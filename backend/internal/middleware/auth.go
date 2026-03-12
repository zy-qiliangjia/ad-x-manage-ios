package middleware

import (
	"strings"

	"github.com/gin-gonic/gin"
	"github.com/redis/go-redis/v9"

	"ad-x-manage/backend/internal/pkg/cache"
	"ad-x-manage/backend/internal/pkg/jwtutil"
	"ad-x-manage/backend/internal/pkg/response"
)

const (
	ContextKeyUserID = "user_id"
	ContextKeyEmail  = "user_email"
	ContextKeyJTI    = "jti"
)

// Auth JWT 鉴权中间件。
// 验证 Authorization: Bearer <token>，并检查 Redis 黑名单。
func Auth(secret string, rdb *redis.Client) gin.HandlerFunc {
	return func(c *gin.Context) {
		header := c.GetHeader("Authorization")
		if !strings.HasPrefix(header, "Bearer ") {
			response.Unauthorized(c, "missing authorization header")
			return
		}
		tokenStr := strings.TrimPrefix(header, "Bearer ")

		claims, err := jwtutil.Parse(secret, tokenStr)
		if err != nil {
			response.Unauthorized(c, "invalid or expired token")
			return
		}

		// 检查黑名单（登出后的 token）
		blacklisted, err := cache.IsTokenBlacklisted(c.Request.Context(), rdb, claims.ID)
		if err == nil && blacklisted {
			response.Unauthorized(c, "token has been revoked")
			return
		}

		c.Set(ContextKeyUserID, claims.UserID)
		c.Set(ContextKeyEmail, claims.Email)
		c.Set(ContextKeyJTI, claims.ID)
		c.Next()
	}
}

// GetUserID 从 gin.Context 中读取当前登录用户 ID。
func GetUserID(c *gin.Context) uint64 {
	v, _ := c.Get(ContextKeyUserID)
	id, _ := v.(uint64)
	return id
}
