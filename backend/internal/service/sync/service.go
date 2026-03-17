// Package syncsvc 负责从广告平台全量拉取数据并 UPSERT 到本地数据库。
// 同步顺序：推广系列 → 广告组 → 广告
package syncsvc

import (
	"context"
	"fmt"
	"time"

	"go.uber.org/zap"

	"ad-x-manage/backend/internal/model/entity"
	adrepo "ad-x-manage/backend/internal/repository/ad"
	adgrouprepo "ad-x-manage/backend/internal/repository/adgroup"
	advertiserrepo "ad-x-manage/backend/internal/repository/advertiser"
	campaignrepo "ad-x-manage/backend/internal/repository/campaign"
	tokenrepo "ad-x-manage/backend/internal/repository/token"
	"ad-x-manage/backend/internal/service/platform"
)

const syncPageSize = 200 // 每页拉取条数

// Result 同步结果摘要。
type Result struct {
	CampaignCount int
	AdGroupCount  int
	AdCount       int
	Duration      time.Duration
	Errors        []string
}

// Service 数据同步接口。
type Service interface {
	SyncAdvertiser(ctx context.Context, adv *entity.Advertiser) (*Result, error)
}

type service struct {
	clients   map[string]platform.Client
	tokenRepo tokenrepo.Repository
	advRepo   advertiserrepo.Repository
	campRepo  campaignrepo.Repository
	groupRepo adgrouprepo.Repository
	adRepo    adrepo.Repository
	log       *zap.Logger
}

func New(
	clients map[string]platform.Client,
	tokenRepo tokenrepo.Repository,
	advRepo advertiserrepo.Repository,
	campRepo campaignrepo.Repository,
	groupRepo adgrouprepo.Repository,
	adRepo adrepo.Repository,
	log *zap.Logger,
) Service {
	return &service{
		clients:   clients,
		tokenRepo: tokenRepo,
		advRepo:   advRepo,
		campRepo:  campRepo,
		groupRepo: groupRepo,
		adRepo:    adRepo,
		log:       log,
	}
}

// SyncAdvertiser 全量同步指定广告主的推广系列、广告组、广告。
func (s *service) SyncAdvertiser(ctx context.Context, adv *entity.Advertiser) (*Result, error) {
	start := time.Now()
	result := &Result{}

	// 1. 获取有效的 access_token
	accessToken, err := s.getValidAccessToken(ctx, adv.TokenID, adv.Platform)
	if err != nil {
		return nil, fmt.Errorf("get access token: %w", err)
	}

	client, ok := s.clients[adv.Platform]
	if !ok {
		return nil, fmt.Errorf("unsupported platform: %s", adv.Platform)
	}

	// 2. 补全广告主 currency / timezone（首次同步时可能为空）
	if adv.Currency == "" || adv.Timezone == "" {
		if infos, err := client.GetAdvertiserInfo(accessToken, []string{adv.AdvertiserID}); err == nil && len(infos) > 0 {
			info := infos[0]
			if info.Currency != "" || info.Timezone != "" {
				if err := s.advRepo.UpdateInfo(ctx, adv.ID, info.Currency, info.Timezone); err != nil {
					s.log.Warn("update advertiser info failed", zap.Uint64("advertiser_id", adv.ID), zap.Error(err))
				} else {
					adv.Currency = info.Currency
					adv.Timezone = info.Timezone
				}
			}
		}
	}

	// 3. 同步推广系列
	campCount, errs := s.syncCampaigns(ctx, client, adv, accessToken)
	result.CampaignCount = campCount
	result.Errors = append(result.Errors, errs...)

	// 3. 构建 platform_campaign_id → internal_id 映射
	campMap, err := s.buildCampaignMap(ctx, adv.ID)
	if err != nil {
		return result, fmt.Errorf("build campaign map: %w", err)
	}

	// 4. 同步广告组
	groupCount, errs := s.syncAdGroups(ctx, client, adv, accessToken, campMap)
	result.AdGroupCount = groupCount
	result.Errors = append(result.Errors, errs...)

	// 5. 构建 platform_adgroup_id → internal_id 映射
	groupMap, err := s.buildAdGroupMap(ctx, adv.ID)
	if err != nil {
		return result, fmt.Errorf("build adgroup map: %w", err)
	}

	// 6. 同步广告
	adCount, errs := s.syncAds(ctx, client, adv, accessToken, groupMap)
	result.AdCount = adCount
	result.Errors = append(result.Errors, errs...)

	// 7. 更新 synced_at
	now := time.Now()
	if err := s.advRepo.UpdateSyncedAt(ctx, adv.ID, now); err != nil {
		s.log.Warn("update synced_at failed", zap.Uint64("advertiser_id", adv.ID), zap.Error(err))
	}

	result.Duration = time.Since(start)
	s.log.Info("sync completed",
		zap.Uint64("advertiser_id", adv.ID),
		zap.String("platform", adv.Platform),
		zap.Int("campaigns", result.CampaignCount),
		zap.Int("adgroups", result.AdGroupCount),
		zap.Int("ads", result.AdCount),
		zap.Duration("duration", result.Duration),
	)
	return result, nil
}

// ── 各层同步 ───────────────────────────────────────────────────

func (s *service) syncCampaigns(ctx context.Context, client platform.Client, adv *entity.Advertiser, accessToken string) (int, []string) {
	var total int
	var errs []string
	page := 1
	for {
		items, _, err := client.GetCampaigns(accessToken, adv.AdvertiserID, page, syncPageSize)
		if err != nil {
			errs = append(errs, fmt.Sprintf("get campaigns page %d: %v", page, err))
			break
		}
		if len(items) == 0 {
			break
		}
		entities := make([]*entity.Campaign, 0, len(items))
		for _, item := range items {
			entities = append(entities, &entity.Campaign{
				AdvertiserID: adv.ID,
				Platform:     adv.Platform,
				CampaignID:   item.CampaignID,
				CampaignName: item.CampaignName,
				Status:       item.Status,
				BudgetMode:   item.BudgetMode,
				Budget:       item.Budget,
				Spend:        item.Spend,
				Objective:    item.Objective,
			})
		}
		if err := s.campRepo.Upsert(ctx, entities); err != nil {
			errs = append(errs, fmt.Sprintf("upsert campaigns page %d: %v", page, err))
		}
		total += len(items)
		if len(items) < syncPageSize {
			break
		}
		page++
	}
	return total, errs
}

func (s *service) syncAdGroups(ctx context.Context, client platform.Client, adv *entity.Advertiser, accessToken string, campMap map[string]uint64) (int, []string) {
	var total int
	var errs []string
	page := 1
	for {
		// 不按 campaign 过滤，一次拉取所有广告组
		items, _, err := client.GetAdGroups(accessToken, adv.AdvertiserID, "", page, syncPageSize)
		if err != nil {
			errs = append(errs, fmt.Sprintf("get adgroups page %d: %v", page, err))
			break
		}
		if len(items) == 0 {
			break
		}
		entities := make([]*entity.AdGroup, 0, len(items))
		for _, item := range items {
			internalCampID := campMap[item.CampaignID] // 平台 campaign_id → 内部 ID
			entities = append(entities, &entity.AdGroup{
				AdvertiserID: adv.ID,
				CampaignID:   internalCampID,
				Platform:     adv.Platform,
				AdgroupID:    item.AdGroupID,
				AdgroupName:  item.AdGroupName,
				Status:       item.Status,
				BudgetMode:   item.BudgetMode,
				Budget:       item.Budget,
				Spend:        item.Spend,
				BidType:      item.BidType,
				BidPrice:     item.BidPrice,
			})
		}
		if err := s.groupRepo.Upsert(ctx, entities); err != nil {
			errs = append(errs, fmt.Sprintf("upsert adgroups page %d: %v", page, err))
		}
		total += len(items)
		if len(items) < syncPageSize {
			break
		}
		page++
	}
	return total, errs
}

func (s *service) syncAds(ctx context.Context, client platform.Client, adv *entity.Advertiser, accessToken string, groupMap map[string]uint64) (int, []string) {
	var total int
	var errs []string
	page := 1
	for {
		items, _, err := client.GetAds(accessToken, adv.AdvertiserID, "", page, syncPageSize)
		if err != nil {
			errs = append(errs, fmt.Sprintf("get ads page %d: %v", page, err))
			break
		}
		if len(items) == 0 {
			break
		}
		entities := make([]*entity.Ad, 0, len(items))
		for _, item := range items {
			internalGroupID := groupMap[item.AdGroupID]
			entities = append(entities, &entity.Ad{
				AdvertiserID: adv.ID,
				AdgroupID:    internalGroupID,
				Platform:     adv.Platform,
				AdID:         item.AdID,
				AdName:       item.AdName,
				Status:       item.Status,
				CreativeType: item.CreativeType,
			})
		}
		if err := s.adRepo.Upsert(ctx, entities); err != nil {
			errs = append(errs, fmt.Sprintf("upsert ads page %d: %v", page, err))
		}
		total += len(items)
		if len(items) < syncPageSize {
			break
		}
		page++
	}
	return total, errs
}

// ── 工具方法 ───────────────────────────────────────────────────

// getValidAccessToken 获取解密后的 access_token，若快过期则自动刷新。
func (s *service) getValidAccessToken(ctx context.Context, tokenID uint64, platformName string) (string, error) {
	token, err := s.tokenRepo.FindByID(ctx, tokenID)
	if err != nil || token == nil {
		return "", fmt.Errorf("token not found: %w", err)
	}

	// 若 30 分钟内过期，自动刷新
	if token.ExpiresAt != nil && time.Until(*token.ExpiresAt) < 30*time.Minute {
		refreshed, err := s.refreshToken(ctx, token, platformName)
		if err != nil {
			s.log.Warn("token refresh failed, using existing token",
				zap.Uint64("token_id", tokenID), zap.Error(err))
		} else {
			return refreshed, nil
		}
	}

	return token.AccessToken, nil
}

// refreshToken 刷新 access_token 并更新数据库。
func (s *service) refreshToken(ctx context.Context, token *entity.PlatformToken, platformName string) (string, error) {
	client, ok := s.clients[platformName]
	if !ok {
		return "", fmt.Errorf("unsupported platform: %s", platformName)
	}

	result, err := client.RefreshToken(token.RefreshToken)
	if err != nil {
		return "", fmt.Errorf("platform refresh token: %w", err)
	}

	if err := s.tokenRepo.UpdateToken(ctx, token.ID, result.AccessToken, result.RefreshToken, result.ExpiresAt); err != nil {
		s.log.Warn("update refreshed token in db failed", zap.Uint64("token_id", token.ID), zap.Error(err))
	}

	return result.AccessToken, nil
}

// buildCampaignMap 构建 platform_campaign_id → internal_id 映射。
func (s *service) buildCampaignMap(ctx context.Context, advertiserID uint64) (map[string]uint64, error) {
	campaigns, err := s.campRepo.FindAllByAdvertiserID(ctx, advertiserID)
	if err != nil {
		return nil, err
	}
	m := make(map[string]uint64, len(campaigns))
	for _, c := range campaigns {
		m[c.CampaignID] = c.ID
	}
	return m, nil
}

// buildAdGroupMap 构建 platform_adgroup_id → internal_id 映射。
func (s *service) buildAdGroupMap(ctx context.Context, advertiserID uint64) (map[string]uint64, error) {
	groups, err := s.groupRepo.FindAllByAdvertiserID(ctx, advertiserID)
	if err != nil {
		return nil, err
	}
	m := make(map[string]uint64, len(groups))
	for _, g := range groups {
		m[g.AdgroupID] = g.ID
	}
	return m, nil
}
