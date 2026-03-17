## ADDED Requirements

### Requirement: Summary stats API endpoint
系统 SHALL 提供 `GET /api/v1/stats/summary` 接口，按指定层级（advertiser / campaign / adgroup）聚合消耗、点击、展示、转化指标，并返回数据最后更新时间。

接口参数：
- `scope`：`advertiser` | `campaign` | `adgroup`（必填）
- `scope_id`：对应层级的数据库 ID（必填）
- `date_from`：`YYYY-MM-DD` 格式（可选，按 updated_at 日期过滤）
- `date_to`：`YYYY-MM-DD` 格式（可选）

响应结构：
```json
{
  "code": 0,
  "message": "ok",
  "data": {
    "spend": 12345.67,
    "clicks": 1000,
    "impressions": 50000,
    "conversions": 200,
    "last_updated_at": "2025-01-15T14:30:00Z"
  }
}
```

#### Scenario: 按广告主聚合
- **WHEN** 客户端请求 `GET /api/v1/stats/summary?scope=advertiser&scope_id=1`
- **THEN** 系统聚合该广告主下所有 campaigns 的 spend/clicks/impressions/conversions 总和并返回

#### Scenario: 按推广系列聚合
- **WHEN** 客户端请求 `GET /api/v1/stats/summary?scope=campaign&scope_id=5`
- **THEN** 系统聚合该推广系列下所有 adgroups 的指标总和并返回

#### Scenario: 按广告组聚合
- **WHEN** 客户端请求 `GET /api/v1/stats/summary?scope=adgroup&scope_id=10`
- **THEN** 系统直接返回该广告组自身的指标值

#### Scenario: 日期过滤
- **WHEN** 请求包含 `date_from=2025-01-01&date_to=2025-01-07`
- **THEN** 系统仅统计 `updated_at` 在该日期区间内的记录，并返回过滤后的聚合数据

#### Scenario: 无权限访问
- **WHEN** 请求的 scope_id 不属于当前登录用户
- **THEN** 系统返回 HTTP 403，code=1004

#### Scenario: 数据为空时
- **WHEN** 指定范围内没有任何记录
- **THEN** 系统返回所有指标值为 0，`last_updated_at` 为 null

---

### Requirement: DB 新增指标列
数据库 `campaigns` 表 SHALL 新增 `clicks BIGINT NOT NULL DEFAULT 0`、`impressions BIGINT NOT NULL DEFAULT 0`、`conversions BIGINT NOT NULL DEFAULT 0` 列。
数据库 `ad_groups` 表 SHALL 同样新增上述三列。

#### Scenario: 迁移不破坏现有数据
- **WHEN** 执行 ALTER TABLE 添加三列
- **THEN** 现有记录的新列值均为 0，原有字段数据不受影响

#### Scenario: 同步写入指标
- **WHEN** 触发广告主手动同步或 OAuth 授权后全量同步
- **THEN** 若平台 API 返回 clicks/impressions/conversions 字段，UPSERT 时同步写入对应列
