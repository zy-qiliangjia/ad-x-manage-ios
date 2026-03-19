package config

import (
	"github.com/gin-gonic/gin"

	appcfg "ad-x-manage/backend/internal/config"
	"ad-x-manage/backend/internal/pkg/response"
)

type Handler struct {
	cfg *appcfg.Config
}

func New(cfg *appcfg.Config) *Handler {
	return &Handler{cfg: cfg}
}

// GetConfig 返回客户端配置（客服联系方式等），无需登录。
// GET /api/v1/config
func (h *Handler) GetConfig(c *gin.Context) {
	response.OK(c, gin.H{
		"wechat_url":   h.cfg.Contact.WechatURL,
		"telegram_url": h.cfg.Contact.TelegramURL,
	})
}
