package entity

import "time"

type User struct {
	ID           uint64     `gorm:"primaryKey;autoIncrement"               json:"id"`
	Email        string     `gorm:"uniqueIndex;size:255;not null"           json:"email"`
	PasswordHash string     `gorm:"size:255;not null"                      json:"-"`
	Name         string     `gorm:"size:100;not null;default:''"           json:"name"`
	Status       uint8      `gorm:"not null;default:1"                     json:"status"`
	LastLoginAt  *time.Time `gorm:"default:null"                           json:"last_login_at"`
	CreatedAt    time.Time  `                                              json:"created_at"`
	UpdatedAt    time.Time  `                                              json:"updated_at"`
}
