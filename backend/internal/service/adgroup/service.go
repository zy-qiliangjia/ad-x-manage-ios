package adgroupsvc

import (
	"context"
	"errors"
	"fmt"

	"go.uber.org/zap"

	"ad-x-manage/backend/internal/model/dto"
	"ad-x-manage/backend/internal/model/entity"
	adgrouprepo "ad-x-manage/backend/internal/repository/adgroup"
	advertiserrepo "ad-x-manage/backend/internal/repository/advertiser"
	operationlogrepo "ad-x-manage/backend/internal/repository/operationlog"
	tokenrepo "ad-x-manage/backend/internal/repository/token"
	"ad-x-manage/backend/internal/service/platform"
)

var (
	ErrNotFound  = errors.New("adgroup not found")
	ErrForbidden = errors.New("no permission")
)

type Service interface {
	List(ctx context.Context, userID, advertiserID uint64, req *dto.AdGroupListRequest) ([]*dto.AdGroupItem, int64, error)
	ListAll(ctx context.Context, userID uint64, req *dto.AllAdGroupListRequest) ([]*dto.AdGroupItem, int64, error)
	UpdateBudget(ctx context.Context, userID, adgroupID uint64, budget float64) error
	UpdateStatus(ctx context.Context, userID, adgroupID uint64, action string) error
}

type service struct {
	groupRepo  adgrouprepo.Repository
	advRepo    advertiserrepo.Repository
	tokenRepo  tokenrepo.Repository
	logRepo    operationlogrepo.Repository
	clients    map[string]platform.Client
	log        *zap.Logger
}

func New(
	groupRepo adgrouprepo.Repository,
	advRepo advertiserrepo.Repository,
	tokenRepo tokenrepo.Repository,
	logRepo operationlogrepo.Repository,
	clients map[string]platform.Client,
	log *zap.Logger,
) Service {
	return &service{groupRepo: groupRepo, advRepo: advRepo, tokenRepo: tokenRepo,
		logRepo: logRepo, clients: clients, log: log}
}

// List 广告组分页列表，campaignID=0 时返回该广告主下全部广告组。
func (s *service) List(ctx context.Context, userID, advertiserID uint64, req *dto.AdGroupListRequest) ([]*dto.AdGroupItem, int64, error) {
	adv, err := s.checkAdvertiserOwnership(ctx, userID, advertiserID)
	if err != nil {
		return nil, 0, err
	}
	if req.Page < 1 {
		req.Page = 1
	}
	if req.PageSize < 1 || req.PageSize > 100 {
		req.PageSize = 20
	}
	list, total, err := s.groupRepo.FindByAdvertiserID(ctx, advertiserID, req.CampaignID, req.Page, req.PageSize)
	if err != nil {
		return nil, 0, err
	}
	items := make([]*dto.AdGroupItem, 0, len(list))
	for _, g := range list {
		items = append(items, toAdGroupItem(g, adv))
	}
	return items, total, nil
}

// ListAll 跨广告主全量广告组分页列表，支持平台和关键词过滤。
func (s *service) ListAll(ctx context.Context, userID uint64, req *dto.AllAdGroupListRequest) ([]*dto.AdGroupItem, int64, error) {
	if req.Page < 1 {
		req.Page = 1
	}
	if req.PageSize < 1 || req.PageSize > 100 {
		req.PageSize = 20
	}

	advs, err := s.advRepo.FindAllActiveByUserID(ctx, userID)
	if err != nil {
		return nil, 0, err
	}

	advIDs := make([]uint64, 0, len(advs))
	advMap := make(map[uint64]*entity.Advertiser, len(advs))
	for _, adv := range advs {
		if req.Platform != "" && adv.Platform != req.Platform {
			continue
		}
		advIDs = append(advIDs, adv.ID)
		advMap[adv.ID] = adv
	}
	if len(advIDs) == 0 {
		return nil, 0, nil
	}

	list, total, err := s.groupRepo.FindByAdvertiserIDs(ctx, advIDs, req.Keyword, req.Page, req.PageSize)
	if err != nil {
		return nil, 0, err
	}

	items := make([]*dto.AdGroupItem, 0, len(list))
	for _, g := range list {
		items = append(items, toAdGroupItem(g, advMap[g.AdvertiserID]))
	}
	return items, total, nil
}

// UpdateBudget 修改广告组预算：调用平台 API → 更新本地 DB → 写操作日志。
func (s *service) UpdateBudget(ctx context.Context, userID, adgroupID uint64, budget float64) error {
	group, adv, accessToken, client, err := s.resolveAdGroup(ctx, userID, adgroupID)
	if err != nil {
		return err
	}

	oldBudget := group.Budget
	if err := client.UpdateAdGroupBudget(accessToken, adv.AdvertiserID, group.AdgroupID, budget); err != nil {
		s.writeLog(ctx, userID, adv, entity.ActionBudgetUpdate, entity.TargetTypeAdGroup,
			group.AdgroupID, group.AdgroupName,
			entity.JSONField{"budget": oldBudget},
			entity.JSONField{"budget": budget}, 0, err.Error())
		return fmt.Errorf("platform update adgroup budget: %w", err)
	}

	if err := s.groupRepo.UpdateBudget(ctx, adgroupID, budget); err != nil {
		s.log.Warn("update adgroup budget in db failed", zap.Uint64("adgroup_id", adgroupID), zap.Error(err))
	}

	s.writeLog(ctx, userID, adv, entity.ActionBudgetUpdate, entity.TargetTypeAdGroup,
		group.AdgroupID, group.AdgroupName,
		entity.JSONField{"budget": oldBudget},
		entity.JSONField{"budget": budget}, 1, "")
	return nil
}

// UpdateStatus 开启或暂停广告组（action: "enable" | "pause"）。
func (s *service) UpdateStatus(ctx context.Context, userID, adgroupID uint64, action string) error {
	group, adv, accessToken, client, err := s.resolveAdGroup(ctx, userID, adgroupID)
	if err != nil {
		return err
	}

	platformStatus := toPlatformStatus(adv.Platform, action)
	oldStatus := group.Status

	if err := client.UpdateAdGroupStatus(accessToken, adv.AdvertiserID, group.AdgroupID, platformStatus); err != nil {
		s.writeLog(ctx, userID, adv, actionToLogAction(action), entity.TargetTypeAdGroup,
			group.AdgroupID, group.AdgroupName,
			entity.JSONField{"status": oldStatus},
			entity.JSONField{"status": platformStatus}, 0, err.Error())
		return fmt.Errorf("platform update adgroup status: %w", err)
	}

	if err := s.groupRepo.UpdateStatus(ctx, adgroupID, platformStatus); err != nil {
		s.log.Warn("update adgroup status in db failed", zap.Uint64("adgroup_id", adgroupID), zap.Error(err))
	}

	s.writeLog(ctx, userID, adv, actionToLogAction(action), entity.TargetTypeAdGroup,
		group.AdgroupID, group.AdgroupName,
		entity.JSONField{"status": oldStatus},
		entity.JSONField{"status": platformStatus}, 1, "")
	return nil
}

// ── 工具方法 ───────────────────────────────────────────────────

func (s *service) resolveAdGroup(ctx context.Context, userID, adgroupID uint64) (
	*entity.AdGroup, *entity.Advertiser, string, platform.Client, error,
) {
	group, err := s.groupRepo.FindByID(ctx, adgroupID)
	if err != nil || group == nil {
		return nil, nil, "", nil, ErrNotFound
	}
	adv, err := s.checkAdvertiserOwnership(ctx, userID, group.AdvertiserID)
	if err != nil {
		return nil, nil, "", nil, err
	}
	accessToken, err := s.getAccessToken(ctx, adv.TokenID)
	if err != nil {
		return nil, nil, "", nil, err
	}
	client, ok := s.clients[adv.Platform]
	if !ok {
		return nil, nil, "", nil, fmt.Errorf("unsupported platform: %s", adv.Platform)
	}
	return group, adv, accessToken, client, nil
}

func (s *service) checkAdvertiserOwnership(ctx context.Context, userID, advertiserID uint64) (*entity.Advertiser, error) {
	adv, err := s.advRepo.FindByID(ctx, advertiserID)
	if err != nil || adv == nil {
		return nil, ErrNotFound
	}
	if adv.UserID != userID {
		return nil, ErrForbidden
	}
	return adv, nil
}

func (s *service) getAccessToken(ctx context.Context, tokenID uint64) (string, error) {
	token, err := s.tokenRepo.FindByID(ctx, tokenID)
	if err != nil || token == nil {
		return "", fmt.Errorf("token not found")
	}
	return token.AccessToken, nil
}

func (s *service) writeLog(ctx context.Context, userID uint64, adv *entity.Advertiser,
	action, targetType, targetID, targetName string,
	before, after entity.JSONField, result uint8, failReason string,
) {
	_ = s.logRepo.Create(ctx, &entity.OperationLog{
		UserID:       userID,
		AdvertiserID: adv.ID,
		Platform:     adv.Platform,
		Action:       action,
		TargetType:   targetType,
		TargetID:     targetID,
		TargetName:   targetName,
		BeforeVal:    before,
		AfterVal:     after,
		Result:       result,
		FailReason:   failReason,
	})
}

func toAdGroupItem(g *entity.AdGroup, adv *entity.Advertiser) *dto.AdGroupItem {
	item := &dto.AdGroupItem{
		ID: g.ID, AdgroupID: g.AdgroupID, AdgroupName: g.AdgroupName,
		CampaignID: g.CampaignID, Status: g.Status, BudgetMode: g.BudgetMode,
		Budget: g.Budget, Spend: g.Spend, Clicks: g.Clicks, Impressions: g.Impressions,
		Conversions: g.Conversions, BidType: g.BidType, BidPrice: g.BidPrice,
		AdvertiserID: g.AdvertiserID,
	}
	if adv != nil {
		item.AdvertiserName = adv.AdvertiserName
		item.Platform = adv.Platform
	}
	return item
}

func toPlatformStatus(platformName, action string) string {
	if action == "enable" {
		if platformName == "tiktok" {
			return "ENABLE"
		}
		return "ONLINE"
	}
	if platformName == "tiktok" {
		return "DISABLE"
	}
	return "OFFLINE"
}

func actionToLogAction(action string) string {
	if action == "enable" {
		return entity.ActionStatusEnable
	}
	return entity.ActionStatusPause
}
