## ADDED Requirements

### Requirement: DimensionTabRow accepts onSelect callback
`DimensionTabRow` SHALL accept an `onSelect: (AdsDimension) -> Void` callback parameter. Each tab MUST be wrapped in a `Button` that triggers `onSelect(dim)` when tapped.

The currently active dimension (matching `activeDimension`) SHALL remain visually highlighted. Tapping the already-active tab SHALL still fire `onSelect`.

#### Scenario: User taps an inactive dimension tab
- **WHEN** the user taps a dimension tab that is not the active one
- **THEN** `onSelect` is called with the tapped `AdsDimension` value

#### Scenario: User taps the active dimension tab
- **WHEN** the user taps the currently active dimension tab
- **THEN** `onSelect` is called with the same `AdsDimension` value (no-op navigation is the caller's responsibility)

### Requirement: Account-level tab navigation (global mode)
When `DimensionTabRow` is displayed at the account-list root of Tab3 and the user taps a non-account dimension, the app SHALL navigate to the corresponding global view.

| Tapped tab | Navigation result |
|---|---|
| 账号 | No-op (already at root) |
| 推广系列 | Push `.allCampaigns` |
| 广告组 | Push `.allAdGroups` |
| 广告 | Push `.allAds` |

#### Scenario: Tap 推广系列 from account list
- **WHEN** the user is at the account-list level and taps "推广系列"
- **THEN** the app navigates to `AdsAllCampaignsView` showing all campaigns across all accounts

#### Scenario: Tap 广告组 from account list
- **WHEN** the user is at the account-list level and taps "广告组"
- **THEN** the app navigates to `AdsAllAdGroupsView` showing all ad groups across all accounts

#### Scenario: Tap 广告 from account list
- **WHEN** the user is at the account-list level and taps "广告"
- **THEN** the app navigates to `AdsAllAdsView` showing all ads across all accounts
