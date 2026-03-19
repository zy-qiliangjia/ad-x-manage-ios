package authsvc

import (
	"context"
	"crypto/rand"
	"errors"
	"time"

	"github.com/redis/go-redis/v9"
	"golang.org/x/crypto/bcrypt"

	"ad-x-manage/backend/internal/model/dto"
	"ad-x-manage/backend/internal/model/entity"
	"ad-x-manage/backend/internal/pkg/cache"
	"ad-x-manage/backend/internal/pkg/jwtutil"
	inviterepo "ad-x-manage/backend/internal/repository/invite"
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
	invRepo   inviterepo.Repository
	rdb       *redis.Client
	jwtSecret string
	product   string
}

func New(userRepo userrepo.Repository, invRepo inviterepo.Repository, rdb *redis.Client, jwtSecret, product string) Service {
	return &service{
		userRepo:  userRepo,
		invRepo:   invRepo,
		rdb:       rdb,
		jwtSecret: jwtSecret,
		product:   product,
	}
}

// Register 注册新用户（邮箱唯一校验 + bcrypt 密码哈希）。
// 若提供有效邀请码，双方各获得 +5 账号额度。
func (s *service) Register(ctx context.Context, req *dto.RegisterRequest) error {
	existing, err := s.userRepo.FindByEmail(ctx, s.product, req.Email)
	if err != nil {
		return err
	}
	if existing != nil {
		return ErrEmailAlreadyExists
	}

	// 校验邀请码（可选）
	var inviter *entity.User
	if req.InviteCode != "" {
		inviter, err = s.userRepo.FindByInviteCode(ctx, req.InviteCode)
		if err != nil {
			return err
		}
		// 邀请码不存在时忽略，不影响注册流程
	}

	hash, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
	if err != nil {
		return err
	}

	inviteCode, err := generateInviteCode()
	if err != nil {
		return err
	}

	quota := 5
	if inviter != nil {
		quota = 10 // 被邀请者额外获得 +5
	}

	newUser := &entity.User{
		Product:      s.product,
		Email:        req.Email,
		PasswordHash: string(hash),
		Name:         req.Name,
		InviteCode:   inviteCode,
		Quota:        quota,
	}
	if inviter != nil {
		newUser.InvitedBy = &inviter.ID
	}
	if err := s.userRepo.Create(ctx, newUser); err != nil {
		return err
	}

	// 邀请人 +5 额度，并写入邀请记录
	if inviter != nil {
		_ = s.userRepo.AddQuota(ctx, inviter.ID, 5)
		_ = s.invRepo.CreateRecord(ctx, &entity.InviteRecord{
			InviterID: inviter.ID,
			InviteeID: newUser.ID,
		})
	}

	return nil
}

// generateInviteCode 生成格式为 AP-XXXXXX 的邀请码（排除易混淆字符 O/0/I/1）。
func generateInviteCode() (string, error) {
	const charset = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789" // 排除 O、I；排除 0、1
	const codeLen = 6
	b := make([]byte, codeLen)
	if _, err := rand.Read(b); err != nil {
		return "", err
	}
	result := make([]byte, codeLen)
	for i, v := range b {
		result[i] = charset[int(v)%len(charset)]
	}
	return "AP-" + string(result), nil
}

// Login 邮箱密码登录，验证通过后签发 JWT。
func (s *service) Login(ctx context.Context, req *dto.LoginRequest) (*dto.LoginResponse, error) {
	user, err := s.userRepo.FindByEmail(ctx, s.product, req.Email)
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
