## 0. 数据库迁移

- [x] 0.1 在 `migrations/` 新增迁移文件，为 `advertisers` 表添加 `daily_budget DECIMAL(18,2) DEFAULT NULL` 字段
- [x] 0.2 更新 `internal/model/entity/advertiser.go` 实体结构体，新增 `DailyBudget *float64` 字段（可为 null）

## 1. 后端 DTO 与接口定义

- [x] 1.1 在 `internal/model/dto/` 新增 `AdvertiserReportDTO`，包含字段：advertiser_id、spend、clicks、impressions、conversion、cost_per_conversion、cpa（skan_click_time_cost_per_conversion）、currency、daily_budget
- [x] 1.2 在 `internal/model/dto/` 新增 `StatsReportRequest`（platform、advertiser_ids[]、start_date、end_date）和 `StatsReportResponse`（list []AdvertiserReportDTO、total_metrics AdvertiserReportDTO）
- [x] 1.3 在 `internal/router/router.go` 注册路由 `GET /api/v1/stats/report`

## 2. TikTok 平台报表接口适配

- [x] 2.1 在 `internal/service/platform/tiktok/` 新增 `GetAdvertiserReport(accessToken string, advertiserIDs []string, startDate, endDate string) ([]*AdvertiserReportDTO, error)` 方法
- [x] 2.2 实现 TikTok 接口调用：构造请求 URL（data_level=AUCTION_ADVERTISER，report_type=BASIC，enable_total_metrics=true），解析返回 JSON，按 dimensions.advertiser_id 匹配 metrics 字段映射到 DTO
- [x] 2.3 在 `internal/service/platform_interface.go` 中为 Platform 接口添加 `GetAdvertiserReport` 方法签名
- [x] 2.4 在 `internal/service/platform/kwai/` 添加 `GetAdvertiserReport` 空实现（返回全0数据，不报错）
- [x] 2.5 在 `internal/service/platform/tiktok/` 新增 `GetAdvertiserInfo(accessToken string, advertiserIDs []string) (map[string]float64, error)` 方法，调用 TikTok `/open_api/v1.3/advertiser/info/` 接口，返回 advertiser_id → daily_budget 映射
- [x] 2.6 在 `internal/service/platform_interface.go` 中为 Platform 接口添加 `GetAdvertiserDailyBudget(accessToken string, advertiserIDs []string) (map[string]float64, error)` 方法签名；Kwai 空实现返回空 map

## 3. 后端缓存与批次拆分服务

- [x] 3.1 在 `internal/service/stats/` 新增 `GetAdvertiserReport` 服务方法，接收完整广告主 ID 列表，按5个一批拆分
- [x] 3.2 实现缓存查找逻辑：优先从 Redis 读取 key `stats:report:{platform}:{advertiser_id}:{start_date}:{end_date}`，未命中则收集到待请求批次
- [x] 3.3 对未命中缓存的广告主分批（≤5个/批）并发调用平台接口（goroutine + WaitGroup），合并结果
- [x] 3.4 将新拉取的数据写入 Redis 缓存，TTL = 5分钟 + rand(-30, +30)秒
- [x] 3.5 对缺失广告主（平台未返回数据）补充全0的 DTO 占位数据
- [x] 3.6 实现 total_metrics 汇总计算（spend/clicks/impressions/conversion 求和）
- [x] 3.7 在 `/stats/report` 响应中为每个广告主附加 `daily_budget` 字段（从 DB `advertisers.daily_budget` 读取，无需实时调用平台接口）

## 3.5 同步服务：广告主日预算写入

- [x] 3.5.1 在 `internal/service/sync/` 全量同步流程中，调用 `GetAdvertiserDailyBudget` 获取每个广告主的日预算，写入 `advertisers.daily_budget`
- [x] 3.5.2 在手动同步（`POST /advertisers/:id/sync`）中同样更新 `daily_budget`
- [x] 3.5.3 更新 `internal/repository/advertiser/` 的 UPSERT 逻辑，支持 `daily_budget` 字段的写入

## 4. 后端 Handler 与参数校验

- [x] 4.1 在 `internal/handler/stats/` 新增 `GetAdvertiserReport` handler，解析并校验请求参数
- [x] 4.2 校验 end_date - start_date ≤ 30天，超出返回 code=1002
- [x] 4.3 校验 platform 必填、advertiser_ids 非空，校验失败返回 code=1002
- [x] 4.4 调用 stats service，封装标准响应结构返回

## 5. iOS 网络层与数据模型

- [x] 5.1 在 iOS 网络层新增 `AdvertiserReportMetrics` 模型（Codable），对应后端 AdvertiserReportDTO 字段
- [x] 5.2 在 iOS 网络层新增 `StatsReportRequest` 和 `StatsReportResponse` 模型
- [x] 5.3 在 `APIClient` 或网络服务中新增 `fetchAdvertiserReport(platform:advertiserIDs:startDate:endDate:)` 异步方法，调用 `GET /api/v1/stats/report`

## 6. iOS AdvertiserListViewModel 更新

- [x] 6.1 在 AdvertiserListViewModel 中新增 `reportMetrics: [String: AdvertiserReportMetrics]`（key 为 advertiser_id）、`totalMetrics: AdvertiserReportMetrics?`、`isLoadingMetrics: Bool`
- [x] 6.2 新增 `selectedStartDate` 和 `selectedEndDate` 属性，默认值为近7天（today-7 至 today-1）
- [x] 6.3 实现 `loadMetrics()` 方法：从 reportMetrics 已有列表获取所有 advertiser_id，按5个一批并发调用 API，合并结果填充 reportMetrics 和 totalMetrics
- [x] 6.4 在广告主列表加载完成后自动触发 `loadMetrics()`
- [x] 6.5 日期区间变更时重新触发 `loadMetrics()`，清空旧 reportMetrics

## 7. iOS 日期筛选器组件

- [x] 7.1 新建 `DateRangePickerView` SwiftUI 组件，包含开始日期和结束日期两个 DatePicker，展示在账号列表顶部筛选区域
- [x] 7.2 实现30天跨度校验：结束日期超出开始日期30天时自动截断，并通过 Toast/Alert 提示用户
- [x] 7.3 切换日期后通知 ViewModel 更新（通过 Binding 或 onChange）

## 8. iOS 账号 Cell 指标展示

- [x] 8.1 更新 AdvertiserCell（或新建 AdvertiserMetricsView 子组件），在基础信息下方添加 2行×3列指标网格
- [x] 8.2 指标网格展示：消耗、点击、展示、转化、CPA、日预算，字号 caption，标签用灰色副标题
- [x] 8.3 指标加载中时显示 skeleton loading（灰色圆角矩形占位）
- [x] 8.4 指标数据为0时显示 "0.00"（带货币符号的数值）或 "0"（整数指标）
- [x] 8.5 消耗/CPA/日预算保留2位小数，点击/展示/转化显示整数，超过10000时显示 "1.2w" 等缩写

## 9. iOS 汇总行展示

- [x] 9.1 在账号列表底部（Section footer 或固定底部视图）新增汇总行，展示 totalMetrics 的各指标合计
- [x] 9.2 汇总行加载中时显示 skeleton loading
- [x] 9.3 汇总行布局与账号 Cell 指标网格保持一致的列宽

## 10. 集成测试与边界验证

- [x] 10.1 后端：验证 advertiser_ids 超过5个时自动分批，缓存 key 格式正确，TTL 正常设置
- [x] 10.2 后端：验证 Kwai platform 返回全0数据不报错
- [x] 10.3 iOS：验证日期跨度30天校验与截断逻辑
- [x] 10.4 iOS：验证某批次请求失败时其他批次数据正常显示，失败批次指标显示0
- [x] 10.5 iOS：验证空数据（所有广告主无投放）时汇总行和各 Cell 均显示 "0.00"
