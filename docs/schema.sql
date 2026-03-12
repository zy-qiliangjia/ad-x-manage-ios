-- ============================================================
-- 广告聚合管理平台 数据库建表 SQL
-- 数据库：MySQL 8.0+
-- 字符集：utf8mb4
-- 排序规则：utf8mb4_unicode_ci
-- ============================================================

CREATE DATABASE IF NOT EXISTS `ad_manage_x`
    DEFAULT CHARACTER SET utf8mb4
    DEFAULT COLLATE utf8mb4_unicode_ci;

USE `ad_manage_x`;

-- ------------------------------------------------------------
-- 1. 用户表
-- ------------------------------------------------------------
CREATE TABLE `users` (
    `id`            BIGINT UNSIGNED  NOT NULL AUTO_INCREMENT COMMENT '主键',
    `email`         VARCHAR(255)     NOT NULL COMMENT '登录邮箱',
    `password_hash` VARCHAR(255)     NOT NULL COMMENT 'bcrypt 密码哈希',
    `name`          VARCHAR(100)     NOT NULL DEFAULT '' COMMENT '用户昵称',
    `status`        TINYINT UNSIGNED NOT NULL DEFAULT 1 COMMENT '状态: 1正常 0禁用',
    `last_login_at` DATETIME                  DEFAULT NULL COMMENT '最后登录时间',
    `created_at`    DATETIME         NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at`    DATETIME         NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_email` (`email`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='用户表';


-- ------------------------------------------------------------
-- 2. 平台 OAuth Token 表
--    一个用户可授权多个平台，同平台也可授权多个账号主体
-- ------------------------------------------------------------
CREATE TABLE `platform_tokens` (
    `id`                BIGINT UNSIGNED  NOT NULL AUTO_INCREMENT COMMENT '主键',
    `user_id`           BIGINT UNSIGNED  NOT NULL COMMENT '关联 users.id',
    `platform`          VARCHAR(20)      NOT NULL COMMENT '平台: tiktok | kwai',
    `open_user_id`      VARCHAR(100)     NOT NULL COMMENT '平台侧用户唯一标识',
    `access_token_enc`  TEXT             NOT NULL COMMENT 'AES-256-GCM 加密后的 access_token',
    `refresh_token_enc` TEXT                      DEFAULT NULL COMMENT 'AES-256-GCM 加密后的 refresh_token',
    `expires_at`        DATETIME                  DEFAULT NULL COMMENT 'access_token 过期时间',
    `scope`             VARCHAR(500)              DEFAULT NULL COMMENT '授权 scope',
    `status`            TINYINT UNSIGNED NOT NULL DEFAULT 1 COMMENT '状态: 1有效 0失效/已解绑',
    `created_at`        DATETIME         NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at`        DATETIME         NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_user_platform_openid` (`user_id`, `platform`, `open_user_id`),
    KEY `idx_user_platform` (`user_id`, `platform`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='平台 OAuth Token 表';


-- ------------------------------------------------------------
-- 3. 广告主账号表
--    通过 OAuth 后拉取到的广告主账号列表
-- ------------------------------------------------------------
CREATE TABLE `advertisers` (
    `id`              BIGINT UNSIGNED  NOT NULL AUTO_INCREMENT COMMENT '主键',
    `token_id`        BIGINT UNSIGNED  NOT NULL COMMENT '关联 platform_tokens.id',
    `user_id`         BIGINT UNSIGNED  NOT NULL COMMENT '关联 users.id',
    `platform`        VARCHAR(20)      NOT NULL COMMENT '平台: tiktok | kwai',
    `advertiser_id`   VARCHAR(100)     NOT NULL COMMENT '平台广告主 ID',
    `advertiser_name` VARCHAR(255)     NOT NULL DEFAULT '' COMMENT '广告主名称',
    `currency`        VARCHAR(10)               DEFAULT NULL COMMENT '货币单位，如 USD CNY',
    `timezone`        VARCHAR(50)               DEFAULT NULL COMMENT '账号时区',
    `status`          TINYINT UNSIGNED NOT NULL DEFAULT 1 COMMENT '状态: 1正常 0停用',
    `synced_at`       DATETIME                  DEFAULT NULL COMMENT '最后同步时间',
    `created_at`      DATETIME         NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at`      DATETIME         NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_platform_advertiser` (`platform`, `advertiser_id`),
    KEY `idx_user_platform` (`user_id`, `platform`),
    KEY `idx_token_id` (`token_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='广告主账号表';


-- ------------------------------------------------------------
-- 4. 推广系列表
-- ------------------------------------------------------------
CREATE TABLE `campaigns` (
    `id`            BIGINT UNSIGNED  NOT NULL AUTO_INCREMENT COMMENT '主键',
    `advertiser_id` BIGINT UNSIGNED  NOT NULL COMMENT '关联 advertisers.id',
    `platform`      VARCHAR(20)      NOT NULL COMMENT '平台: tiktok | kwai',
    `campaign_id`   VARCHAR(100)     NOT NULL COMMENT '平台 campaign ID',
    `campaign_name` VARCHAR(255)     NOT NULL DEFAULT '' COMMENT '推广系列名称',
    `status`        VARCHAR(50)      NOT NULL DEFAULT '' COMMENT '投放状态，保存平台原始值',
    `budget_mode`   VARCHAR(50)               DEFAULT NULL COMMENT '预算类型: BUDGET_MODE_DAY | BUDGET_MODE_TOTAL',
    `budget`        DECIMAL(18, 2)   NOT NULL DEFAULT 0.00 COMMENT '预算金额',
    `spend`         DECIMAL(18, 2)   NOT NULL DEFAULT 0.00 COMMENT '总消耗（定期同步）',
    `objective`     VARCHAR(100)              DEFAULT NULL COMMENT '推广目标',
    `created_at`    DATETIME         NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at`    DATETIME         NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_platform_campaign` (`platform`, `campaign_id`),
    KEY `idx_advertiser_id` (`advertiser_id`),
    KEY `idx_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='推广系列表';


-- ------------------------------------------------------------
-- 5. 广告组表
-- ------------------------------------------------------------
CREATE TABLE `ad_groups` (
    `id`            BIGINT UNSIGNED  NOT NULL AUTO_INCREMENT COMMENT '主键',
    `advertiser_id` BIGINT UNSIGNED  NOT NULL COMMENT '关联 advertisers.id',
    `campaign_id`   BIGINT UNSIGNED  NOT NULL COMMENT '关联 campaigns.id',
    `platform`      VARCHAR(20)      NOT NULL COMMENT '平台: tiktok | kwai',
    `adgroup_id`    VARCHAR(100)     NOT NULL COMMENT '平台广告组 ID',
    `adgroup_name`  VARCHAR(255)     NOT NULL DEFAULT '' COMMENT '广告组名称',
    `status`        VARCHAR(50)      NOT NULL DEFAULT '' COMMENT '投放状态，保存平台原始值',
    `budget_mode`   VARCHAR(50)               DEFAULT NULL COMMENT '预算类型',
    `budget`        DECIMAL(18, 2)   NOT NULL DEFAULT 0.00 COMMENT '预算金额',
    `spend`         DECIMAL(18, 2)   NOT NULL DEFAULT 0.00 COMMENT '总消耗（定期同步）',
    `bid_type`      VARCHAR(50)               DEFAULT NULL COMMENT '出价方式',
    `bid_price`     DECIMAL(18, 4)            DEFAULT NULL COMMENT '出价金额',
    `created_at`    DATETIME         NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at`    DATETIME         NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_platform_adgroup` (`platform`, `adgroup_id`),
    KEY `idx_advertiser_id` (`advertiser_id`),
    KEY `idx_campaign_id` (`campaign_id`),
    KEY `idx_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='广告组表';


-- ------------------------------------------------------------
-- 6. 广告表
-- ------------------------------------------------------------
CREATE TABLE `ads` (
    `id`            BIGINT UNSIGNED  NOT NULL AUTO_INCREMENT COMMENT '主键',
    `advertiser_id` BIGINT UNSIGNED  NOT NULL COMMENT '关联 advertisers.id',
    `adgroup_id`    BIGINT UNSIGNED  NOT NULL COMMENT '关联 ad_groups.id',
    `platform`      VARCHAR(20)      NOT NULL COMMENT '平台: tiktok | kwai',
    `ad_id`         VARCHAR(100)     NOT NULL COMMENT '平台广告 ID',
    `ad_name`       VARCHAR(255)     NOT NULL DEFAULT '' COMMENT '广告名称',
    `status`        VARCHAR(50)      NOT NULL DEFAULT '' COMMENT '投放状态，保存平台原始值',
    `creative_type` VARCHAR(50)               DEFAULT NULL COMMENT '创意类型: 视频/图片',
    `created_at`    DATETIME         NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at`    DATETIME         NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_platform_ad` (`platform`, `ad_id`),
    KEY `idx_advertiser_id` (`advertiser_id`),
    KEY `idx_adgroup_id` (`adgroup_id`),
    KEY `idx_status` (`status`),
    KEY `idx_ad_name` (`ad_name`(50))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='广告表';


-- ------------------------------------------------------------
-- 7. 操作日志表
--    记录所有写操作：修改预算、开启/暂停投放
-- ------------------------------------------------------------
CREATE TABLE `operation_logs` (
    `id`            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键',
    `user_id`       BIGINT UNSIGNED NOT NULL COMMENT '操作人 users.id',
    `advertiser_id` BIGINT UNSIGNED NOT NULL COMMENT '广告主 advertisers.id',
    `platform`      VARCHAR(20)     NOT NULL COMMENT '平台: tiktok | kwai',
    `action`        VARCHAR(50)     NOT NULL COMMENT '操作类型: budget_update | status_enable | status_pause',
    `target_type`   VARCHAR(20)     NOT NULL COMMENT '操作对象: campaign | adgroup | ad',
    `target_id`     VARCHAR(100)    NOT NULL COMMENT '平台侧对象 ID',
    `target_name`   VARCHAR(255)             DEFAULT NULL COMMENT '对象名称（冗余，便于日志查阅）',
    `before_val`    JSON                     DEFAULT NULL COMMENT '操作前的值',
    `after_val`     JSON                     DEFAULT NULL COMMENT '操作后的值',
    `result`        TINYINT UNSIGNED NOT NULL DEFAULT 1 COMMENT '执行结果: 1成功 0失败',
    `fail_reason`   VARCHAR(500)             DEFAULT NULL COMMENT '失败原因',
    `created_at`    DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_user_id` (`user_id`),
    KEY `idx_advertiser_id` (`advertiser_id`),
    KEY `idx_target` (`target_type`, `target_id`),
    KEY `idx_created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='操作日志表';
