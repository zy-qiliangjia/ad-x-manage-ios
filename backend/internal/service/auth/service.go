package authsvc

import (
	"context"
	"errors"
	"time"

	"github.com/redis/go-redis/v9"
	"golang.org/x/crypto/bcrypt"

	"ad-x-manage/backend/internal/model/dto"
	"ad-x-manage/backend/internal/model/entity"
	"ad-x-manage/backend/internal/pkg/cache"
	"ad-x-manage/backend/internal/pkg/jwtutil"
	userrepo "ad-x-manage/backend/internal/repository/user"
)

// 业务错误
var (
	ErrEmailAlreadyExists = errors.New("email already exists")
	ErrInvalidCredentials = errors.New("invalid email or password")
	ErrUserDisabled       = errors.New("account is disabled")
)

// Service 定义认证业务接口。
type Service interface {
	Register(ctx context.Context, req *dto.RegisterRequest) error
	Login(ctx context.Context, req *dto.LoginRequest) (*dto.LoginResponse, error)
	Logout(ctx context.Context, jti string, ttl time.Duration) error
	Refresh(ctx context.Context, userID uint64, email string) (*dto.RefreshResponse, error)
}

type service struct {
	userRepo  userrepo.Repository
	rdb       *redis.Client
	jwtSecret string
}

func New(userRepo userrepo.Repository, rdb *redis.Client, jwtSecret string) Service {
	return &service{
		userRepo:  userRepo,
		rdb:       rdb,
		jwtSecret: jwtSecret,
	}
}

// Register 注册新用户（邮箱唯一校验 + bcrypt 密码哈希）。
func (s *service) Register(ctx context.Context, req *dto.RegisterRequest) error {
	existing, err := s.userRepo.FindByEmail(ctx, req.Email)
	if err != nil {
		return err
	}
	if existing != nil {
		return ErrEmailAlreadyExists
	}

	hash, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
	if err != nil {
		return err
	}

	return s.userRepo.Create(ctx, &entity.User{
		Email:        req.Email,
		PasswordHash: string(hash),
		Name:         req.Name,
	})
}

// Login 邮箱密码登录，验证通过后签发 JWT。
func (s *service) Login(ctx context.Context, req *dto.LoginRequest) (*dto.LoginResponse, error) {
	user, err := s.userRepo.FindByEmail(ctx, req.Email)
	if err != nil {
		return nil, err
	}
	// 邮箱不存在与密码错误返回相同错误，避免用户枚举
	if user == nil {
		return nil, ErrInvalidCredentials
	}
	if err = bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(req.Password)); err != nil {
		return nil, ErrInvalidCredentials
	}
	if user.Status == 0 {
		return nil, ErrUserDisabled
	}

	tokenStr, _, expiresAt, err := jwtutil.Sign(s.jwtSecret, user.ID, user.Email)
	if err != nil {
		return nil, err
	}

	// 异步更新最后登录时间，不影响登录响应
	go func() {
		_ = s.userRepo.UpdateLastLoginAt(context.Background(), user.ID, time.Now())
	}()

	return &dto.LoginResponse{
		Token:     tokenStr,
		ExpiresAt: expiresAt,
		User: dto.UserInfo{
			ID:    user.ID,
			Email: user.Email,
			Name:  user.Name,
		},
	}, nil
}

// Logout 将当前 JWT 的 jti 加入 Redis 黑名单，TTL = Token 剩余有效期。
func (s *service) Logout(ctx context.Context, jti string, ttl time.Duration) error {
	return cache.BlacklistToken(ctx, s.rdb, jti, ttl)
}

// Refresh 用已登录的 Token 换取新 Token（旧 Token 继续有效直至过期，由客户端替换）。
func (s *service) Refresh(ctx context.Context, userID uint64, email string) (*dto.RefreshResponse, error) {
	tokenStr, _, expiresAt, err := jwtutil.Sign(s.jwtSecret, userID, email)
	if err != nil {
		return nil, err
	}
	return &dto.RefreshResponse{
		Token:     tokenStr,
		ExpiresAt: expiresAt,
	}, nil
}
