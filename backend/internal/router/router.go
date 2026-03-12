package router

import (
	"github.com/gin-gonic/gin"
	"github.com/redis/go-redis/v9"
	"go.uber.org/zap"
	"gorm.io/gorm"

	"ad-x-manage/backend/internal/config"
	authhandler "ad-x-manage/backend/internal/handler/auth"
	"ad-x-manage/backend/internal/handler/health"
	"ad-x-manage/backend/internal/middleware"
	userrepo "ad-x-manage/backend/internal/repository/user"
	authsvc "ad-x-manage/backend/internal/service/auth"
)

// New 初始化 Gin 路由，注册所有中间件和路由。
// 依赖注入顺序：repository → service → handler → router
func New(cfg *config.Config, db *gorm.DB, rdb *redis.Client, log *zap.Logger) *gin.Engine {
	if cfg.App.Env == "production" {
		gin.SetMode(gin.ReleaseMode)
	}

	// ── 依赖注入 ──────────────────────────────────────────
	// B2: 用户认证
	userRepo := userrepo.New(db)
	authService := authsvc.New(userRepo, rdb, cfg.App.Secret)
	authHandler := authhandler.New(authService)

	// B3~B8: 后续模块在此追加
	// oauthService  := ...
	// advertiserService := ...

	// ── Gin Engine ────────────────────────────────────────
	r := gin.New()
	r.Use(gin.Recovery())
	r.Use(middleware.CORS())
	r.Use(middleware.RequestLogger(log))

	// 健康检查（无需鉴权）
	r.GET("/health", health.Check)

	// API v1
	v1 := r.Group("/api/v1")

	// ── 公开路由（无需登录）──────────────────────────────
	auth := v1.Group("/auth")
	{
		auth.POST("/register", authHandler.Register)
		auth.POST("/login", authHandler.Login)
	}

	// ── 需要登录的路由 ────────────────────────────────────
	protected := v1.Group("", middleware.Auth(cfg.App.Secret, rdb))
	{
		// B2: Token 操作
		protected.POST("/auth/logout", authHandler.Logout)
		protected.POST("/auth/refresh", authHandler.Refresh)

		// B3: OAuth 授权（待实现）
		// oauth := protected.Group("/oauth")
		// oauth.GET("/:platform/url",           oauthHandler.GetURL)
		// oauth.POST("/:platform/callback",     oauthHandler.Callback)
		// oauth.DELETE("/:platform/:accountID", oauthHandler.Revoke)

		// B5: 广告主账号（待实现）
		// advGroup := protected.Group("/advertisers")
		// advGroup.GET("",             advertiserHandler.List)
		// advGroup.GET("/:id/balance", advertiserHandler.Balance)
		// advGroup.POST("/:id/sync",   advertiserHandler.Sync)

		// B6: 推广系列（待实现）
		// protected.GET("/advertisers/:id/campaigns", campaignHandler.List)
		// protected.PATCH("/campaigns/:id/budget",    campaignHandler.UpdateBudget)
		// protected.PATCH("/campaigns/:id/status",    campaignHandler.UpdateStatus)

		// B7: 广告组（待实现）
		// protected.GET("/advertisers/:id/adgroups",  adgroupHandler.List)
		// protected.PATCH("/adgroups/:id/budget",     adgroupHandler.UpdateBudget)
		// protected.PATCH("/adgroups/:id/status",     adgroupHandler.UpdateStatus)

		// B8: 广告（待实现）
		// protected.GET("/advertisers/:id/ads", adHandler.List)
	}

	return r
}
