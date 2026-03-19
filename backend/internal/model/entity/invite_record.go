package entity

import "time"

// InviteRecord 记录邀请关系：每个用户只能被邀请一次（invitee_id 唯一）。
type InviteRecord struct {
	ID        uint64    `gorm:"primaryKey;autoIncrement" json:"id"`
	InviterID uint64    `gorm:"not null;index"           json:"inviter_id"`
	InviteeID uint64    `gorm:"not null;uniqueIndex"     json:"invitee_id"`
	CreatedAt time.Time `                                json:"created_at"`
}
