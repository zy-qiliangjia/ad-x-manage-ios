package response

import (
	"net/http"

	"github.com/gin-gonic/gin"
)

// 业务错误码
const (
	CodeOK            = 0
	CodeUnauthorized  = 1001 // 未登录 / JWT 过期
	CodeInvalidParam  = 1002 // 参数校验失败
	CodePlatformError = 1003 // 平台 API 调用失败
	CodeForbidden     = 1004 // 无权限操作
	CodeTokenExpired  = 1005 // OAuth Token 失效，需重新授权
	CodeServerError   = 5000 // 服务器内部错误
)

type Response struct {
	Code    int    `json:"code"`
	Message string `json:"message"`
	Data    any    `json:"data,omitempty"`
}

type PageResponse struct {
	Code       int        `json:"code"`
	Message    string     `json:"message"`
	Data       any        `json:"data,omitempty"`
	Pagination Pagination `json:"pagination"`
}

type Pagination struct {
	Page     int   `json:"page"`
	PageSize int   `json:"page_size"`
	Total    int64 `json:"total"`
	HasMore  bool  `json:"has_more"`
}

func OK(c *gin.Context, data any) {
	c.JSON(http.StatusOK, Response{Code: CodeOK, Message: "ok", Data: data})
}

func OKPage(c *gin.Context, data any, p Pagination) {
	c.JSON(http.StatusOK, PageResponse{
		Code: CodeOK, Message: "ok", Data: data, Pagination: p,
	})
}

func Fail(c *gin.Context, httpCode, code int, msg string) {
	c.AbortWithStatusJSON(httpCode, Response{Code: code, Message: msg})
}

func BadRequest(c *gin.Context, msg string) {
	Fail(c, http.StatusUnprocessableEntity, CodeInvalidParam, msg)
}

func Unauthorized(c *gin.Context, msg string) {
	Fail(c, http.StatusUnauthorized, CodeUnauthorized, msg)
}

func Forbidden(c *gin.Context, msg string) {
	Fail(c, http.StatusForbidden, CodeForbidden, msg)
}

func ServerError(c *gin.Context, msg string) {
	Fail(c, http.StatusInternalServerError, CodeServerError, msg)
}

func PlatformError(c *gin.Context, msg string) {
	Fail(c, http.StatusBadGateway, CodePlatformError, msg)
}
