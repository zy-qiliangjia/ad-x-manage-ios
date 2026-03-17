## ADDED Requirements

### Requirement: Global campaigns list view
`AdsAllCampaignsView` SHALL display a paginated list of all campaigns across all advertiser accounts belonging to the current user. It MUST support platform filter (segmented picker) and pull-to-refresh. It SHALL be read-only (no budget edit or status toggle). Tapping an item SHALL navigate to that campaign's ad groups scoped to the parent account (`.adGroups(advertiser:, campaign:)`).

#### Scenario: Load global campaigns
- **WHEN** the user navigates to `AdsAllCampaignsView`
- **THEN** the view calls `GET /campaigns` and renders a paginated list

#### Scenario: Platform filter
- **WHEN** the user selects a platform in the picker
- **THEN** the list reloads showing only campaigns for that platform

#### Scenario: Tap a campaign
- **WHEN** the user taps a campaign row in the global view
- **THEN** the app navigates to the ad group list scoped to that campaign and its parent account

### Requirement: Global ad groups list view
`AdsAllAdGroupsView` SHALL display a paginated list of all ad groups across all accounts. It MUST support platform filter and pull-to-refresh. It SHALL be read-only. Tapping SHALL navigate to `.ads(advertiser:, adgroup:)`.

#### Scenario: Load global ad groups
- **WHEN** the user navigates to `AdsAllAdGroupsView`
- **THEN** the view calls `GET /adgroups` and renders a paginated list

#### Scenario: Tap an ad group
- **WHEN** the user taps an ad group row in the global view
- **THEN** the app navigates to the ads list for that ad group

### Requirement: Global ads list view
`AdsAllAdsView` SHALL display a paginated list of all ads across all accounts. It MUST support search and platform filter. It SHALL be read-only.

#### Scenario: Load global ads
- **WHEN** the user navigates to `AdsAllAdsView`
- **THEN** the view calls `GET /ads` and renders a paginated list

#### Scenario: Search ads
- **WHEN** the user enters text in the search bar
- **THEN** the list filters to matching ad names or IDs via the `keyword` query param

### Requirement: Backend global list endpoints
The backend SHALL expose three new endpoints:
- `GET /api/v1/campaigns` — all campaigns for the current user (scoped by JWT)
- `GET /api/v1/adgroups` — all ad groups for the current user
- `GET /api/v1/ads` — all ads for the current user

All three MUST support `platform`, `keyword`, `page`, `page_size` query params and return the same pagination envelope as existing endpoints. Results MUST be filtered to only the accounts owned by the authenticated user.

#### Scenario: Global campaigns endpoint returns only user's data
- **WHEN** `GET /campaigns` is called with a valid JWT
- **THEN** only campaigns belonging to advertisers owned by that user are returned

#### Scenario: Pagination works on global endpoints
- **WHEN** `GET /campaigns?page=2&page_size=20` is called
- **THEN** the response contains the correct page of results with accurate `has_more` and `total`
