package adsvc

import (
	"context"
	"errors"
	"fmt"

	"go.uber.org/zap"

	"ad-x-manage/backend/internal/model/dto"
	"ad-x-manage/backend/internal/model/entity"
	adrepo "ad-x-manage/backend/internal/repository/ad"
	adgrouprepo "ad-x-manage/backend/internal/repository/adgroup"
	advertiserrepo "ad-x-manage/backend/internal/repository/advertiser"
	operationlogrepo "ad-x-manage/backend/internal/repository/operationlog"
	tokenrepo "ad-x-manage/backend/internal/repository/token"
	"ad-x-manage/backend/internal/service/platform"
)

var (
	ErrNotFound  = errors.New("advertiser not found")
	ErrForbidden = errors.New("no permission")
)

type Service interface {
	List(ctx context.Context, userID, advertiserID uint64, req *dto.AdListRequest) ([]*dto.AdItem, int64, error)
	ListAll(ctx context.Context, userID uint64, req *dto.AllAdListRequest) ([]*dto.AdItem, int64, error)
	UpdateStatus(ctx context.Context, userID, adID uint64, action string) error
}

type service struct {
	adRepo    adrepo.Repository
	groupRepo adgrouprepo.Repository
	advRepo   advertiserrepo.Repository
	tokenRepo tokenrepo.Repository
	logRepo   operationlogrepo.Repository
	clients   map[string]platform.Client
	log       *zap.Logger
}

func New(
	adRepo adrepo.Repository,
	groupRepo adgrouprepo.Repository,
	advRepo advertiserrepo.Repository,
	tokenRepo tokenrepo.Repository,
	logRepo operationlogrepo.Repository,
	clients map[string]platform.Client,
	log *zap.Logger,
) Service {
	return &service{
		adRepo: adRepo, groupRepo: groupRepo, advRepo: advRepo,
		tokenRepo: tokenRepo, logRepo: logRepo, clients: clients, log: log,
	}
}

// List 广告分页列表，支持按广告组过滤和关键词搜索。
func (s *service) List(ctx context.Context, userID, advertiserID uint64, req *dto.AdListRequest) ([]*dto.AdItem, int64, error) {
	adv, err := s.checkOwnership(ctx, userID, advertiserID)
	if err != nil {
		return nil, 0, err
	}
	if req.Page < 1 {
		req.Page = 1
	}
	if req.PageSize < 1 || req.PageSize > 100 {
		req.PageSize = 20
	}

	list, total, err := s.adRepo.FindByAdvertiserID(ctx, advertiserID, req.AdgroupID, req.Keyword, req.Page, req.PageSize)
	if err != nil {
		return nil, 0, err
	}

	nameMap, _ := s.buildAdGroupNameMap(ctx, advertiserID)

	items := make([]*dto.AdItem, 0, len(list))
	for _, a := range list {
		item := toAdItem(a, adv)
		item.AdgroupName = nameMap[a.AdgroupID]
		items = append(items, item)
	}
	return items, total, nil
}

// ListAll 跨广告主全量广告分页列表，支持平台和关键词过滤。
func (s *service) ListAll(ctx context.Context, userID uint64, req *dto.AllAdListRequest) ([]*dto.AdItem, int64, error) {
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

	list, total, err := s.adRepo.FindByAdvertiserIDs(ctx, advIDs, req.Keyword, req.Page, req.PageSize)
	if err != nil {
		return nil, 0, err
	}

	items := make([]*dto.AdItem, 0, len(list))
	for _, a := range list {
		items = append(items, toAdItem(a, advMap[a.AdvertiserID]))
	}
	return items, total, nil
}

// UpdateStatus 开启或暂停广告（action: "enable" | "pause"）。
func (s *service) UpdateStatus(ctx context.Context, userID, adID uint64, action string) error {
	ad, err := s.adRepo.FindByID(ctx, adID)
	if err != nil || ad == nil {
		return ErrNotFound
	}

	adv, err := s.checkOwnership(ctx, userID, ad.AdvertiserID)
	if err != nil {
		return err
	}

	token, err := s.tokenRepo.FindByID(ctx, adv.TokenID)
	if err != nil || token == nil {
		return fmt.Errorf("token not found")
	}

	client, ok := s.clients[adv.Platform]
	if !ok {
		return fmt.Errorf("unsupported platform: %s", adv.Platform)
	}

	platformStatus := toPlatformStatus(adv.Platform, action)
	oldStatus := ad.Status

	if err := client.UpdateAdStatus(token.AccessToken, adv.AdvertiserID, ad.AdID, platformStatus); err != nil {
		s.writeLog(ctx, userID, adv, actionToLogAction(action), entity.TargetTypeAd,
			ad.AdID, ad.AdName,
			entity.JSONField{"status": oldStatus},
			entity.JSONField{"status": platformStatus}, 0, err.Error())
		return fmt.Errorf("platform update ad status: %w", err)
	}

	if err := s.adRepo.UpdateStatus(ctx, adID, platformStatus); err != nil {
		s.log.Warn("update ad status in db failed", zap.Uint64("ad_id", adID), zap.Error(err))
	}

	s.writeLog(ctx, userID, adv, actionToLogAction(action), entity.TargetTypeAd,
		ad.AdID, ad.AdName,
		entity.JSONField{"status": oldStatus},
		entity.JSONField{"status": platformStatus}, 1, "")
	return nil
}

func (s *service) checkOwnership(ctx context.Context, userID, advertiserID uint64) (*entity.Advertiser, error) {
	adv, err := s.advRepo.FindByID(ctx, advertiserID)
	if err != nil || adv == nil {
		return nil, ErrNotFound
	}
	if adv.UserID != userID {
		return nil, ErrForbidden
	}
	return adv, nil
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

// buildAdGroupNameMap 返回 adgroup internal_id → adgroup_name 的映射。
func (s *service) buildAdGroupNameMap(ctx context.Context, advertiserID uint64) (map[uint64]string, error) {
	groups, err := s.groupRepo.FindAllByAdvertiserID(ctx, advertiserID)
	if err != nil {
		return nil, err
	}
	m := make(map[uint64]string, len(groups))
	for _, g := range groups {
		m[g.ID] = g.AdgroupName
	}
	return m, nil
}

func toAdItem(a *entity.Ad, adv *entity.Advertiser) *dto.AdItem {
	item := &dto.AdItem{
		ID: a.ID, AdID: a.AdID, AdName: a.AdName,
		AdgroupID: a.AdgroupID, Status: a.Status, CreativeType: a.CreativeType,
		AdvertiserID: a.AdvertiserID,
	}
	if adv != nil {
		item.AdvertiserName = adv.AdvertiserName
		item.Platform = adv.Platform
	}
	return item
}
