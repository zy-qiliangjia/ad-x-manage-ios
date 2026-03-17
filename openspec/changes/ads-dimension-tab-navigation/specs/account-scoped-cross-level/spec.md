## ADDED Requirements

### Requirement: Campaign-level tab switches to account-scoped views
When the user is inside `AdsCampaignView` (campaign list for a specific account) and taps a dimension tab, the navigation SHALL behave as follows:

| Tapped tab | Navigation result |
|---|---|
| 账号 | `navPath.removeAll()` (back to root) |
| 推广系列 | No-op (already at campaign level) |
| 广告组 | Push `.adGroupsForAccount(advertiser)` |
| 广告 | Push `.adsForAccount(advertiser)` |

#### Scenario: Tap 广告组 from campaign list (account scoped)
- **WHEN** the user is inside a specific account's campaign list and taps "广告组"
- **THEN** the app pushes `AdsAdGroupsForAccountView` showing all ad groups for that account (no campaign_id filter)

#### Scenario: Tap 账号 from campaign list
- **WHEN** the user is inside a specific account's campaign list and taps "账号"
- **THEN** the app pops back to the account list root

### Requirement: Ad group level tab switches to account-scoped or campaign-scoped views
When the user is inside `AdsAdGroupView` (ad group list for a specific campaign) and taps a dimension tab:

| Tapped tab | Navigation result |
|---|---|
| 账号 | `navPath.removeAll()` |
| 推广系列 | `navPath.removeLast()` (back to campaigns for same account) |
| 广告组 | No-op (already at ad group level) |
| 广告 | Push `.adsForAccount(advertiser)` |

#### Scenario: Tap 推广系列 from ad group list
- **WHEN** the user is inside an ad group list and taps "推广系列"
- **THEN** the app returns to the campaign list for the same account

#### Scenario: Tap 广告 from ad group list (account scoped)
- **WHEN** the user is inside an ad group list and taps "广告"
- **THEN** the app pushes `AdsAdsForAccountView` showing all ads for that account (no adgroup_id filter)

### Requirement: AdsAdGroupsForAccountView
`AdsAdGroupsForAccountView` SHALL display all ad groups for a specific advertiser, without filtering by campaign. It MUST call `GET /advertisers/:id/adgroups` without `campaign_id`. It SHALL support the same budget edit and status toggle as `AdsAdGroupView`. Tapping SHALL drill into `.ads(advertiser:, adgroup:)`.

#### Scenario: Load account-scoped ad groups without campaign filter
- **WHEN** the user navigates to `AdsAdGroupsForAccountView` for advertiser X
- **THEN** `GET /advertisers/X/adgroups` is called without `campaign_id` and all ad groups for that account are shown

### Requirement: AdsAdsForAccountView
`AdsAdsForAccountView` SHALL display all ads for a specific advertiser, without filtering by ad group. It MUST call `GET /advertisers/:id/ads` without `adgroup_id`. It SHALL support keyword search.

#### Scenario: Load account-scoped ads without ad group filter
- **WHEN** the user navigates to `AdsAdsForAccountView` for advertiser X
- **THEN** `GET /advertisers/X/ads` is called without `adgroup_id` and all ads for that account are shown

### Requirement: AdsNav extended cases
`AdsNav` MUST be extended with:
- `.allCampaigns` — global campaign list (no account filter)
- `.allAdGroups` — global ad group list
- `.allAds` — global ad list
- `.adGroupsForAccount(AdvertiserListItem)` — account-scoped all ad groups
- `.adsForAccount(AdvertiserListItem)` — account-scoped all ads

#### Scenario: Navigation destination handles all new cases
- **WHEN** `navPath` contains any of the new `AdsNav` cases
- **THEN** `navigationDestination(for: AdsNav.self)` presents the correct view without crashing
