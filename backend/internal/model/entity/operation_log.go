package entity

import (
	"database/sql/driver"
	"encoding/json"
	"fmt"
	"time"
)

// OperationLog 操作日志（不可修改，仅追加）。
type OperationLog struct {
	ID           uint64    `gorm:"primaryKey;autoIncrement"                     json:"id"`
	UserID       uint64    `gorm:"not null;index:idx_user_id"                    json:"user_id"`
	AdvertiserID uint64    `gorm:"not null;index:idx_advertiser_id"              json:"advertiser_id"`
	Platform     string    `gorm:"size:20;not null"                             json:"platform"`
	Action       string    `gorm:"size:50;not null"                             json:"action"`
	TargetType   string    `gorm:"size:20;not null;index:idx_target"             json:"target_type"`
	TargetID     string    `gorm:"size:100;not null;index:idx_target"            json:"target_id"`
	TargetName   string    `gorm:"size:255;default:null"                        json:"target_name"`
	BeforeVal    JSONField `gorm:"type:json;default:null"                       json:"before_val"`
	AfterVal     JSONField `gorm:"type:json;default:null"                       json:"after_val"`
	Result       uint8     `gorm:"not null;default:1"                           json:"result"`
	FailReason   string    `gorm:"size:500;default:null"                        json:"fail_reason"`
	CreatedAt    time.Time `gorm:"index:idx_created_at"                         json:"created_at"`
}

// Action 操作类型常量
const (
	ActionBudgetUpdate = "budget_update"
	ActionStatusEnable = "status_enable"
	ActionStatusPause  = "status_pause"
)

// TargetType 操作对象常量
const (
	TargetTypeCampaign   = "campaign"
	TargetTypeAdGroup    = "adgroup"
	TargetTypeAd         = "ad"
	TargetTypeAdvertiser = "advertiser"
)

// JSONField 支持 JSON 字段的自定义类型（兼容 GORM + MySQL JSON 列）。
type JSONField map[string]any

func (j JSONField) Value() (driver.Value, error) {
	if j == nil {
		return nil, nil
	}
	b, err := json.Marshal(j)
	return string(b), err
}

func (j *JSONField) Scan(value any) error {
	if value == nil {
		*j = nil
		return nil
	}
	var b []byte
	switch v := value.(type) {
	case []byte:
		b = v
	case string:
		b = []byte(v)
	default:
		return fmt.Errorf("unsupported type: %T", value)
	}
	return json.Unmarshal(b, j)
}
