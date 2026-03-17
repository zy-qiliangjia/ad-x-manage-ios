package main

import (
	"context"
	"fmt"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"go.uber.org/zap"

	"ad-x-manage/backend/internal/config"
	"ad-x-manage/backend/internal/pkg/cache"
	"ad-x-manage/backend/internal/pkg/database"
	"ad-x-manage/backend/internal/pkg/logger"
	"ad-x-manage/backend/internal/router"
)

func main() {
	// 1. 加载配置
	cfg, err := config.Load()
	if err != nil {
		fmt.Fprintf(os.Stderr, "config load error: %v\n", err)
		os.Exit(1)
	}

	// 2. 初始化日志
	log := logger.New(cfg.App.Env)
	defer log.Sync() //nolint:errcheck

	// 3. 初始化 MySQL
	db, err := database.New(&cfg.DB, log)
	if err != nil {
		log.Fatal("database init failed", zap.Error(err))
	}
	log.Info("database connected",
		zap.String("host", cfg.DB.Host),
		zap.String("name", cfg.DB.Name),
	)

	// 4. 初始化 Redis
	rdb, err := cache.New(&cfg.Redis)
	if err != nil {
		log.Fatal("redis init failed", zap.Error(err))
	}
	log.Info("redis connected", zap.String("host", cfg.Redis.Host))

	// 5. 注册路由
	r := router.New(cfg, db, rdb, log)

	// 6. 启动 HTTP Server
	srv := &http.Server{
		Addr:         ":" + cfg.App.Port,
		Handler:      r,
		ReadTimeout:  15 * time.Second,
		WriteTimeout: 15 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	go func() {
		log.Info("server starting",
			zap.String("port", cfg.App.Port),
			zap.String("env", cfg.App.Env),
		)
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatal("server error", zap.Error(err))
		}
	}()

	// 7. 优雅关闭（等待 SIGINT / SIGTERM）
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	log.Info("shutting down server...")
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	if err := srv.Shutdown(ctx); err != nil {
		log.Error("server shutdown error", zap.Error(err))
	}
	log.Info("server exited")
}
