package main

import (
	"fmt"
	"os"

	"go.uber.org/zap"

	"ad-x-manage/backend/internal/config"
	"ad-x-manage/backend/internal/model/entity"
	"ad-x-manage/backend/internal/pkg/database"
)

func main() {
	cfg, err := config.Load()
	if err != nil {
		fmt.Fprintf(os.Stderr, "config load error: %v\n", err)
		os.Exit(1)
	}

	db, err := database.New(&cfg.DB, zap.NewNop())
	if err != nil {
		fmt.Fprintf(os.Stderr, "database init error: %v\n", err)
		os.Exit(1)
	}

	models := []any{
		&entity.User{},
		&entity.PlatformToken{},
		&entity.Advertiser{},
		&entity.Campaign{},
		&entity.AdGroup{},
		&entity.Ad{},
		&entity.OperationLog{},
	}

	// 手动迁移：将 platform_tokens 的加密列重命名为明文列名。
	// 通过 INFORMATION_SCHEMA 检查旧列是否存在，幂等安全。
	fmt.Println("renaming token columns if needed...")
	var colCount int64
	db.Raw(`SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
		WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'platform_tokens'
		AND COLUMN_NAME = 'access_token_enc'`).Scan(&colCount)
	if colCount > 0 {
		if err := db.Exec(`ALTER TABLE platform_tokens
			CHANGE COLUMN access_token_enc  access_token  TEXT NOT NULL,
			CHANGE COLUMN refresh_token_enc refresh_token TEXT`).Error; err != nil {
			fmt.Fprintf(os.Stderr, "rename columns error: %v\n", err)
			os.Exit(1)
		}
		fmt.Println("columns renamed")
	} else {
		fmt.Println("columns already renamed, skipping")
	}

	// 清理历史重复索引（幂等：索引不存在时忽略错误）
	db.Exec(`ALTER TABLE platform_tokens DROP INDEX uk_user_platform_openid`)

	// 修复多用户授权同一第三方账号的 bug：
	// 将各表的 unique key 从平台维度改为用户+平台维度，
	// 使不同用户授权相同广告主/系列/广告组/广告时各自拥有独立记录。
	fmt.Println("dropping old platform-scoped unique indexes...")
	db.Exec(`ALTER TABLE advertisers DROP INDEX uk_platform_advertiser`)
	db.Exec(`ALTER TABLE campaigns DROP INDEX uk_platform_campaign`)
	db.Exec(`ALTER TABLE ad_groups DROP INDEX uk_platform_adgroup`)
	db.Exec(`ALTER TABLE ads DROP INDEX uk_platform_ad`)

	fmt.Println("running migrations...")
	if err := db.AutoMigrate(models...); err != nil {
		fmt.Fprintf(os.Stderr, "migrate error: %v\n", err)
		os.Exit(1)
	}
	fmt.Println("migrations completed successfully")
}
