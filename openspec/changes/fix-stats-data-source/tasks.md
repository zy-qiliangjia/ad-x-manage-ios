## 1. DB Migration

- [x] 1.1 Add a migration SQL file (or inline SQL) to `ALTER TABLE platform_tokens CHANGE access_token_enc access_token TEXT NOT NULL, CHANGE refresh_token_enc refresh_token TEXT`

## 2. Entity and Repository

- [x] 2.1 Rename struct fields in `model/entity/platform_token.go`: `AccessTokenEnc` → `AccessToken`, `RefreshTokenEnc` → `RefreshToken`; update GORM column tags to `access_token` / `refresh_token`
- [x] 2.2 Update `repository/token/repository.go`: rename the `accessTokenEnc` / `refreshTokenEnc` parameters in `Upsert`, `UpdateToken`, and any other methods; update all `token.AccessTokenEnc` / `token.RefreshTokenEnc` field references to use new names

## 3. Remove Encryption from Services

- [x] 3.1 `oauth/service.go`: remove `encrypt.Encrypt` calls — store `tokenResult.AccessToken` and `tokenResult.RefreshToken` directly on the entity; remove `encryptKey string` field and constructor parameter; remove `encrypt` import
- [x] 3.2 `sync/service.go`: in `getAccessToken` replace `encrypt.Decrypt(s.encryptKey, token.AccessTokenEnc)` with `token.AccessToken`; replace `encrypt.Encrypt` calls in the token-refresh helper with direct assignment; remove `encryptKey` field and constructor parameter; remove `encrypt` import
- [x] 3.3 `advertiser/service.go`: in `getAccessToken` replace `encrypt.Decrypt(s.encryptKey, token.AccessTokenEnc)` with `token.AccessToken`; remove `encryptKey` field and constructor parameter; remove `encrypt` import
- [x] 3.4 `campaign/service.go`: same as 3.3
- [x] 3.5 `adgroup/service.go`: same as 3.3

## 4. Remove GetReport from Platform Layer

- [x] 4.1 `platform/platform.go`: delete `GetReport(ctx, accessToken, advertiserID, startDate, endDate) (*ReportResult, error)` from the `Client` interface; delete the `ReportResult` struct
- [x] 4.2 `platform/tiktok/client.go`: delete the `GetReport` method and the `parseFloat` helper (used only by `GetReport`)
- [x] 4.3 `platform/kwai/client.go`: delete the `GetReport` method (and its equivalent helper if any)

## 5. Rewrite stats/service.go Overview

- [x] 5.1 Remove `clients map[string]platform.Client`, `tokenRepo tokenrepo.Repository`, and `encryptKey string` from the `service` struct and `New()` constructor in `stats/service.go`; remove the corresponding imports
- [x] 5.2 Replace the goroutine fan-out block (steps 3 in `Overview`) with a single SQL query: `SELECT COALESCE(SUM(spend),0), COALESCE(SUM(clicks),0), COALESCE(SUM(impressions),0), COALESCE(SUM(conversions),0) FROM campaigns WHERE advertiser_id IN (?)` over `advIDs`; assign results to `result.TotalSpend`, `result.TotalClicks`, `result.TotalImpressions`, `result.TotalConversions`
- [x] 5.3 Delete the `getAccessToken` helper function from `stats/service.go` (no longer needed)

## 6. Config and Wiring

- [x] 6.1 `config/config.go`: remove the `AppEncryptKey` (or equivalent) field; remove it from the struct tag and any validation
- [x] 6.2 `cmd/server/main.go`: remove `encryptKey` argument from all service constructor calls (`oauthsvc.New`, `syncsvc.New`, `advertisersvc.New`, `campaignsvc.New`, `adgroupsvc.New`); update `statssvc.New` to only pass `db` and `log`

## 7. Validation

- [x] 7.1 Build the backend (`go build ./...`) and confirm zero errors
- [x] 7.2 Run the DB migration against the local database
- [ ] 7.3 Re-authorise a TikTok account (existing encrypted token values are now invalid) and confirm the Dashboard loads with non-zero spend figures
- [ ] 7.4 Confirm the `.env` / config no longer requires `APP_ENCRYPT_KEY`
