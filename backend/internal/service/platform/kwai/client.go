// Package kwai 封装快手商业化 Open API。
// API 文档：https://developers.e.kuaishou.com
package kwai

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"time"

	"ad-x-manage/backend/internal/service/platform"
)

const (
	authURL    = "https://developers.e.kuaishou.com/oauth2/authorize"
	apiBaseURL = "https://api.e.kuaishou.com"
)

type Client struct {
	appKey      string
	appSecret   string
	redirectURI string
	httpClient  *http.Client
}

func New(appKey, appSecret, redirectURI string) *Client {
	return &Client{
		appKey:      appKey,
		appSecret:   appSecret,
		redirectURI: redirectURI,
		httpClient:  &http.Client{Timeout: 15 * time.Second},
	}
}

func (c *Client) Name() string { return "kwai" }

// ── OAuth ──────────────────────────────────────────────────────

// GetOAuthURL 生成快手授权跳转 URL。
func (c *Client) GetOAuthURL(state string) string {
	params := url.Values{}
	params.Set("app_id", c.appKey)
	params.Set("redirect_uri", c.redirectURI)
	params.Set("state", state)
	params.Set("scope", "AD_MANAGEMENT")
	params.Set("response_type", "code")
	return authURL + "?" + params.Encode()
}

// ExchangeToken 用授权 code 换取 access_token。
func (c *Client) ExchangeToken(code string) (*platform.TokenResult, error) {
	body := map[string]string{
		"app_id":     c.appKey,
		"app_secret": c.appSecret,
		"code":       code,
		"grant_type": "authorization_code",
	}
	var resp struct {
		Result           int    `json:"result"`
		ErrorMsg         string `json:"error_msg"`
		AccessToken      string `json:"access_token"`
		ExpiresIn        int64  `json:"expires_in"`
		RefreshToken     string `json:"refresh_token"`
		RefreshExpiresIn int64  `json:"refresh_expires_in"`
		OpenUserID       string `json:"open_user_id"`
		Scope            string `json:"scope"`
	}
	if err := c.post("/rest/openapi/oauth2/token", body, "", &resp); err != nil {
		return nil, err
	}
	if resp.Result != 1 {
		return nil, fmt.Errorf("kwai exchange token error: %s", resp.ErrorMsg)
	}
	now := time.Now()
	return &platform.TokenResult{
		OpenUserID:          resp.OpenUserID,
		AccessToken:         resp.AccessToken,
		RefreshToken:        resp.RefreshToken,
		ExpiresAt:           now.Add(time.Duration(resp.ExpiresIn) * time.Second),
		RefreshTokenExpires: now.Add(time.Duration(resp.RefreshExpiresIn) * time.Second),
		Scope:               resp.Scope,
	}, nil
}

// RefreshToken 刷新 access_token。
func (c *Client) RefreshToken(refreshToken string) (*platform.TokenResult, error) {
	body := map[string]string{
		"app_id":        c.appKey,
		"app_secret":    c.appSecret,
		"refresh_token": refreshToken,
		"grant_type":    "refresh_token",
	}
	var resp struct {
		Result           int    `json:"result"`
		ErrorMsg         string `json:"error_msg"`
		AccessToken      string `json:"access_token"`
		ExpiresIn        int64  `json:"expires_in"`
		RefreshToken     string `json:"refresh_token"`
		RefreshExpiresIn int64  `json:"refresh_expires_in"`
		OpenUserID       string `json:"open_user_id"`
	}
	if err := c.post("/rest/openapi/oauth2/token", body, "", &resp); err != nil {
		return nil, err
	}
	if resp.Result != 1 {
		return nil, fmt.Errorf("kwai refresh token error: %s", resp.ErrorMsg)
	}
	now := time.Now()
	return &platform.TokenResult{
		OpenUserID:          resp.OpenUserID,
		AccessToken:         resp.AccessToken,
		RefreshToken:        resp.RefreshToken,
		ExpiresAt:           now.Add(time.Duration(resp.ExpiresIn) * time.Second),
		RefreshTokenExpires: now.Add(time.Duration(resp.RefreshExpiresIn) * time.Second),
	}, nil
}

// ── 广告主 ─────────────────────────────────────────────────────

// GetAdvertisers 拉取广告主列表。
func (c *Client) GetAdvertisers(accessToken string) ([]*platform.AdvertiserInfo, error) {
	var resp struct {
		Result      int    `json:"result"`
		ErrorMsg    string `json:"error_msg"`
		Advertisers []struct {
			ID       int64  `json:"id"`
			Name     string `json:"name"`
			Currency string `json:"currency"`
			Timezone string `json:"timezone"`
		} `json:"advertisers"`
	}
	params := url.Values{}
	params.Set("access_token", accessToken)
	if err := c.get("/rest/openapi/advertiser/list", params, accessToken, &resp); err != nil {
		return nil, err
	}
	if resp.Result != 1 {
		return nil, fmt.Errorf("kwai get advertisers error: %s", resp.ErrorMsg)
	}
	result := make([]*platform.AdvertiserInfo, 0, len(resp.Advertisers))
	for _, item := range resp.Advertisers {
		result = append(result, &platform.AdvertiserInfo{
			AdvertiserID:   fmt.Sprintf("%d", item.ID),
			AdvertiserName: item.Name,
			Currency:       item.Currency,
			Timezone:       item.Timezone,
		})
	}
	return result, nil
}

// GetAdvertiserInfo 查询广告主详情（currency、timezone）。
// Kwai GetAdvertisers 已包含这些字段，此处按 ID 批量过滤返回。
func (c *Client) GetAdvertiserInfo(accessToken string, advertiserIDs []string) ([]*platform.AdvertiserInfo, error) {
	// Kwai 的 advertiser/list 接口已包含 currency/timezone，直接复用
	all, err := c.GetAdvertisers(accessToken)
	if err != nil {
		return nil, err
	}
	need := make(map[string]bool, len(advertiserIDs))
	for _, id := range advertiserIDs {
		need[id] = true
	}
	result := make([]*platform.AdvertiserInfo, 0, len(advertiserIDs))
	for _, a := range all {
		if need[a.AdvertiserID] {
			result = append(result, a)
		}
	}
	return result, nil
}

// GetBalance 查询广告主余额。
func (c *Client) GetBalance(accessToken, advertiserID string) (*platform.BalanceInfo, error) {
	params := url.Values{}
	params.Set("access_token", accessToken)
	params.Set("advertiser_id", advertiserID)
	var resp struct {
		Result   int     `json:"result"`
		ErrorMsg string  `json:"error_msg"`
		Balance  float64 `json:"balance"`
		Currency string  `json:"currency"`
	}
	if err := c.get("/rest/openapi/advertiser/finance/info", params, accessToken, &resp); err != nil {
		return nil, err
	}
	if resp.Result != 1 {
		return nil, fmt.Errorf("kwai get balance error: %s", resp.ErrorMsg)
	}
	return &platform.BalanceInfo{
		AdvertiserID: advertiserID,
		Balance:      resp.Balance,
		Currency:     resp.Currency,
	}, nil
}

// UpdateAdvertiserBudget 修改广告主账户日预算。
func (c *Client) UpdateAdvertiserBudget(accessToken, advertiserID string, budget float64) error {
	body := map[string]any{
		"access_token":  accessToken,
		"advertiser_id": advertiserID,
		"day_budget":    budget,
	}
	var resp struct {
		Result   int    `json:"result"`
		ErrorMsg string `json:"error_msg"`
	}
	if err := c.post("/rest/openapi/advertiser/update", body, accessToken, &resp); err != nil {
		return err
	}
	if resp.Result != 1 {
		return fmt.Errorf("kwai update advertiser budget error: %s", resp.ErrorMsg)
	}
	return nil
}

// ── 推广系列 ───────────────────────────────────────────────────

func (c *Client) GetCampaigns(accessToken, advertiserID string, page, pageSize int) ([]*platform.CampaignInfo, int64, error) {
	params := url.Values{}
	params.Set("access_token", accessToken)
	params.Set("advertiser_id", advertiserID)
	params.Set("page", fmt.Sprintf("%d", page))
	params.Set("page_size", fmt.Sprintf("%d", pageSize))
	var resp struct {
		Result    int    `json:"result"`
		ErrorMsg  string `json:"error_msg"`
		Campaigns []struct {
			CampaignID   string  `json:"campaign_id"`
			CampaignName string  `json:"campaign_name"`
			Status       string  `json:"status"`
			DayBudget    float64 `json:"day_budget"`
			TotalBudget  float64 `json:"total_budget"`
		} `json:"campaigns"`
		TotalCount int64 `json:"total_count"`
	}
	if err := c.get("/rest/openapi/campaign/list", params, accessToken, &resp); err != nil {
		return nil, 0, err
	}
	if resp.Result != 1 {
		return nil, 0, fmt.Errorf("kwai get campaigns error: %s", resp.ErrorMsg)
	}
	result := make([]*platform.CampaignInfo, 0, len(resp.Campaigns))
	for _, item := range resp.Campaigns {
		budget := item.DayBudget
		budgetMode := "BUDGET_MODE_DAY"
		if item.TotalBudget > 0 {
			budget = item.TotalBudget
			budgetMode = "BUDGET_MODE_TOTAL"
		}
		result = append(result, &platform.CampaignInfo{
			CampaignID:   item.CampaignID,
			CampaignName: item.CampaignName,
			Status:       item.Status,
			BudgetMode:   budgetMode,
			Budget:       budget,
		})
	}
	return result, resp.TotalCount, nil
}

func (c *Client) UpdateCampaignBudget(accessToken, advertiserID, campaignID string, budget float64) error {
	body := map[string]any{
		"access_token":  accessToken,
		"advertiser_id": advertiserID,
		"campaign_id":   campaignID,
		"day_budget":    budget,
	}
	var resp struct {
		Result   int    `json:"result"`
		ErrorMsg string `json:"error_msg"`
	}
	if err := c.post("/rest/openapi/campaign/update", body, accessToken, &resp); err != nil {
		return err
	}
	if resp.Result != 1 {
		return fmt.Errorf("kwai update campaign budget error: %s", resp.ErrorMsg)
	}
	return nil
}

func (c *Client) UpdateCampaignStatus(accessToken, advertiserID, campaignID, status string) error {
	body := map[string]any{
		"access_token":  accessToken,
		"advertiser_id": advertiserID,
		"campaign_id":   campaignID,
		"status":        status,
	}
	var resp struct {
		Result   int    `json:"result"`
		ErrorMsg string `json:"error_msg"`
	}
	if err := c.post("/rest/openapi/campaign/status/update", body, accessToken, &resp); err != nil {
		return err
	}
	if resp.Result != 1 {
		return fmt.Errorf("kwai update campaign status error: %s", resp.ErrorMsg)
	}
	return nil
}

// ── 广告组 ─────────────────────────────────────────────────────

func (c *Client) GetAdGroups(accessToken, advertiserID, campaignID string, page, pageSize int) ([]*platform.AdGroupInfo, int64, error) {
	params := url.Values{}
	params.Set("access_token", accessToken)
	params.Set("advertiser_id", advertiserID)
	params.Set("page", fmt.Sprintf("%d", page))
	params.Set("page_size", fmt.Sprintf("%d", pageSize))
	if campaignID != "" {
		params.Set("campaign_id", campaignID)
	}
	var resp struct {
		Result   int    `json:"result"`
		ErrorMsg string `json:"error_msg"`
		Groups   []struct {
			GroupID    string  `json:"group_id"`
			GroupName  string  `json:"group_name"`
			CampaignID string  `json:"campaign_id"`
			Status     string  `json:"status"`
			DayBudget  float64 `json:"day_budget"`
			BidType    string  `json:"bid_type"`
			BidPrice   float64 `json:"bid_price"`
		} `json:"groups"`
		TotalCount int64 `json:"total_count"`
	}
	if err := c.get("/rest/openapi/adgroup/list", params, accessToken, &resp); err != nil {
		return nil, 0, err
	}
	if resp.Result != 1 {
		return nil, 0, fmt.Errorf("kwai get adgroups error: %s", resp.ErrorMsg)
	}
	result := make([]*platform.AdGroupInfo, 0, len(resp.Groups))
	for _, item := range resp.Groups {
		result = append(result, &platform.AdGroupInfo{
			AdGroupID:   item.GroupID,
			AdGroupName: item.GroupName,
			CampaignID:  item.CampaignID,
			Status:      item.Status,
			Budget:      item.DayBudget,
			BidType:     item.BidType,
			BidPrice:    item.BidPrice,
		})
	}
	return result, resp.TotalCount, nil
}

func (c *Client) UpdateAdGroupBudget(accessToken, advertiserID, adGroupID string, budget float64) error {
	body := map[string]any{
		"access_token":  accessToken,
		"advertiser_id": advertiserID,
		"group_id":      adGroupID,
		"day_budget":    budget,
	}
	var resp struct {
		Result   int    `json:"result"`
		ErrorMsg string `json:"error_msg"`
	}
	if err := c.post("/rest/openapi/adgroup/update", body, accessToken, &resp); err != nil {
		return err
	}
	if resp.Result != 1 {
		return fmt.Errorf("kwai update adgroup budget error: %s", resp.ErrorMsg)
	}
	return nil
}

func (c *Client) UpdateAdGroupStatus(accessToken, advertiserID, adGroupID, status string) error {
	body := map[string]any{
		"access_token":  accessToken,
		"advertiser_id": advertiserID,
		"group_id":      adGroupID,
		"status":        status,
	}
	var resp struct {
		Result   int    `json:"result"`
		ErrorMsg string `json:"error_msg"`
	}
	if err := c.post("/rest/openapi/adgroup/status/update", body, accessToken, &resp); err != nil {
		return err
	}
	if resp.Result != 1 {
		return fmt.Errorf("kwai update adgroup status error: %s", resp.ErrorMsg)
	}
	return nil
}

// ── 广告 ───────────────────────────────────────────────────────

func (c *Client) GetAds(accessToken, advertiserID, adGroupID string, page, pageSize int) ([]*platform.AdInfo, int64, error) {
	params := url.Values{}
	params.Set("access_token", accessToken)
	params.Set("advertiser_id", advertiserID)
	params.Set("page", fmt.Sprintf("%d", page))
	params.Set("page_size", fmt.Sprintf("%d", pageSize))
	if adGroupID != "" {
		params.Set("group_id", adGroupID)
	}
	var resp struct {
		Result   int    `json:"result"`
		ErrorMsg string `json:"error_msg"`
		Ads      []struct {
			AdID    string `json:"ad_id"`
			AdName  string `json:"ad_name"`
			GroupID string `json:"group_id"`
			Status  string `json:"status"`
		} `json:"ads"`
		TotalCount int64 `json:"total_count"`
	}
	if err := c.get("/rest/openapi/ad/list", params, accessToken, &resp); err != nil {
		return nil, 0, err
	}
	if resp.Result != 1 {
		return nil, 0, fmt.Errorf("kwai get ads error: %s", resp.ErrorMsg)
	}
	result := make([]*platform.AdInfo, 0, len(resp.Ads))
	for _, item := range resp.Ads {
		result = append(result, &platform.AdInfo{
			AdID:      item.AdID,
			AdName:    item.AdName,
			AdGroupID: item.GroupID,
			Status:    item.Status,
		})
	}
	return result, resp.TotalCount, nil
}

// ── 报表 ────────────────────────────────────────────────────────

// GetReport Kwai 报表接口暂未接入，返回全零占位。
func (c *Client) GetReport(_ context.Context, _, _, _, _ string) (*platform.ReportResult, error) {
	return &platform.ReportResult{}, nil
}

// ── HTTP 工具方法 ───────────────────────────────────────────────

func (c *Client) get(path string, params url.Values, accessToken string, out any) error {
	req, err := http.NewRequest(http.MethodGet, apiBaseURL+path+"?"+params.Encode(), nil)
	if err != nil {
		return err
	}
	if accessToken != "" {
		req.Header.Set("Authorization", "Bearer "+accessToken)
	}
	return c.do(req, out)
}

func (c *Client) post(path string, body any, accessToken string, out any) error {
	b, err := json.Marshal(body)
	if err != nil {
		return err
	}
	req, err := http.NewRequest(http.MethodPost, apiBaseURL+path, bytes.NewReader(b))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/json")
	if accessToken != "" {
		req.Header.Set("Authorization", "Bearer "+accessToken)
	}
	return c.do(req, out)
}

// GetReportStats 快手报表统计接口（待实现，当前返回零值占位）。
func (c *Client) GetReportStats(_ string, _ []string, _, _ string) (*platform.ReportStats, error) {
	return &platform.ReportStats{}, nil
}

// GetAdvertiserReport 快手逐广告主报表（待实现，返回零值占位）。
func (c *Client) GetAdvertiserReport(_ string, advertiserIDs []string, _, _ string) ([]*platform.AdvertiserReportItem, error) {
	items := make([]*platform.AdvertiserReportItem, 0, len(advertiserIDs))
	for _, id := range advertiserIDs {
		items = append(items, &platform.AdvertiserReportItem{AdvertiserID: id})
	}
	return items, nil
}

// GetAdvertiserDailyBudget 快手广告主日预算（待实现，返回空 map）。
func (c *Client) GetAdvertiserDailyBudget(_ string, _ []string) (map[string]float64, error) {
	return map[string]float64{}, nil
}

// GetAdGroupReport 快手广告组报表（待实现，返回零值占位）。
func (c *Client) GetAdGroupReport(_ string, _ string, adGroupIDs []string, _, _ string) ([]*platform.AdGroupReportItem, error) {
	items := make([]*platform.AdGroupReportItem, 0, len(adGroupIDs))
	for _, id := range adGroupIDs {
		items = append(items, &platform.AdGroupReportItem{AdGroupID: id})
	}
	return items, nil
}

// GetCampaignReport 快手推广系列报表（待实现，返回零值占位）。
func (c *Client) GetCampaignReport(_ string, _ string, campaignIDs []string, _, _ string) ([]*platform.CampaignReportItem, error) {
	items := make([]*platform.CampaignReportItem, 0, len(campaignIDs))
	for _, id := range campaignIDs {
		items = append(items, &platform.CampaignReportItem{CampaignID: id})
	}
	return items, nil
}

func (c *Client) do(req *http.Request, out any) error {
	resp, err := c.httpClient.Do(req)
	if err != nil {
		return fmt.Errorf("kwai http request failed: %w", err)
	}
	defer resp.Body.Close()

	data, err := io.ReadAll(resp.Body)
	if err != nil {
		return fmt.Errorf("kwai read response failed: %w", err)
	}
	if err := json.Unmarshal(data, out); err != nil {
		return fmt.Errorf("kwai parse response failed: %w (body: %.200s)", err, data)
	}
	return nil
}
