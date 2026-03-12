package health

import (
	"github.com/gin-gonic/gin"

	"ad-x-manage/backend/internal/pkg/response"
)

// Check 健康检查接口，用于负载均衡探活。
// GET /health
func Check(c *gin.Context) {
	response.OK(c, gin.H{"status": "ok"})
}
