package adsvc

import (
	"context"
	"errors"

	adrepo "ad-x-manage/backend/internal/repository/ad"
	adgrouprepo "ad-x-manage/backend/internal/repository/adgroup"
	advertiserrepo "ad-x-manage/backend/internal/repository/advertiser"

	"ad-x-manage/backend/internal/model/dto"
	"ad-x-manage/backend/internal/model/entity"
)

var (
	ErrNotFound  = errors.New("advertiser not found")
	ErrForbidden = errors.New("no permission")
)

type Service interface {
	List(ctx context.Context, userID, advertiserID uint64, req *dto.AdListRequest) ([]*dto.AdItem, int64, error)
	ListAll(ctx context.Context, userID uint64, req *dto.AllAdListRequest) ([]*dto.AdItem, int64, error)
}

type service struct {
	adRepo    adrepo.Repository
	groupRepo adgrouprepo.Repository
	advRepo   advertiserrepo.Repository
}

func New(
	adRepo adrepo.Repository,
	groupRepo adgrouprepo.Repository,
	advRepo advertiserrepo.Repository,
) Service {
	return &service{adRepo: adRepo, groupRepo: groupRepo, advRepo: advRepo}
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
