## 1. Backend: DB Migration + Server Restart

- [ ] 1.1 Run `go run ./backend/migrations/migrate.go` from project root to add missing columns (`clicks`, `impressions`, `conversions`, `objective` on `campaigns`; `clicks`, `impressions`, `conversions`, `bid_type`, `bid_price` on `ad_groups`)
- [x] 1.2 Stop the running server process and restart it (`make run` or `go run ./backend/cmd/server/main.go`) so the new routes are live
- [x] 1.3 Verify `GET /api/v1/campaigns?page=1&page_size=20` returns HTTP 200 (use curl with a valid JWT)
- [x] 1.4 Verify `GET /api/v1/adgroups?page=1&page_size=20` returns HTTP 200
- [x] 1.5 Verify `GET /api/v1/ads?page=1&page_size=20` returns HTTP 200

## 2. iOS: Platform Filter Persistence Across Dimension Tabs

- [x] 2.1 In `AdsManageView`, update `DimensionTabRow` callbacks to pass `vm.platformFilter` when navigating to `allCampaigns`, `allAdGroups`, `allAds` destinations
- [x] 2.2 Update `AdsAllCampaignsView` to accept an initial platform filter parameter and initialize `AllCampaignsViewModel.platformFilter` with it
- [x] 2.3 Update `AdsAllAdGroupsView` to accept an initial platform filter parameter and initialize `AllAdGroupsViewModel.platformFilter` with it
- [x] 2.4 Update `AdsAllAdsView` to accept an initial platform filter parameter and initialize `AllAdsViewModel.platformFilter` with it
- [x] 2.5 Update `AdsNav` enum cases `.allCampaigns`, `.allAdGroups`, `.allAds` to carry an associated `Platform?` value
- [x] 2.6 Update `navigationDestination` switch in `AdsManageView` to pass the associated platform value into each "all" view

## 3. iOS: Summary Card in All-Campaigns and All-AdGroups Views

- [x] 3.1 In `AdsAllCampaignsView`, add `AdsSummaryCardView` above the list — aggregate `spend`, `clicks`, `impressions`, `conversions` from `vm.items`
- [x] 3.2 In `AdsAllAdGroupsView`, add `AdsSummaryCardView` above the list — aggregate the same metrics from `vm.items`

## 4. Validation

- [ ] 4.1 In the iOS simulator, tap the "推广系列" dimension tab from the accounts view — confirm campaigns load without errors
- [ ] 4.2 Select "TikTok" in the platform picker, then switch to "推广系列" — confirm filter is pre-applied in the new view
- [ ] 4.3 Confirm summary card appears and shows non-zero totals when data is present
- [ ] 4.4 Confirm "广告组" and "广告" dimension tabs also load correctly
