package entity

import "time"

type User struct {
	ID           uint64     `gorm:"primaryKey;autoIncrement"                                      json:"id"`
	Product      string     `gorm:"uniqueIndex:uk_product_email;size:50;not null;default:''"      json:"product"`
	Email        string     `gorm:"uniqueIndex:uk_product_email;size:255;not null"               json:"email"`
	PasswordHash string     `gorm:"size:255;not null"                                             json:"-"`
	Name         string     `gorm:"size:100;not null;default:''"                                  json:"name"`
	Status       uint8      `gorm:"not null;default:1"                                            json:"status"`
	InviteCode   string     `gorm:"uniqueIndex;size:20;not null;default:''"                       json:"invite_code"`
	InvitedBy    *uint64    `gorm:"default:null;index"                                            json:"invited_by"`
	Remark       string     `gorm:"size:500;not null;default:''"                                  json:"remark"`
	Quota        int        `gorm:"not null;default:5"                                            json:"quota"`
	UsedQuota    int        `gorm:"not null;default:0"                                            json:"used_quota"`
	LastLoginAt  *time.Time `gorm:"default:null"                                                  json:"last_login_at"`
	CreatedAt    time.Time  `                                                                     json:"created_at"`
	UpdatedAt    time.Time  `                                                                     json:"updated_at"`
}
