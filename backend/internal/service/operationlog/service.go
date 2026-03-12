package operationlogsvc

import (
	"context"
	"errors"
	"time"

	advertiserrepo "ad-x-manage/backend/internal/repository/advertiser"
	operationlogrepo "ad-x-manage/backend/internal/repository/operationlog"

	"ad-x-manage/backend/internal/model/dto"
	"ad-x-manage/backend/internal/model/entity"
)

var (
	ErrForbidden = errors.New("no permission")
)

type Service interface {
	List(ctx context.Context, userID uint64, req *dto.OperationLogListRequest) ([]*dto.OperationLogItem, int64, error)
}

type service struct {
	logRepo operationlogrepo.Repository
	advRepo advertiserrepo.Repository
}

func New(logRepo operationlogrepo.Repository, advRepo advertiserrepo.Repository) Service {
	return &service{logRepo: logRepo, advRepo: advRepo}
}

// List 分页查询操作日志。若指定 advertiser_id，验证归属权后再过滤。
func (s *service) List(ctx context.Context, userID uint64, req *dto.OperationLogListRequest) ([]*dto.OperationLogItem, int64, error) {
	// 若指定了广告主，需确认归属（防止越权查看他人日志）
	if req.AdvertiserID > 0 {
		adv, err := s.advRepo.FindByID(ctx, req.AdvertiserID)
		if err != nil || adv == nil || adv.UserID != userID {
			return nil, 0, ErrForbidden
		}
	}

	if req.Page < 1 {
		req.Page = 1
	}
	if req.PageSize < 1 || req.PageSize > 100 {
		req.PageSize = 20
	}

	filter := operationlogrepo.ListFilter{
		AdvertiserID: req.AdvertiserID,
		Platform:     req.Platform,
		Action:       req.Action,
		TargetType:   req.TargetType,
		Result:       req.Result,
		Page:         req.Page,
		PageSize:     req.PageSize,
	}

	if t := parseDate(req.StartDate, false); t != nil {
		filter.StartTime = t
	}
	if t := parseDate(req.EndDate, true); t != nil {
		filter.EndTime = t
	}

	list, total, err := s.logRepo.List(ctx, userID, filter)
	if err != nil {
		return nil, 0, err
	}

	items := make([]*dto.OperationLogItem, 0, len(list))
	for _, l := range list {
		items = append(items, toItem(l))
	}
	return items, total, nil
}

// parseDate 将 "YYYY-MM-DD" 解析为 UTC 时间。
// isEnd=true 时返回当天结束时刻（次日 00:00:00）以便做 < 查询。
func parseDate(s string, isEnd bool) *time.Time {
	if s == "" {
		return nil
	}
	t, err := time.ParseInLocation("2006-01-02", s, time.UTC)
	if err != nil {
		return nil
	}
	if isEnd {
		next := t.AddDate(0, 0, 1)
		return &next
	}
	return &t
}

func toItem(l *entity.OperationLog) *dto.OperationLogItem {
	return &dto.OperationLogItem{
		ID:           l.ID,
		AdvertiserID: l.AdvertiserID,
		Platform:     l.Platform,
		Action:       l.Action,
		TargetType:   l.TargetType,
		TargetID:     l.TargetID,
		TargetName:   l.TargetName,
		BeforeVal:    map[string]any(l.BeforeVal),
		AfterVal:     map[string]any(l.AfterVal),
		Result:       l.Result,
		FailReason:   l.FailReason,
		CreatedAt:    l.CreatedAt,
	}
}
