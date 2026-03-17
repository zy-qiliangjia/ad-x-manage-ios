package campaignsvc

import (
	"context"
	"errors"
	"fmt"

	"go.uber.org/zap"

	"ad-x-manage/backend/internal/model/dto"
	"ad-x-manage/backend/internal/model/entity"
	advertiserrepo "ad-x-manage/backend/internal/repository/advertiser"
	campaignrepo "ad-x-manage/backend/internal/repository/campaign"
	operationlogrepo "ad-x-manage/backend/internal/repository/operationlog"
	tokenrepo "ad-x-manage/backend/internal/repository/token"
	"ad-x-manage/backend/internal/service/platform"
)

var (
	ErrNotFound  = errors.New("campaign not found")
	ErrForbidden = errors.New("no permission")
)

type Service interface {
	List(ctx context.Context, userID, advertiserID uint64, req *dto.CampaignListRequest) ([]*dto.CampaignItem, int64, error)
	ListAll(ctx context.Context, userID uint64, req *dto.AllCampaignListRequest) ([]*dto.CampaignItem, int64, error)
	UpdateBudget(ctx context.Context, userID, campaignID uint64, budget float64) error
	UpdateStatus(ctx context.Context, userID, campaignID uint64, action string) error
}

type service struct {
	campRepo   campaignrepo.Repository
	advRepo    advertiserrepo.Repository
	tokenRepo  tokenrepo.Repository
	logRepo    operationlogrepo.Repository
	clients    map[string]platform.Client
	log        *zap.Logger
}

func New(
	campRepo campaignrepo.Repository,
	advRepo advertiserrepo.Repository,
	tokenRepo tokenrepo.Repository,
	logRepo operationlogrepo.Repository,
	clients map[string]platform.Client,
	log *zap.Logger,
) Service {
	return &service{campRepo: campRepo, advRepo: advRepo, tokenRepo: tokenRepo,
		logRepo: logRepo, clients: clients, log: log}
}

// List 推广系列分页列表。
func (s *service) List(ctx context.Context, userID, advertiserID uint64, req *dto.CampaignListRequest) ([]*dto.CampaignItem, int64, error) {
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
	list, total, err := s.campRepo.FindByAdvertiserID(ctx, advertiserID, req.Page, req.PageSize)
	if err != nil {
		return nil, 0, err
	}
	items := make([]*dto.CampaignItem, 0, len(list))
	for _, c := range list {
		items = append(items, toCampaignItem(c, adv))
	}
	return items, total, nil
}

// ListAll 跨广告主全量推广系列分页列表，支持平台和关键词过滤。
func (s *service) ListAll(ctx context.Context, userID uint64, req *dto.AllCampaignListRequest) ([]*dto.CampaignItem, int64, error) {
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

	list, total, err := s.campRepo.FindByAdvertiserIDs(ctx, advIDs, req.Keyword, req.Page, req.PageSize)
	if err != nil {
		return nil, 0, err
	}

	items := make([]*dto.CampaignItem, 0, len(list))
	for _, c := range list {
		items = append(items, toCampaignItem(c, advMap[c.AdvertiserID]))
	}
	return items, total, nil
}

// UpdateBudget 修改推广系列预算：调用平台 API → 更新本地 DB → 写操作日志。
func (s *service) UpdateBudget(ctx context.Context, userID, campaignID uint64, budget float64) error {
	camp, adv, accessToken, client, err := s.resolveCampaign(ctx, userID, campaignID)
	if err != nil {
		return err
	}

	oldBudget := camp.Budget
	if err := client.UpdateCampaignBudget(accessToken, adv.AdvertiserID, camp.CampaignID, budget); err != nil {
		s.writeLog(ctx, userID, adv, entity.ActionBudgetUpdate, entity.TargetTypeCampaign,
			camp.CampaignID, camp.CampaignName,
			entity.JSONField{"budget": oldBudget},
			entity.JSONField{"budget": budget}, 0, err.Error())
		return fmt.Errorf("platform update budget: %w", err)
	}

	if err := s.campRepo.UpdateBudget(ctx, campaignID, budget); err != nil {
		s.log.Warn("update campaign budget in db failed", zap.Uint64("campaign_id", campaignID), zap.Error(err))
	}

	s.writeLog(ctx, userID, adv, entity.ActionBudgetUpdate, entity.TargetTypeCampaign,
		camp.CampaignID, camp.CampaignName,
		entity.JSONField{"budget": oldBudget},
		entity.JSONField{"budget": budget}, 1, "")
	return nil
}

// UpdateStatus 开启或暂停推广系列（action: "enable" | "pause"）。
func (s *service) UpdateStatus(ctx context.Context, userID, campaignID uint64, action string) error {
	camp, adv, accessToken, client, err := s.resolveCampaign(ctx, userID, campaignID)
	if err != nil {
		return err
	}

	platformStatus := toPlatformStatus(adv.Platform, action)
	oldStatus := camp.Status

	if err := client.UpdateCampaignStatus(accessToken, adv.AdvertiserID, camp.CampaignID, platformStatus); err != nil {
		s.writeLog(ctx, userID, adv, actionToLogAction(action), entity.TargetTypeCampaign,
			camp.CampaignID, camp.CampaignName,
			entity.JSONField{"status": oldStatus},
			entity.JSONField{"status": platformStatus}, 0, err.Error())
		return fmt.Errorf("platform update status: %w", err)
	}

	if err := s.campRepo.UpdateStatus(ctx, campaignID, platformStatus); err != nil {
		s.log.Warn("update campaign status in db failed", zap.Uint64("campaign_id", campaignID), zap.Error(err))
	}

	s.writeLog(ctx, userID, adv, actionToLogAction(action), entity.TargetTypeCampaign,
		camp.CampaignID, camp.CampaignName,
		entity.JSONField{"status": oldStatus},
		entity.JSONField{"status": platformStatus}, 1, "")
	return nil
}

// ── 工具方法 ───────────────────────────────────────────────────

func (s *service) resolveCampaign(ctx context.Context, userID, campaignID uint64) (
	*entity.Campaign, *entity.Advertiser, string, platform.Client, error,
) {
	camp, err := s.campRepo.FindByID(ctx, campaignID)
	if err != nil || camp == nil {
		return nil, nil, "", nil, ErrNotFound
	}
	adv, err := s.checkAdvertiserOwnership(ctx, userID, camp.AdvertiserID)
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
	return camp, adv, accessToken, client, nil
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

func toCampaignItem(c *entity.Campaign, adv *entity.Advertiser) *dto.CampaignItem {
	item := &dto.CampaignItem{
		ID: c.ID, CampaignID: c.CampaignID, CampaignName: c.CampaignName,
		Status: c.Status, BudgetMode: c.BudgetMode, Budget: c.Budget,
		Spend: c.Spend, Clicks: c.Clicks, Impressions: c.Impressions,
		Conversions: c.Conversions, Objective: c.Objective,
		AdvertiserID: c.AdvertiserID,
	}
	if adv != nil {
		item.AdvertiserName = adv.AdvertiserName
		item.Platform = adv.Platform
	}
	return item
}

// toPlatformStatus 将 iOS 的平台无关 action 转为平台原生状态值。
func toPlatformStatus(platformName, action string) string {
	if action == "enable" {
		if platformName == "tiktok" {
			return "ENABLE"
		}
		return "ONLINE"
	}
	// pause
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
