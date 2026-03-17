## Why

The ads management tab (Tab3) has a "维度切换" (DimensionTabRow) feature that lets users switch between 账号 / 推广系列 / 广告组 / 广告 views. Clicking 推广系列, 广告组, or 广告 navigates to the cross-advertiser list views (`AdsAllCampaignsView`, `AdsAllAdGroupsView`, `AdsAllAdsView`) which call `GET /api/v1/campaigns`, `/adgroups`, `/ads` respectively — but these return 404 in the running server.

## What Changes

- Rebuild and restart the backend server so the already-registered routes (`GET /campaigns`, `GET /adgroups`, `GET /ads`) are live
- Run DB AutoMigrate so newer columns (`clicks`, `impressions`, `conversions`, `objective` on `campaigns`; `clicks`, `impressions`, `conversions`, `bid_type`, `bid_price` on `ad_groups`) are added to existing tables
- Fix iOS platform-filter persistence: when switching between dimension tabs, the current platform selection (全部 / TikTok / Kwai) should be passed along so the new view loads with the same filter
- Fix iOS summary card missing in `AdsAllCampaignsView` and `AdsAllAdGroupsView` — unlike the per-advertiser drill-down views, the cross-advertiser views show no `AdsSummaryCardView`

## Capabilities

### New Capabilities

- `ads-dimension-tab-polish`: Platform-filter state shared across dimension tab switches; summary card added to all-campaigns and all-adgroups views

### Modified Capabilities

- `ads-tab-routing`: Server restart + DB migration required to activate existing cross-advertiser list routes

## Impact

- **Backend**: No code changes; requires `make run` / server restart and `go run ./migrations/migrate.go`
- **iOS `AdsManageView.swift`**: Pass `platformFilter` into child navigation destinations so filter persists; add `AdsSummaryCardView` to `AdsAllCampaignsView` and `AdsAllAdGroupsView`
- No new API endpoints, no model changes
