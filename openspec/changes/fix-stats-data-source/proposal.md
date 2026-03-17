## Why

`Overview` in `stats/service.go` calls `client.GetReport()` per advertiser, which hits TikTok's `/report/advertiser/get/` endpoint. This endpoint requires the `report:read` OAuth scope that is not granted in the current app registration, causing error `40001: Permission error` for every TikTok advertiser and returning zero spend/clicks/impressions/conversions on the Dashboard. Additionally, the token encryption layer (AES-256-GCM) adds unnecessary complexity for a development/internal tool — plaintext storage is sufficient.

## What Changes

- **BREAKING** Remove per-advertiser `GetReport()` calls from `Overview`; replace with a single SQL aggregation over the local `campaigns` table (which already stores `spend`, `clicks`, `impressions`, `conversions` from sync).
- Remove `GetReport` method from `platform.Client` interface and both TikTok and Kwai implementations.
- **BREAKING** Remove AES-256-GCM encryption from token storage: rename DB columns `access_token_enc` → `access_token` and `refresh_token_enc` → `refresh_token`; store and read plaintext values throughout.
- Remove `encrypt` package usage from all services that read or write tokens (`oauth`, `sync`, `stats`, `advertiser`, `campaign`, `adgroup`).
- Remove `encryptKey` parameter from all service constructors that currently accept it.
- Remove `APP_ENCRYPT_KEY` config field (no longer needed).

## Capabilities

### New Capabilities

- `stats-from-local-db`: Dashboard Overview aggregates spend/clicks/impressions/conversions from local `campaigns` table via SQL instead of calling the platform report API.

### Modified Capabilities

- `token-storage`: Platform token persistence no longer encrypts access/refresh tokens; column names change from `*_enc` to plain names and the entity struct fields are updated accordingly.

## Impact

- **Backend files**: `stats/service.go`, `oauth/service.go`, `sync/service.go`, `advertiser/service.go`, `campaign/service.go`, `adgroup/service.go`, `platform/platform.go`, `platform/tiktok/client.go`, `platform/kwai/client.go`, `model/entity/platform_token.go`, `config/config.go`, `cmd/server/main.go`.
- **DB migration**: ALTER TABLE `platform_tokens` to rename columns; UPDATE existing rows is not needed (tokens will be re-authorised or can be manually re-inserted).
- **No iOS changes** required.
- **No backend API contract changes** — request/response shapes are unchanged.
