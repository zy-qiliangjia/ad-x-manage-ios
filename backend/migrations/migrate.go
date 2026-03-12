package main

import (
	"fmt"
	"os"

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

	db, err := database.New(&cfg.DB)
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

	fmt.Println("running migrations...")
	if err := db.AutoMigrate(models...); err != nil {
		fmt.Fprintf(os.Stderr, "migrate error: %v\n", err)
		os.Exit(1)
	}
	fmt.Println("migrations completed successfully")
}
