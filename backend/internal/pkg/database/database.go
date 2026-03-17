package database

import (
	"context"
	"errors"
	"fmt"
	"time"

	"go.uber.org/zap"
	"gorm.io/driver/mysql"
	"gorm.io/gorm"
	gormlogger "gorm.io/gorm/logger"

	"ad-x-manage/backend/internal/config"
)

// New 初始化 MySQL 连接，返回 *gorm.DB。
func New(cfg *config.DBConfig, log *zap.Logger) (*gorm.DB, error) {
	dsn := fmt.Sprintf(
		"%s:%s@tcp(%s:%s)/%s?charset=utf8mb4&parseTime=True&loc=Local",
		cfg.User, cfg.Password, cfg.Host, cfg.Port, cfg.Name,
	)

	db, err := gorm.Open(mysql.Open(dsn), &gorm.Config{
		Logger:                                   newZapGormLogger(log),
		DisableForeignKeyConstraintWhenMigrating: true,
	})
	if err != nil {
		return nil, fmt.Errorf("connect to mysql: %w", err)
	}

	sqlDB, err := db.DB()
	if err != nil {
		return nil, fmt.Errorf("get sql.DB: %w", err)
	}
	sqlDB.SetMaxOpenConns(cfg.MaxOpenConns)
	sqlDB.SetMaxIdleConns(cfg.MaxIdleConns)
	sqlDB.SetConnMaxLifetime(time.Hour)
	sqlDB.SetConnMaxIdleTime(30 * time.Minute)

	return db, nil
}

// ── GORM → zap logger bridge ──────────────────────────────────────────────

type zapGormLogger struct {
	log *zap.Logger
}

func newZapGormLogger(log *zap.Logger) gormlogger.Interface {
	return &zapGormLogger{log: log.Named("sql")}
}

func (l *zapGormLogger) LogMode(_ gormlogger.LogLevel) gormlogger.Interface { return l }

func (l *zapGormLogger) Info(_ context.Context, msg string, args ...any) {
	l.log.Sugar().Infof(msg, args...)
}

func (l *zapGormLogger) Warn(_ context.Context, msg string, args ...any) {
	l.log.Sugar().Warnf(msg, args...)
}

func (l *zapGormLogger) Error(_ context.Context, msg string, args ...any) {
	l.log.Sugar().Errorf(msg, args...)
}

// Trace 每条 SQL 执行后调用，记录语句、影响行数、耗时。
func (l *zapGormLogger) Trace(_ context.Context, begin time.Time, fc func() (string, int64), err error) {
	elapsed := time.Since(begin)
	sql, rows := fc()
	fields := []zap.Field{
		zap.String("sql", sql),
		zap.Int64("rows", rows),
		zap.Duration("elapsed", elapsed),
	}
	if err != nil && !errors.Is(err, gorm.ErrRecordNotFound) {
		l.log.Error("sql", append(fields, zap.Error(err))...)
		return
	}
	l.log.Info("sql", fields...)
}
