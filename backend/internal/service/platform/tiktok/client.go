// Package tiktok 封装 TikTok For Business Marketing API。
// API 文档：https://business-api.tiktok.com/portal/docs
package tiktok

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"time"

	"ad-x-manage/backend/internal/service/platform"
)

const (
	baseURL     = "https://business-api.tiktok.com"
	authURL     = "https://business-api.tiktok.com/portal/auth"
	sandboxBase = "https://sandbox-ads.tiktok.com"
	apiVersion  = "v1.3"
)

type Client struct {
	appID       string
	appSecret   string
	redirectURI string
	sandbox     bool
	httpClient  *http.Client
}

func New(appID, appSecret, redirectURI string, sandbox bool) *Client {
	return &Client{
		appID:       appID,
		appSecret:   appSecret,
		redirectURI: redirectURI,
		sandbox:     sandbox,
		httpClient:  &http.Client{Timeout: 15 * time.Second},
	}
}

func (c *Client) Name() string { return "tiktok" }

func (c *Client) base() string {
	if c.sandbox {
		return sandboxBase
	}
	return baseURL
}

// ── OAuth ──────────────────────────────────────────────────────

// GetOAuthURL 生成 TikTok 授权跳转 URL。
// 文档：https://business-api.tiktok.com/portal/docs?id=1738373164380162
func (c *Client) GetOAuthURL(state string) string {
	params := url.Values{}
	params.Set("app_id", c.appID)
	params.Set("state", state)
	params.Set("redirect_uri", c.redirectURI)
	return authURL + "?" + params.Encode()
}

// ExchangeToken 用授权 code 换取 access_token。
// 文档：https://business-api.tiktok.com/portal/docs?id=1738373141733378
func (c *Client) ExchangeToken(code string) (*platform.TokenResult, error) {
	body := map[string]string{
		"app_id":    c.appID,
		"secret":    c.appSecret,
		"auth_code": code,
	}
	var resp struct {
		Code    int    `json:"code"`
		Message string `json:"message"`
		Data    struct {
			AccessToken           string   `json:"access_token"`
			AdvertiserIDs         []string `json:"advertiser_ids"`
			ExpiresIn             int64    `json:"expires_in"`
			RefreshToken          string   `json:"refresh_token"`
			RefreshTokenExpiresIn int64    `json:"refresh_token_expires_in"`
			OpenID                string   `json:"open_id"`
			Scope                 any      `json:"scope"`
		} `json:"data"`
	}
	if err := c.post("/open_api/"+apiVersion+"/oauth2/access_token/", body, &resp); err != nil {
		return nil, err
	}
	if resp.Code != 0 {
		return nil, fmt.Errorf("tiktok exchange token error %d: %s", resp.Code, resp.Message)
	}
	now := time.Now()
	return &platform.TokenResult{
		OpenUserID:          resp.Data.OpenID,
		AccessToken:         resp.Data.AccessToken,
		RefreshToken:        resp.Data.RefreshToken,
		ExpiresAt:           now.Add(time.Duration(resp.Data.ExpiresIn) * time.Second),
		RefreshTokenExpires: now.Add(time.Duration(resp.Data.RefreshTokenExpiresIn) * time.Second),
		Scope:               fmt.Sprintf("%v", resp.Data.Scope),
	}, nil
}

// RefreshToken 刷新 access_token。
// 文档：https://business-api.tiktok.com/portal/docs?id=1738373141733378
func (c *Client) RefreshToken(refreshToken string) (*platform.TokenResult, error) {
	body := map[string]string{
		"app_id":        c.appID,
		"secret":        c.appSecret,
		"refresh_token": refreshToken,
	}
	var resp struct {
		Code    int    `json:"code"`
		Message string `json:"message"`
		Data    struct {
			AccessToken           string `json:"access_token"`
			ExpiresIn             int64  `json:"expires_in"`
			RefreshToken          string `json:"refresh_token"`
			RefreshTokenExpiresIn int64  `json:"refresh_token_expires_in"`
			OpenID                string `json:"open_id"`
		} `json:"data"`
	}
	if err := c.post("/open_api/"+apiVersion+"/oauth2/refresh_token/", body, &resp); err != nil {
		return nil, err
	}
	if resp.Code != 0 {
		return nil, fmt.Errorf("tiktok refresh token error %d: %s", resp.Code, resp.Message)
	}
	now := time.Now()
	return &platform.TokenResult{
		OpenUserID:          resp.Data.OpenID,
		AccessToken:         resp.Data.AccessToken,
		RefreshToken:        resp.Data.RefreshToken,
		ExpiresAt:           now.Add(time.Duration(resp.Data.ExpiresIn) * time.Second),
		RefreshTokenExpires: now.Add(time.Duration(resp.Data.RefreshTokenExpiresIn) * time.Second),
	}, nil
}

// ── 广告主 ─────────────────────────────────────────────────────

// GetAdvertisers 拉取该 access_token 下所有广告主账号列表。
// 文档：https://business-api.tiktok.com/portal/docs?id=1738455508553729
func (c *Client) GetAdvertisers(accessToken string) ([]*platform.AdvertiserInfo, error) {
	params := url.Values{}
	params.Set("app_id", c.appID)
	params.Set("secret", c.appSecret)
	params.Set("access_token", accessToken)

	var resp struct {
		Code    int    `json:"code"`
		Message string `json:"message"`
		Data    struct {
			List []struct {
				AdvertiserID   string `json:"advertiser_id"`
				AdvertiserName string `json:"advertiser_name"`
				Status         string `json:"status"`
				Currency       string `json:"currency"`
				Timezone       string `json:"timezone"`
			} `json:"list"`
		} `json:"data"`
	}
	if err := c.get("/open_api/"+apiVersion+"/oauth2/advertiser/get/", params, accessToken, &resp); err != nil {
		return nil, err
	}
	if resp.Code != 0 {
		return nil, fmt.Errorf("tiktok get advertisers error %d: %s", resp.Code, resp.Message)
	}
	result := make([]*platform.AdvertiserInfo, 0, len(resp.Data.List))
	for _, item := range resp.Data.List {
		result = append(result, &platform.AdvertiserInfo{
			AdvertiserID:   item.AdvertiserID,
			AdvertiserName: item.AdvertiserName,
			Currency:       item.Currency,
			Timezone:       item.Timezone,
		})
	}
	return result, nil
}

// GetBalance 实时查询广告主余额。
func (c *Client) GetBalance(accessToken, advertiserID string) (*platform.BalanceInfo, error) {
	params := url.Values{}
	params.Set("advertiser_id", advertiserID)

	var resp struct {
		Code    int    `json:"code"`
		Message string `json:"message"`
		Data    struct {
			Balance  float64 `json:"balance"`
			Currency string  `json:"currency"`
		} `json:"data"`
	}
	if err := c.get("/open_api/"+apiVersion+"/advertiser/finance/get/", params, accessToken, &resp); err != nil {
		return nil, err
	}
	if resp.Code != 0 {
		return nil, fmt.Errorf("tiktok get balance error %d: %s", resp.Code, resp.Message)
	}
	return &platform.BalanceInfo{
		AdvertiserID: advertiserID,
		Balance:      resp.Data.Balance,
		Currency:     resp.Data.Currency,
	}, nil
}

// ── 推广系列 ───────────────────────────────────────────────────

func (c *Client) GetCampaigns(accessToken, advertiserID string, page, pageSize int) ([]*platform.CampaignInfo, int64, error) {
	fields, _ := json.Marshal([]string{"campaign_id", "campaign_name", "operation_status", "budget_mode", "budget", "objective_type"})
	params := url.Values{}
	params.Set("advertiser_id", advertiserID)
	params.Set("page", fmt.Sprintf("%d", page))
	params.Set("page_size", fmt.Sprintf("%d", pageSize))
	params.Set("fields", string(fields))
	var resp struct {
		Code    int    `json:"code"`
		Message string `json:"message"`
		Data    struct {
			List []struct {
				CampaignID    string  `json:"campaign_id"`
				CampaignName  string  `json:"campaign_name"`
				Status        string  `json:"operation_status"`
				BudgetMode    string  `json:"budget_mode"`
				Budget        float64 `json:"budget"`
				ObjectiveType string  `json:"objective_type"`
			} `json:"list"`
			PageInfo struct {
				TotalNumber int64 `json:"total_number"`
			} `json:"page_info"`
		} `json:"data"`
	}
	if err := c.get("/open_api/"+apiVersion+"/campaign/get/", params, accessToken, &resp); err != nil {
		return nil, 0, err
	}
	if resp.Code != 0 {
		return nil, 0, fmt.Errorf("tiktok get campaigns error %d: %s", resp.Code, resp.Message)
	}
	result := make([]*platform.CampaignInfo, 0, len(resp.Data.List))
	for _, item := range resp.Data.List {
		result = append(result, &platform.CampaignInfo{
			CampaignID:   item.CampaignID,
			CampaignName: item.CampaignName,
			Status:       item.Status,
			BudgetMode:   item.BudgetMode,
			Budget:       item.Budget,
			Objective:    item.ObjectiveType,
		})
	}
	return result, resp.Data.PageInfo.TotalNumber, nil
}

func (c *Client) UpdateCampaignBudget(accessToken, advertiserID, campaignID string, budget float64) error {
	body := map[string]any{
		"advertiser_id": advertiserID,
		"campaign_id":   campaignID,
		"budget":        budget,
	}
	var resp struct {
		Code    int    `json:"code"`
		Message string `json:"message"`
	}
	if err := c.postWithToken("/open_api/"+apiVersion+"/campaign/update/", body, accessToken, &resp); err != nil {
		return err
	}
	if resp.Code != 0 {
		return fmt.Errorf("tiktok update campaign budget error %d: %s", resp.Code, resp.Message)
	}
	return nil
}

func (c *Client) UpdateCampaignStatus(accessToken, advertiserID, campaignID, status string) error {
	body := map[string]any{
		"advertiser_id": advertiserID,
		"campaign_ids":  []string{campaignID},
		"opt_status":    status,
	}
	var resp struct {
		Code    int    `json:"code"`
		Message string `json:"message"`
	}
	if err := c.postWithToken("/open_api/"+apiVersion+"/campaign/status/update/", body, accessToken, &resp); err != nil {
		return err
	}
	if resp.Code != 0 {
		return fmt.Errorf("tiktok update campaign status error %d: %s", resp.Code, resp.Message)
	}
	return nil
}

// ── 广告组 ─────────────────────────────────────────────────────

func (c *Client) GetAdGroups(accessToken, advertiserID, campaignID string, page, pageSize int) ([]*platform.AdGroupInfo, int64, error) {
	fields, _ := json.Marshal([]string{"adgroup_id", "adgroup_name", "campaign_id", "operation_status", "budget_mode", "budget", "bid_type", "bid_price"})
	params := url.Values{}
	params.Set("advertiser_id", advertiserID)
	params.Set("page", fmt.Sprintf("%d", page))
	params.Set("page_size", fmt.Sprintf("%d", pageSize))
	params.Set("fields", string(fields))
	if campaignID != "" {
		filtering, _ := json.Marshal(map[string]any{"campaign_ids": []string{campaignID}})
		params.Set("filtering", string(filtering))
	}
	var resp struct {
		Code    int    `json:"code"`
		Message string `json:"message"`
		Data    struct {
			List []struct {
				AdgroupID   string  `json:"adgroup_id"`
				AdgroupName string  `json:"adgroup_name"`
				CampaignID  string  `json:"campaign_id"`
				Status      string  `json:"operation_status"`
				BudgetMode  string  `json:"budget_mode"`
				Budget      float64 `json:"budget"`
				BidType     string  `json:"bid_type"`
				BidPrice    float64 `json:"bid_price"`
			} `json:"list"`
			PageInfo struct {
				TotalNumber int64 `json:"total_number"`
			} `json:"page_info"`
		} `json:"data"`
	}
	if err := c.get("/open_api/"+apiVersion+"/adgroup/get/", params, accessToken, &resp); err != nil {
		return nil, 0, err
	}
	if resp.Code != 0 {
		return nil, 0, fmt.Errorf("tiktok get adgroups error %d: %s", resp.Code, resp.Message)
	}
	result := make([]*platform.AdGroupInfo, 0, len(resp.Data.List))
	for _, item := range resp.Data.List {
		result = append(result, &platform.AdGroupInfo{
			AdGroupID:   item.AdgroupID,
			AdGroupName: item.AdgroupName,
			CampaignID:  item.CampaignID,
			Status:      item.Status,
			BudgetMode:  item.BudgetMode,
			Budget:      item.Budget,
			BidType:     item.BidType,
			BidPrice:    item.BidPrice,
		})
	}
	return result, resp.Data.PageInfo.TotalNumber, nil
}

func (c *Client) UpdateAdGroupBudget(accessToken, advertiserID, adGroupID string, budget float64) error {
	body := map[string]any{
		"advertiser_id": advertiserID,
		"adgroup_id":    adGroupID,
		"budget":        budget,
	}
	var resp struct {
		Code    int    `json:"code"`
		Message string `json:"message"`
	}
	if err := c.postWithToken("/open_api/"+apiVersion+"/adgroup/update/", body, accessToken, &resp); err != nil {
		return err
	}
	if resp.Code != 0 {
		return fmt.Errorf("tiktok update adgroup budget error %d: %s", resp.Code, resp.Message)
	}
	return nil
}

func (c *Client) UpdateAdGroupStatus(accessToken, advertiserID, adGroupID, status string) error {
	body := map[string]any{
		"advertiser_id": advertiserID,
		"adgroup_ids":   []string{adGroupID},
		"opt_status":    status,
	}
	var resp struct {
		Code    int    `json:"code"`
		Message string `json:"message"`
	}
	if err := c.postWithToken("/open_api/"+apiVersion+"/adgroup/status/update/", body, accessToken, &resp); err != nil {
		return err
	}
	if resp.Code != 0 {
		return fmt.Errorf("tiktok update adgroup status error %d: %s", resp.Code, resp.Message)
	}
	return nil
}

// ── 广告 ───────────────────────────────────────────────────────

func (c *Client) GetAds(accessToken, advertiserID, adGroupID string, page, pageSize int) ([]*platform.AdInfo, int64, error) {
	fields, _ := json.Marshal([]string{"ad_id", "ad_name", "adgroup_id", "operation_status"})
	params := url.Values{}
	params.Set("advertiser_id", advertiserID)
	params.Set("page", fmt.Sprintf("%d", page))
	params.Set("page_size", fmt.Sprintf("%d", pageSize))
	params.Set("fields", string(fields))
	if adGroupID != "" {
		filtering, _ := json.Marshal(map[string]any{"adgroup_ids": []string{adGroupID}})
		params.Set("filtering", string(filtering))
	}
	var resp struct {
		Code    int    `json:"code"`
		Message string `json:"message"`
		Data    struct {
			List []struct {
				AdID      string `json:"ad_id"`
				AdName    string `json:"ad_name"`
				AdgroupID string `json:"adgroup_id"`
				Status    string `json:"operation_status"`
			} `json:"list"`
			PageInfo struct {
				TotalNumber int64 `json:"total_number"`
			} `json:"page_info"`
		} `json:"data"`
	}
	if err := c.get("/open_api/"+apiVersion+"/ad/get/", params, accessToken, &resp); err != nil {
		return nil, 0, err
	}
	if resp.Code != 0 {
		return nil, 0, fmt.Errorf("tiktok get ads error %d: %s", resp.Code, resp.Message)
	}
	result := make([]*platform.AdInfo, 0, len(resp.Data.List))
	for _, item := range resp.Data.List {
		result = append(result, &platform.AdInfo{
			AdID:      item.AdID,
			AdName:    item.AdName,
			AdGroupID: item.AdgroupID,
			Status:    item.Status,
		})
	}
	return result, resp.Data.PageInfo.TotalNumber, nil
}

// ── HTTP 工具方法 ───────────────────────────────────────────────

func (c *Client) get(path string, params url.Values, accessToken string, out any) error {
	reqURL := c.base() + path + "?" + params.Encode()
	req, err := http.NewRequest(http.MethodGet, reqURL, nil)
	if err != nil {
		return err
	}
	if accessToken != "" {
		req.Header.Set("Access-Token", accessToken)
	}
	return c.do(req, out)
}

func (c *Client) post(path string, body any, out any) error {
	return c.postWithToken(path, body, "", out)
}

func (c *Client) postWithToken(path string, body any, accessToken string, out any) error {
	b, err := json.Marshal(body)
	if err != nil {
		return err
	}
	req, err := http.NewRequest(http.MethodPost, c.base()+path, bytes.NewReader(b))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/json")
	if accessToken != "" {
		req.Header.Set("Access-Token", accessToken)
	}
	return c.do(req, out)
}

func (c *Client) do(req *http.Request, out any) error {
	resp, err := c.httpClient.Do(req)
	if err != nil {
		return fmt.Errorf("tiktok http request failed: %w", err)
	}
	defer resp.Body.Close()

	data, err := io.ReadAll(resp.Body)
	if err != nil {
		return fmt.Errorf("tiktok read response failed: %w", err)
	}
	if err := json.Unmarshal(data, out); err != nil {
		return fmt.Errorf("tiktok parse response failed: %w (body: %.200s)", err, data)
	}
	return nil
}
