## Context

The ads management tab (Tab3: `AdsManageView`) has a `DimensionTabRow` that lets users switch across four views: 账号 / 推广系列 / 广告组 / 广告. The three cross-advertiser views (`AdsAllCampaignsView`, `AdsAllAdGroupsView`, `AdsAllAdsView`) rely on three backend endpoints:

- `GET /api/v1/campaigns` → `campaignHandler.ListAll`
- `GET /api/v1/adgroups` → `adGroupHandler.ListAll`
- `GET /api/v1/ads` → `adHandler.ListAll`

After investigation, all three routes are correctly registered in `router.go` and fully implemented (handler → service → repository). The 404 error is caused solely by a **stale server binary** — the running process predates the route registrations. Additionally, the `campaigns` and `ad_groups` tables are missing newer columns (`clicks`, `impressions`, `conversions`, `objective`, `bid_type`, `bid_price`) because AutoMigrate has not been re-run.

There are also two iOS UX gaps:
1. Platform filter (全部 / TikTok / Kwai) is not preserved when switching dimension tabs.
2. `AdsAllCampaignsView` and `AdsAllAdGroupsView` lack the `AdsSummaryCardView` that per-advertiser drill-down views display.

## Goals / Non-Goals

**Goals:**
- Restore all three cross-advertiser list APIs by restarting the server and running DB migrations
- Preserve platform filter state when switching between dimension tabs in `AdsManageView`
- Add `AdsSummaryCardView` to `AdsAllCampaignsView` and `AdsAllAdGroupsView`

**Non-Goals:**
- Backend code changes (all routes and logic are already complete)
- New API endpoints
- Changes to data models or response shapes

## Decisions

**Decision: No backend code changes**
The route registration, handler, service, and repository code are all correct and compile cleanly. Only runtime restart is needed. Rationale: changing code that works would risk introducing regressions.

**Decision: Pass `platformFilter` as a binding into dimension-tab destinations**
The simplest iOS approach is to plumb the existing `vm.platformFilter` from `AdsManageView` into the navigation destinations (`AdsAllCampaignsView`, etc.) via a `Binding<Platform?>`. Alternative: use a shared `@EnvironmentObject`. Binding is preferred because it keeps the component coupling local and consistent with how other filter state is passed in this codebase.

**Decision: Add summary card with a local stats load in AllCampaigns/AllAdGroups views**
These views should show aggregate spend/clicks/impressions/conversions. The simplest approach is to compute totals from the currently loaded page on the client. A richer approach would be a dedicated server-side stats endpoint for cross-advertiser scope — but that is out of scope for this fix; client-side aggregation is sufficient.

## Risks / Trade-offs

- [Risk] DB AutoMigrate may timeout on large tables → Mitigation: Run migrate in a maintenance window; columns have `DEFAULT 0` so existing rows are unaffected and the migration is non-blocking on MySQL 8+.
- [Risk] Server restart drops in-flight requests → Mitigation: Development environment only; use graceful shutdown in production via `context.WithTimeout`.
- [Trade-off] Client-side summary totals only reflect the current page, not all data → Acceptable for now; a full aggregate endpoint is a future enhancement.

## Migration Plan

1. From the project root: `go run ./backend/migrations/migrate.go` — adds new columns to `campaigns` and `ad_groups`.
2. Stop the running server and restart: `go run ./backend/cmd/server/main.go` (or `make run`).
3. Verify: `curl -H "Authorization: Bearer <token>" http://localhost:8080/api/v1/campaigns?page=1&page_size=20` should return 200.
4. Apply iOS changes to `AdsManageView.swift` for platform filter binding and summary cards.

## Open Questions

- None — root cause is confirmed and all fixes are straightforward.
