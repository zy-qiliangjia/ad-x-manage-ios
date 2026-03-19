package main

import (
	"crypto/rand"
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
		&entity.InviteRecord{},
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

	// 先为 users 表加列（不带唯一索引），以便存量数据补填后再建索引
	fmt.Println("adding invite_code / quota columns if needed...")
	var inviteColCount int64
	db.Raw(`SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
		WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'users'
		AND COLUMN_NAME = 'invite_code'`).Scan(&inviteColCount)
	if inviteColCount == 0 {
		if err := db.Exec(`ALTER TABLE users
			ADD COLUMN invite_code VARCHAR(20) NOT NULL DEFAULT '',
			ADD COLUMN quota       INT         NOT NULL DEFAULT 5`).Error; err != nil {
			fmt.Fprintf(os.Stderr, "add columns error: %v\n", err)
			os.Exit(1)
		}
		fmt.Println("columns added")
	} else {
		fmt.Println("columns already exist, skipping")
	}

	// 补填 invite_code（必须在建唯一索引之前完成）
	fmt.Println("backfilling invite_code for existing users...")
	var users []entity.User
	if err := db.Where("invite_code = ''").Find(&users).Error; err != nil {
		fmt.Fprintf(os.Stderr, "fetch users error: %v\n", err)
		os.Exit(1)
	}
	for _, u := range users {
		code, err := generateInviteCode()
		if err != nil {
			fmt.Fprintf(os.Stderr, "generate invite code error: %v\n", err)
			continue
		}
		updates := map[string]any{"invite_code": code}
		if u.Quota == 0 {
			updates["quota"] = 5
		}
		db.Model(&entity.User{}).Where("id = ?", u.ID).Updates(updates)
	}
	fmt.Printf("backfilled %d users\n", len(users))

	// 再执行 AutoMigrate（此时 invite_code 已全部不重复，可安全建唯一索引）
	fmt.Println("running migrations...")
	if err := db.AutoMigrate(models...); err != nil {
		fmt.Fprintf(os.Stderr, "migrate error: %v\n", err)
		os.Exit(1)
	}
	fmt.Println("migrations completed successfully")
}

func generateInviteCode() (string, error) {
	const charset = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
	const codeLen = 6
	b := make([]byte, codeLen)
	if _, err := rand.Read(b); err != nil {
		return "", err
	}
	result := make([]byte, codeLen)
	for i, v := range b {
		result[i] = charset[int(v)%len(charset)]
	}
	return "AP-" + string(result), nil
}
