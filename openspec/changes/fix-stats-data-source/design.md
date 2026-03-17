## Context

Two independent problems need fixing:

**Problem 1 — Report API permission error**
`stats/service.Overview()` fans out to N `client.GetReport()` calls (one per advertiser), hitting TikTok's `/report/advertiser/get/` POST endpoint. The app's OAuth registration does not include the `report:read` scope, so every TikTok advertiser returns error 40001 and the Dashboard shows zero for all metrics. The local `campaigns` table already stores `spend`, `clicks`, `impressions`, `conversions` from the background sync; the data is available without calling any platform API.

**Problem 2 — Unnecessary token encryption**
Six backend services (`oauth`, `sync`, `advertiser`, `campaign`, `adgroup`, `stats`) all carry an `encryptKey string` in their constructor and call `encrypt.Encrypt` / `encrypt.Decrypt` on every token read/write. For a development/internal tool, AES-256-GCM encryption is overkill — it complicates debugging, requires `APP_ENCRYPT_KEY` to be set correctly in every environment, and breaks silently if the key changes.

## Goals / Non-Goals

**Goals:**
- Dashboard Overview returns real spend/clicks/impressions/conversions sourced from local DB.
- Token storage uses plaintext; all `encrypt.*` calls are removed.
- `GetReport` is deleted from the platform interface and both client implementations.
- All six services lose the `encryptKey` constructor parameter.

**Non-Goals:**
- Re-adding report-API support (scope would need to be requested from TikTok).
- Migrating existing encrypted token rows — tokens will need to be re-authorised after the column rename (or manually updated).
- Any iOS changes.

## Decisions

**Decision: Aggregate spend from `campaigns` table, not `ad_groups`**
Campaigns hold the top-level spend that matches what the report API returned at `AUCTION_ADVERTISER` level. Summing campaign-level spend avoids double-counting (a campaign's spend = sum of its ad groups' spend, so picking one level is sufficient). `aggregateCampaigns` already exists in the same file and can be reused.

**Decision: Remove `GetReport` from `platform.Client` interface entirely**
Keeping a dead interface method misleads future contributors. Both TikTok and Kwai implementations are deleted. The `ReportResult` struct in `platform/platform.go` is also deleted since nothing uses it.

**Decision: Rename DB columns, not add new ones**
A clean rename (`access_token_enc` → `access_token`, `refresh_token_enc` → `refresh_token`) is simpler than adding new columns alongside old ones. All existing tokens become invalid after rename; users must re-authorise. This is acceptable for an internal tool.

**Decision: Store tokens as plaintext (no new encryption scheme)**
The replacement is no encryption at all — just store the raw string. If encryption is desired later it can be re-added as a separate change with proper key-rotation support.

**Decision: Remove `tokenRepo` and `encryptKey` from `stats/service`**
With the report API gone, `stats/service` only reads the local DB and needs no token access. Removing these dependencies shrinks the constructor and eliminates a whole category of possible errors.

## Risks / Trade-offs

- [Risk] Existing encrypted token rows become unreadable after column rename → Mitigation: users re-authorise; document this in migration instructions.
- [Risk] Spend/clicks data in `campaigns` table may be stale if sync has not run recently → Accepted: the Dashboard already shows "last synced" time, and the manual sync button exists for freshness.
- [Trade-off] Removing encryption reduces security posture → Accepted for internal/dev use; note in README if plaintext storage is a concern.

## Migration Plan

1. Run DB migration: `ALTER TABLE platform_tokens CHANGE access_token_enc access_token TEXT NOT NULL, CHANGE refresh_token_enc refresh_token TEXT;`
2. Re-authorise all platform accounts (existing encrypted values are now invalid).
3. Deploy updated backend binary.
4. Verify Dashboard loads with real spend figures.

**Rollback**: Rename columns back; re-deploy previous binary. Token re-authorisation required again.

## Open Questions

None.
