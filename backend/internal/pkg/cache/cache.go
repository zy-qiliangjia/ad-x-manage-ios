package cache

import (
	"context"
	"fmt"
	"time"

	"github.com/redis/go-redis/v9"

	"ad-x-manage/backend/internal/config"
)

// New 初始化 Redis 客户端，并通过 Ping 验证连接。
func New(cfg *config.RedisConfig) (*redis.Client, error) {
	rdb := redis.NewClient(&redis.Options{
		Addr:         fmt.Sprintf("%s:%s", cfg.Host, cfg.Port),
		Password:     cfg.Password,
		DB:           cfg.DB,
		DialTimeout:  5 * time.Second,
		ReadTimeout:  3 * time.Second,
		WriteTimeout: 3 * time.Second,
	})

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	if err := rdb.Ping(ctx).Err(); err != nil {
		return nil, fmt.Errorf("connect to redis: %w", err)
	}
	return rdb, nil
}

// BlacklistToken 将 JWT jti 加入 Redis 黑名单，TTL 设为 Token 剩余有效期。
func BlacklistToken(ctx context.Context, rdb *redis.Client, jti string, ttl time.Duration) error {
	key := "jwt:blacklist:" + jti
	return rdb.Set(ctx, key, 1, ttl).Err()
}

// IsTokenBlacklisted 检查 JWT jti 是否在黑名单中。
func IsTokenBlacklisted(ctx context.Context, rdb *redis.Client, jti string) (bool, error) {
	key := "jwt:blacklist:" + jti
	exists, err := rdb.Exists(ctx, key).Result()
	if err != nil {
		return false, err
	}
	return exists > 0, nil
}
