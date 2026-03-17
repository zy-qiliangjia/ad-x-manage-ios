# 数据库迁移记录

本文档记录所有数据库结构变更，按时间倒序排列。

---

## 2025-xx-xx: 广告指标字段扩展（ads-manage-enhanced-data-view）

### 变更说明

为支持广告管理页各层级展示真实的点击/展示/转化指标，在 `campaigns` 和 `ad_groups` 表中新增指标字段。

### 执行顺序

以下 SQL 按顺序执行（先 campaigns，再 ad_groups）。

### 1. campaigns 表 — 新增指标列

```sql
ALTER TABLE campaigns
    ADD COLUMN clicks      BIGINT NOT NULL DEFAULT 0 COMMENT '点击数（最近一次同步值）' AFTER spend,
    ADD COLUMN impressions BIGINT NOT NULL DEFAULT 0 COMMENT '展示数（最近一次同步值）' AFTER clicks,
    ADD COLUMN conversions BIGINT NOT NULL DEFAULT 0 COMMENT '转化数（最近一次同步值）' AFTER impressions;
```

**验证：**
```sql
DESCRIBE campaigns;
-- 确认 clicks, impressions, conversions 列存在且 DEFAULT 0
```

### 2. ad_groups 表 — 新增指标列

```sql
ALTER TABLE ad_groups
    ADD COLUMN clicks      BIGINT NOT NULL DEFAULT 0 COMMENT '点击数（最近一次同步值）' AFTER spend,
    ADD COLUMN impressions BIGINT NOT NULL DEFAULT 0 COMMENT '展示数（最近一次同步值）' AFTER clicks,
    ADD COLUMN conversions BIGINT NOT NULL DEFAULT 0 COMMENT '转化数（最近一次同步值）' AFTER impressions;
```

**验证：**
```sql
DESCRIBE ad_groups;
-- 确认 clicks, impressions, conversions 列存在且 DEFAULT 0
```

### 回滚方案

如需回滚，按如下顺序执行（先 ad_groups，再 campaigns）：

```sql
-- 回滚 ad_groups
ALTER TABLE ad_groups
    DROP COLUMN conversions,
    DROP COLUMN impressions,
    DROP COLUMN clicks;

-- 回滚 campaigns
ALTER TABLE campaigns
    DROP COLUMN conversions,
    DROP COLUMN impressions,
    DROP COLUMN clicks;
```

### MySQL 8.0 优化说明

MySQL 8.0+ 对 `INT`/`BIGINT` 类型的 `ADD COLUMN` 支持 `ALGORITHM=INSTANT`，可避免锁表：

```sql
ALTER TABLE campaigns
    ADD COLUMN clicks      BIGINT NOT NULL DEFAULT 0 AFTER spend,
    ADD COLUMN impressions BIGINT NOT NULL DEFAULT 0 AFTER clicks,
    ADD COLUMN conversions BIGINT NOT NULL DEFAULT 0 AFTER impressions,
    ALGORITHM=INSTANT;

ALTER TABLE ad_groups
    ADD COLUMN clicks      BIGINT NOT NULL DEFAULT 0 AFTER spend,
    ADD COLUMN impressions BIGINT NOT NULL DEFAULT 0 AFTER clicks,
    ADD COLUMN conversions BIGINT NOT NULL DEFAULT 0 AFTER impressions,
    ALGORITHM=INSTANT;
```

### 数据回填

迁移完成后，已有数据的 `clicks`/`impressions`/`conversions` 均为 0。
可通过广告主账号页面的「手动同步」按钮触发数据回填（需平台 API 支持返回这些字段）。

---
