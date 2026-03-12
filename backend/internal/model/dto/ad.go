package dto

// ── 广告列表 ───────────────────────────────────────────────────

type AdListRequest struct {
	AdgroupID uint64 `form:"adgroup_id"` // 0 = 不过滤
	Keyword   string `form:"keyword"`    // 按 ID 或名称模糊搜索
	Page      int    `form:"page,default=1"`
	PageSize  int    `form:"page_size,default=20"`
}

type AdItem struct {
	ID           uint64 `json:"id"`
	AdID         string `json:"ad_id"`
	AdName       string `json:"ad_name"`
	AdgroupID    uint64 `json:"adgroup_id"`
	AdgroupName  string `json:"adgroup_name"` // 关联查询后填入
	Status       string `json:"status"`
	CreativeType string `json:"creative_type"`
}
