## 1. 后端：数据模型与接口定义

- [ ] 1.1 在 `internal/model/dto/` 新增 `ReportStats` 结构体（Spend float64, Conversion int64, Clicks int64, Impressions int64）
- [ ] 1.2 更新 `StatsResponse` DTO，移除 `active_advertisers`、`campaign_count`、`adgroup_count`，新增 `spend`、`conversion`、`clicks`、`impressions` 字段
- [ ] 1.3 在 `internal/service/platform_interface.go` 的 `Platform` 接口新增 `GetReportStats(accessToken string, advertiserIDs []string, startDate, endDate string) (*ReportStats, error)` 方法

## 2. 后端：TikTok Report API 实现

- [ ] 2.1 在 `internal/service/platform/tiktok/` 新增 `GetReportStats` 方法，调用 `GET /open_api/v1.3/report/integrated/get`，参数：`data_level=AUCTION_ADVERTISER`、`report_type=BASIC`、`dimensions=["advertiser_id"]`、`metrics=["spend","conversion","clicks","impressions"]`、`enable_total_metrics=true`
- [ ] 2.2 解析响应 `data.total_metrics`，映射到 `ReportStats`（spend string→float64，其余 string→int64）
- [ ] 2.3 处理空 advertiserIDs 时直接返回零值；平台 API 非 0 code 时返回 error

## 3. 后端：Kwai Report API 预留实现

- [ ] 3.1 在 `internal/service/platform/kwai/` 新增 `GetReportStats` 方法，返回 `&ReportStats{}, nil`（零值占位，满足 Platform 接口，不报错）

## 4. 后端：Stats 服务重写

- [ ] 4.1 重写 `internal/service/stats/` 的统计逻辑：从本地 `advertisers` 表按 `user_id` + `platform`（status=1）查询所有 advertiser_id 列表
- [ ] 4.2 从 `platform_tokens` 表取当前用户+平台的有效 access_token 并解密
- [ ] 4.3 实现日期范围计算：end_date = 今日 UTC，start_date = end_date - 30 天，格式化为 `YYYY-MM-DD`
- [ ] 4.4 实现 Redis 缓存逻辑：key = `stats:report:{user_id}:{platform}:{start_date}:{end_date}`，TTL 15 分钟；命中缓存直接返回，未命中则调用 API 后写入缓存
- [ ] 4.5 实现 `platform=all` 场景：分别调用 TikTok 和 Kwai 的 `GetReportStats`，将两个平台 `ReportStats` 的各字段数值相加后返回
- [ ] 4.6 处理无广告主或无有效 token 边界情况：返回零值 `ReportStats{}`，不报错

## 5. 后端：Stats Handler 更新

- [ ] 5.1 更新 `internal/handler/stats/` handler，调用重写后的 stats 服务，返回新 `StatsResponse` 结构

## 6. iOS：网络层 DTO 更新

- [ ] 6.1 更新 `StatsResponse` Swift 结构体：移除旧字段，新增 `spend: Double`、`conversion: Int`、`clicks: Int`、`impressions: Int`

## 7. iOS：Dashboard UI 更新

- [ ] 7.1 更新 `DashboardView` 的 4 张统计卡片，标题改为"总消耗"、"转化"、"点击"、"展示"，绑定新 DTO 字段
- [ ] 7.2 spend 显示格式化为保留 2 位小数（`String(format: "%.2f", spend)`），其余整数指标直接展示
- [ ] 7.3 验证平台筛选切换（全部/TikTok/Kwai）触发重新请求 `/stats?platform=<selected>` 并更新卡片
