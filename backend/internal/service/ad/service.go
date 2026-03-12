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
	if err := s.checkOwnership(ctx, userID, advertiserID); err != nil {
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

	// 批量查询广告组名称，构建 internal_id → name 映射。
	nameMap, _ := s.buildAdGroupNameMap(ctx, advertiserID)

	items := make([]*dto.AdItem, 0, len(list))
	for _, a := range list {
		item := toAdItem(a)
		item.AdgroupName = nameMap[a.AdgroupID]
		items = append(items, item)
	}
	return items, total, nil
}

func (s *service) checkOwnership(ctx context.Context, userID, advertiserID uint64) error {
	adv, err := s.advRepo.FindByID(ctx, advertiserID)
	if err != nil || adv == nil {
		return ErrNotFound
	}
	if adv.UserID != userID {
		return ErrForbidden
	}
	return nil
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

func toAdItem(a *entity.Ad) *dto.AdItem {
	return &dto.AdItem{
		ID: a.ID, AdID: a.AdID, AdName: a.AdName,
		AdgroupID: a.AdgroupID, Status: a.Status, CreativeType: a.CreativeType,
	}
}
