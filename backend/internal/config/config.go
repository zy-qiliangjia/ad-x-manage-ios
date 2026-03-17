package config

import (
	"github.com/joho/godotenv"
	"github.com/kelseyhightower/envconfig"
)

type Config struct {
	App    AppConfig
	DB     DBConfig
	Redis  RedisConfig
	TikTok TikTokConfig
	Kwai   KwaiConfig
}

type AppConfig struct {
	Env    string `envconfig:"APP_ENV"    default:"development"`
	Port   string `envconfig:"APP_PORT"   default:"8080"`
	Secret string `envconfig:"APP_SECRET" required:"true"`
}

type DBConfig struct {
	Host         string `envconfig:"DB_HOST"           default:"127.0.0.1"`
	Port         string `envconfig:"DB_PORT"           default:"3306"`
	User         string `envconfig:"DB_USER"           required:"true"`
	Password     string `envconfig:"DB_PASSWORD"`
	Name         string `envconfig:"DB_NAME"           required:"true"`
	MaxOpenConns int    `envconfig:"DB_MAX_OPEN_CONNS" default:"20"`
	MaxIdleConns int    `envconfig:"DB_MAX_IDLE_CONNS" default:"5"`
}

type RedisConfig struct {
	Host     string `envconfig:"REDIS_HOST"     default:"127.0.0.1"`
	Port     string `envconfig:"REDIS_PORT"     default:"6379"`
	Password string `envconfig:"REDIS_PASSWORD"`
	DB       int    `envconfig:"REDIS_DB"       default:"0"`
}

type TikTokConfig struct {
	AppID       string `envconfig:"TIKTOK_APP_ID"`
	AppSecret   string `envconfig:"TIKTOK_APP_SECRET"`
	RedirectURI string `envconfig:"TIKTOK_REDIRECT_URI"`
	Sandbox     bool   `envconfig:"TIKTOK_SANDBOX" default:"true"`
}

type KwaiConfig struct {
	AppKey      string `envconfig:"KWAI_APP_KEY"`
	AppSecret   string `envconfig:"KWAI_APP_SECRET"`
	RedirectURI string `envconfig:"KWAI_REDIRECT_URI"`
}

// Load 读取 .env 文件（本地开发）并解析环境变量到 Config。
// 生产环境直接注入系统环境变量，.env 文件不存在时不报错。
func Load() (*Config, error) {
	_ = godotenv.Load()
	var cfg Config
	if err := envconfig.Process("", &cfg); err != nil {
		return nil, err
	}
	return &cfg, nil
}
