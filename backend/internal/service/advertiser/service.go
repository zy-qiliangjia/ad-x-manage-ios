package advertisersvc

import (
	"context"
	"errors"
	"fmt"
	"time"

	"go.uber.org/zap"

	"ad-x-manage/backend/internal/model/dto"
	"ad-x-manage/backend/internal/model/entity"
	"ad-x-manage/backend/internal/pkg/encrypt"
	advertiserrepo "ad-x-manage/backend/internal/repository/advertiser"
	tokenrepo "ad-x-manage/backend/internal/repository/token"
	"ad-x-manage/backend/internal/service/platform"
	syncsvc "ad-x-manage/backend/internal/service/sync"
)

var (
	ErrNotFound  = errors.New("advertiser not found")
	ErrForbidden = errors.New("no permission")
)

type Service interface {
	List(ctx context.Context, userID uint64, req *dto.AdvertiserListRequest) ([]*dto.AdvertiserListItem, int64, error)
	GetBalance(ctx context.Context, userID, advertiserID uint64) (*dto.BalanceResponse, error)
	Sync(ctx context.Context, userID, advertiserID uint64) (*dto.SyncResponse, error)
	// SyncAll 对当前用户所有有效广告主触发后台全量同步，立即返回广告主数量。
	SyncAll(ctx context.Context, userID uint64) (int, error)
}

type service struct {
	advRepo    advertiserrepo.Repository
	tokenRepo  tokenrepo.Repository
	clients    map[string]platform.Client
	syncSvc    syncsvc.Service
	encryptKey string
	log        *zap.Logger
}

func New(
	advRepo advertiserrepo.Repository,
	tokenRepo tokenrepo.Repository,
	clients map[string]platform.Client,
	syncSvc syncsvc.Service,
	encryptKey string,
	log *zap.Logger,
) Service {
	return &service{
		advRepo:    advRepo,
		tokenRepo:  tokenRepo,
		clients:    clients,
		syncSvc:    syncSvc,
		encryptKey: encryptKey,
		log:        log,
	}
}

// List 查询当前用户的广告主列表（支持平台过滤、关键词搜索、分页）。
func (s *service) List(ctx context.Context, userID uint64, req *dto.AdvertiserListRequest) ([]*dto.AdvertiserListItem, int64, error) {
	if req.Page < 1 {
		req.Page = 1
	}
	if req.PageSize < 1 || req.PageSize > 100 {
		req.PageSize = 20
	}

	list, total, err := s.advRepo.FindByUserAndPlatform(ctx, userID, req.Platform, req.Keyword, req.Page, req.PageSize)
	if err != nil {
		return nil, 0, err
	}

	items := make([]*dto.AdvertiserListItem, 0, len(list))
	for _, a := range list {
		items = append(items, toListItem(a))
	}
	return items, total, nil
}

// GetBalance 实时查询广告主余额（不走缓存，直接调用平台 API）。
func (s *service) GetBalance(ctx context.Context, userID, advertiserID uint64) (*dto.BalanceResponse, error) {
	adv, err := s.checkOwnership(ctx, userID, advertiserID)
	if err != nil {
		return nil, err
	}

	accessToken, err := s.getAccessToken(ctx, adv.TokenID, adv.Platform)
	if err != nil {
		return nil, fmt.Errorf("get access token: %w", err)
	}

	client, ok := s.clients[adv.Platform]
	if !ok {
		return nil, fmt.Errorf("unsupported platform: %s", adv.Platform)
	}

	balance, err := client.GetBalance(accessToken, adv.AdvertiserID)
	if err != nil {
		return nil, fmt.Errorf("platform get balance: %w", err)
	}

	return &dto.BalanceResponse{
		AdvertiserID: adv.AdvertiserID,
		Balance:      balance.Balance,
		Currency:     balance.Currency,
	}, nil
}

// Sync 手动触发全量数据同步（同步运行，有 context 超时控制）。
func (s *service) Sync(ctx context.Context, userID, advertiserID uint64) (*dto.SyncResponse, error) {
	adv, err := s.checkOwnership(ctx, userID, advertiserID)
	if err != nil {
		return nil, err
	}

	result, err := s.syncSvc.SyncAdvertiser(ctx, adv)
	if err != nil {
		return nil, fmt.Errorf("sync failed: %w", err)
	}

	return &dto.SyncResponse{
		AdvertiserID:  advertiserID,
		CampaignCount: result.CampaignCount,
		AdGroupCount:  result.AdGroupCount,
		AdCount:       result.AdCount,
		Duration:      result.Duration.String(),
		Errors:        result.Errors,
	}, nil
}

// SyncAll 对当前用户所有有效广告主在后台触发全量同步，立即返回广告主数量（异步，不等待结果）。
func (s *service) SyncAll(ctx context.Context, userID uint64) (int, error) {
	advs, err := s.advRepo.FindAllActiveByUserID(ctx, userID)
	if err != nil {
		return 0, fmt.Errorf("query advertisers: %w", err)
	}
	for _, adv := range advs {
		adv := adv
		go func() {
			bgCtx, cancel := context.WithTimeout(context.Background(), 10*time.Minute)
			defer cancel()
			if _, err := s.syncSvc.SyncAdvertiser(bgCtx, adv); err != nil {
				s.log.Warn("SyncAll background sync failed",
					zap.Uint64("advertiser_id", adv.ID),
					zap.String("platform", adv.Platform),
					zap.Error(err),
				)
			}
		}()
	}
	return len(advs), nil
}

// ── 工具方法 ───────────────────────────────────────────────────

// checkOwnership 确认该广告主属于当前用户。
func (s *service) checkOwnership(ctx context.Context, userID, advertiserID uint64) (*entity.Advertiser, error) {
	adv, err := s.advRepo.FindByID(ctx, advertiserID)
	if err != nil {
		return nil, err
	}
	if adv == nil {
		return nil, ErrNotFound
	}
	if adv.UserID != userID {
		return nil, ErrForbidden
	}
	return adv, nil
}

// getAccessToken 从 DB 解密 access_token。
func (s *service) getAccessToken(ctx context.Context, tokenID uint64, _ string) (string, error) {
	token, err := s.tokenRepo.FindByID(ctx, tokenID)
	if err != nil || token == nil {
		return "", fmt.Errorf("token not found")
	}
	return encrypt.Decrypt(s.encryptKey, token.AccessTokenEnc)
}

func toListItem(a *entity.Advertiser) *dto.AdvertiserListItem {
	return &dto.AdvertiserListItem{
		ID:             a.ID,
		Platform:       a.Platform,
		AdvertiserID:   a.AdvertiserID,
		AdvertiserName: a.AdvertiserName,
		Currency:       a.Currency,
		Timezone:       a.Timezone,
		Status:         a.Status,
		SyncedAt:       a.SyncedAt,
	}
}
