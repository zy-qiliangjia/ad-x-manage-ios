package router

import (
	"github.com/gin-gonic/gin"
	"github.com/redis/go-redis/v9"
	"go.uber.org/zap"
	"gorm.io/gorm"

	"ad-x-manage/backend/internal/config"
	adhandler "ad-x-manage/backend/internal/handler/ad"
	adgrouphandler "ad-x-manage/backend/internal/handler/adgroup"
	advertiserhandler "ad-x-manage/backend/internal/handler/advertiser"
	authhandler "ad-x-manage/backend/internal/handler/auth"
	campaignhandler "ad-x-manage/backend/internal/handler/campaign"
	"ad-x-manage/backend/internal/handler/health"
	oauthhandler "ad-x-manage/backend/internal/handler/oauth"
	operationloghandler "ad-x-manage/backend/internal/handler/operationlog"
	statshandler "ad-x-manage/backend/internal/handler/stats"
	"ad-x-manage/backend/internal/middleware"
	adrepo "ad-x-manage/backend/internal/repository/ad"
	adgrouprepo "ad-x-manage/backend/internal/repository/adgroup"
	advertiserrepo "ad-x-manage/backend/internal/repository/advertiser"
	campaignrepo "ad-x-manage/backend/internal/repository/campaign"
	operationlogrepo "ad-x-manage/backend/internal/repository/operationlog"
	tokenrepo "ad-x-manage/backend/internal/repository/token"
	userrepo "ad-x-manage/backend/internal/repository/user"
	adsvc "ad-x-manage/backend/internal/service/ad"
	adgroupsvc "ad-x-manage/backend/internal/service/adgroup"
	advertisersvc "ad-x-manage/backend/internal/service/advertiser"
	authsvc "ad-x-manage/backend/internal/service/auth"
	campaignsvc "ad-x-manage/backend/internal/service/campaign"
	oauthsvc "ad-x-manage/backend/internal/service/oauth"
	operationlogsvc "ad-x-manage/backend/internal/service/operationlog"
	"ad-x-manage/backend/internal/service/platform"
	"ad-x-manage/backend/internal/service/platform/kwai"
	"ad-x-manage/backend/internal/service/platform/tiktok"
	statssvc "ad-x-manage/backend/internal/service/stats"
	syncsvc "ad-x-manage/backend/internal/service/sync"
)

// New 初始化 Gin 路由。
// 依赖注入顺序：platform clients → repositories → services → handlers → router
func New(cfg *config.Config, db *gorm.DB, rdb *redis.Client, log *zap.Logger) *gin.Engine {
	if cfg.App.Env == "production" {
		gin.SetMode(gin.ReleaseMode)
	}

	// ── 平台客户端 ────────────────────────────────────────
	platformClients := map[string]platform.Client{
		"tiktok": tiktok.New(cfg.TikTok.AppID, cfg.TikTok.AppSecret, cfg.TikTok.RedirectURI, cfg.TikTok.Sandbox),
		"kwai":   kwai.New(cfg.Kwai.AppKey, cfg.Kwai.AppSecret, cfg.Kwai.RedirectURI),
	}

	// ── Repositories ──────────────────────────────────────
	userRepo := userrepo.New(db)
	tokenRepo := tokenrepo.New(db)
	advRepo := advertiserrepo.New(db)
	campRepo := campaignrepo.New(db)
	groupRepo := adgrouprepo.New(db)
	adRepo := adrepo.New(db)
	logRepo := operationlogrepo.New(db)

	// ── Services ──────────────────────────────────────────
	// B4: 数据同步（被 OAuth 和 Advertiser 服务共用）
	syncService := syncsvc.New(platformClients, tokenRepo, advRepo, campRepo, groupRepo, adRepo, log)

	// B2: 用户认证
	authService := authsvc.New(userRepo, rdb, cfg.App.Secret)

	// B3: OAuth 授权（授权完成后自动触发后台同步）
	oauthService := oauthsvc.New(platformClients, tokenRepo, advRepo, syncService, rdb, log)

	// B5: 广告主账号
	advertiserService := advertisersvc.New(advRepo, tokenRepo, platformClients, syncService, log)

	// B6: 推广系列
	campaignService := campaignsvc.New(campRepo, advRepo, tokenRepo, logRepo, platformClients, log)

	// B7: 广告组
	adGroupService := adgroupsvc.New(groupRepo, advRepo, tokenRepo, logRepo, platformClients, log)

	// B8: 广告
	adService := adsvc.New(adRepo, groupRepo, advRepo)

	// B9: 操作日志
	operationLogService := operationlogsvc.New(logRepo, advRepo)

	// Dashboard: 统计概览
	statsService := statssvc.New(db, log)

	// ── Handlers ──────────────────────────────────────────
	authHandler := authhandler.New(authService)
	oauthHandler := oauthhandler.New(oauthService)
	advertiserHandler := advertiserhandler.New(advertiserService)
	campaignHandler := campaignhandler.New(campaignService)
	adGroupHandler := adgrouphandler.New(adGroupService)
	adHandler := adhandler.New(adService)
	operationLogHandler := operationloghandler.New(operationLogService)
	statsHandler := statshandler.New(statsService)

	// ── Gin Engine ────────────────────────────────────────
	r := gin.New()
	r.Use(gin.Recovery())
	r.Use(middleware.CORS())
	r.Use(middleware.RequestLogger(log))

	r.GET("/health", health.Check)

	v1 := r.Group("/api/v1")

	// ── 公开路由 ──────────────────────────────────────────
	authGroup := v1.Group("/auth")
	{
		authGroup.POST("/register", authHandler.Register)
		authGroup.POST("/login", authHandler.Login)
	}

	// OAuth 平台回调（无需 JWT，由平台服务器直接调用）
	v1.GET("/oauth/:platform/redirect", oauthHandler.Redirect)

	// ── 需要登录的路由 ────────────────────────────────────
	protected := v1.Group("", middleware.Auth(cfg.App.Secret, rdb))
	{
		// B2
		protected.POST("/auth/logout", authHandler.Logout)
		protected.POST("/auth/refresh", authHandler.Refresh)

		// B3: OAuth 授权
		oauth := protected.Group("/oauth")
		{
			oauth.GET("/:platform/url", oauthHandler.GetURL)
			oauth.POST("/:platform/callback", oauthHandler.Callback)
			oauth.DELETE("/:platform/:token_id", oauthHandler.Revoke)
		}

		// B5: 广告主账号
		advGroup := protected.Group("/advertisers")
		{
			advGroup.GET("", advertiserHandler.List)
			advGroup.POST("/sync", advertiserHandler.SyncAll) // 登录后触发所有广告主后台同步
			advGroup.GET("/:id/balance", advertiserHandler.Balance)
			advGroup.POST("/:id/sync", advertiserHandler.Sync)

			// B6: 推广系列（挂在 /advertisers/:id 下的列表接口）
			advGroup.GET("/:id/campaigns", campaignHandler.List)

			// B7: 广告组（挂在 /advertisers/:id 下的列表接口）
			advGroup.GET("/:id/adgroups", adGroupHandler.List)

			// B8: 广告（挂在 /advertisers/:id 下的列表接口）
			advGroup.GET("/:id/ads", adHandler.List)
		}

		// B6: 推广系列全量列表 + 写操作
		protected.GET("/campaigns", campaignHandler.ListAll)
		protected.PATCH("/campaigns/:id/budget", campaignHandler.UpdateBudget)
		protected.PATCH("/campaigns/:id/status", campaignHandler.UpdateStatus)

		// B7: 广告组全量列表 + 写操作
		protected.GET("/adgroups", adGroupHandler.ListAll)
		protected.PATCH("/adgroups/:id/budget", adGroupHandler.UpdateBudget)
		protected.PATCH("/adgroups/:id/status", adGroupHandler.UpdateStatus)

		// B8: 广告全量列表
		protected.GET("/ads", adHandler.ListAll)

		// B9: 操作日志
		protected.GET("/operation-logs", operationLogHandler.List)

		// Dashboard + 广告汇总统计
		protected.GET("/stats", statsHandler.Overview)
		protected.GET("/stats/summary", statsHandler.Summary)
	}

	return r
}
