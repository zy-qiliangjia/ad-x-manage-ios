## ADDED Requirements

### Requirement: Platform filter persists across dimension tab switches
When the user switches between dimension tabs (账号 / 推广系列 / 广告组 / 广告) in the ads management screen, the currently selected platform filter SHALL be applied to the newly opened view.

#### Scenario: Switch from 账号 to 推广系列 with TikTok filter active
- **WHEN** the user has selected "TikTok" in the platform picker and taps the "推广系列" dimension tab
- **THEN** `AdsAllCampaignsView` opens with its platform filter pre-set to "TikTok" and immediately loads TikTok campaigns

#### Scenario: Switch from 推广系列 to 广告组 with Kwai filter active
- **WHEN** the user is viewing all campaigns with "Kwai" selected and taps the "广告组" tab
- **THEN** `AdsAllAdGroupsView` opens with its platform filter set to "Kwai"

#### Scenario: No filter selected
- **WHEN** the platform picker shows "全部" (nil) and the user switches dimension tabs
- **THEN** the destination view loads with "全部" and shows all platforms

### Requirement: Summary card shown in all-campaigns and all-adgroups views
`AdsAllCampaignsView` and `AdsAllAdGroupsView` SHALL display an `AdsSummaryCardView` at the top of the list, aggregating spend, clicks, impressions, and conversions from the currently loaded items.

#### Scenario: Summary card renders in all-campaigns view
- **WHEN** `AdsAllCampaignsView` loads campaign items successfully
- **THEN** an `AdsSummaryCardView` is displayed above the list with aggregated totals from the loaded page

#### Scenario: Summary card renders in all-adgroups view
- **WHEN** `AdsAllAdGroupsView` loads adgroup items successfully
- **THEN** an `AdsSummaryCardView` is displayed above the list with aggregated totals
