package invitesvc

import (
	"context"
	"fmt"

	advertiserrepo "ad-x-manage/backend/internal/repository/advertiser"
	inviterepo "ad-x-manage/backend/internal/repository/invite"
	userrepo "ad-x-manage/backend/internal/repository/user"
)

const (
	DefaultQuota    = 5
	InviteBonus     = 5
	InviteLinkTmpl  = "https://adpilot.app/invite/%s"
)

// InviteInfoResponse 对应 iOS InviteInfo 结构。
type InviteInfoResponse struct {
	InviteCode   string `json:"invite_code"`
	InviteLink   string `json:"invite_link"`
	InvitedCount int64  `json:"invited_count"`
	EarnedQuota  int64  `json:"earned_quota"`
	TotalQuota   int    `json:"total_quota"`
}

// UserQuotaResponse 对应 iOS UserQuota 结构。
type UserQuotaResponse struct {
	TotalQuota int                     `json:"total_quota"`
	UsedTotal  int64                   `json:"used_total"`
	Platforms  []PlatformQuotaItem     `json:"platforms"`
}

type PlatformQuotaItem struct {
	Platform string `json:"platform"`
	Used     int    `json:"used"`
}

type Service interface {
	GetInviteInfo(ctx context.Context, userID uint64) (*InviteInfoResponse, error)
	GetQuota(ctx context.Context, userID uint64) (*UserQuotaResponse, error)
}

type service struct {
	userRepo userrepo.Repository
	advRepo  advertiserrepo.Repository
	invRepo  inviterepo.Repository
}

func New(
	userRepo userrepo.Repository,
	advRepo advertiserrepo.Repository,
	invRepo inviterepo.Repository,
) Service {
	return &service{
		userRepo: userRepo,
		advRepo:  advRepo,
		invRepo:  invRepo,
	}
}

func (s *service) GetInviteInfo(ctx context.Context, userID uint64) (*InviteInfoResponse, error) {
	user, err := s.userRepo.FindByID(ctx, userID)
	if err != nil || user == nil {
		return nil, fmt.Errorf("user not found")
	}

	invitedCount, err := s.invRepo.CountByInviterID(ctx, userID)
	if err != nil {
		return nil, err
	}

	earnedQuota := invitedCount * InviteBonus

	return &InviteInfoResponse{
		InviteCode:   user.InviteCode,
		InviteLink:   fmt.Sprintf(InviteLinkTmpl, user.InviteCode),
		InvitedCount: invitedCount,
		EarnedQuota:  earnedQuota,
		TotalQuota:   user.Quota,
	}, nil
}

func (s *service) GetQuota(ctx context.Context, userID uint64) (*UserQuotaResponse, error) {
	user, err := s.userRepo.FindByID(ctx, userID)
	if err != nil || user == nil {
		return nil, fmt.Errorf("user not found")
	}

	// 按平台分项（仍需查询，用于展示明细）
	platformCounts, err := s.advRepo.CountPerPlatformByUserID(ctx, userID)
	if err != nil {
		return nil, err
	}

	platforms := make([]PlatformQuotaItem, 0, len(platformCounts))
	for _, pc := range platformCounts {
		platforms = append(platforms, PlatformQuotaItem{
			Platform: pc.Platform,
			Used:     pc.Count,
		})
	}

	return &UserQuotaResponse{
		TotalQuota: user.Quota,
		UsedTotal:  int64(user.UsedQuota), // 使用存储值，无需 COUNT(*)
		Platforms:  platforms,
	}, nil
}
