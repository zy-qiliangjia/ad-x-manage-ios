.PHONY: run build tidy migrate lint

# 本地开发运行
run:
	go run cmd/server/main.go

# 编译
build:
	go build -o bin/server cmd/server/main.go

# 整理依赖
tidy:
	go mod tidy

# 数据库迁移
migrate:
	go run migrations/migrate.go

# 代码检查
lint:
	golangci-lint run ./...

# 运行测试
test:
	go test ./... -v

# 复制配置文件（首次初始化）
init-env:
	cp .env.example .env
	@echo ".env created, please fill in your config"
