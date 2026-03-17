## ADDED Requirements

### Requirement: Overview aggregates spend metrics from local campaigns table
`stats.Service.Overview()` SHALL compute `total_spend`, `total_clicks`, `total_impressions`, and `total_conversions` by summing the corresponding columns in the `campaigns` table for all advertisers belonging to the current user (filtered by platform when specified). No platform API call SHALL be made for these four metrics.

#### Scenario: Spend totals reflect local campaign data
- **WHEN** `Overview` is called for a user who has two advertisers with total campaign spend of 500 and 300
- **THEN** `total_spend` equals 800 and no `GetReport` API call is made

#### Scenario: Platform filter is applied to campaign aggregation
- **WHEN** `Overview` is called with `platform = "tiktok"`
- **THEN** only campaigns belonging to TikTok advertisers are included in the aggregation

#### Scenario: Empty advertiser list returns zero metrics
- **WHEN** the user has no active advertisers matching the filter
- **THEN** `Overview` returns a result with all numeric fields set to zero without querying `campaigns`

### Requirement: GetReport is removed from the platform.Client interface
The `GetReport(ctx, accessToken, advertiserID, startDate, endDate)` method SHALL be removed from `platform.Client`. Neither the TikTok nor the Kwai implementation SHALL provide this method. The `ReportResult` struct SHALL be deleted from `platform/platform.go`.

#### Scenario: Platform interface compiles without GetReport
- **WHEN** the backend is compiled after the change
- **THEN** there are no references to `GetReport` or `ReportResult` anywhere in the codebase

### Requirement: stats.Service no longer depends on tokenRepo or encryptKey
`stats.New(...)` SHALL accept only `db *gorm.DB`, `log *zap.Logger` as arguments. It SHALL NOT hold a `tokenRepo`, `clients` map, or `encryptKey`.

#### Scenario: stats.Service constructor has reduced parameters
- **WHEN** `statssvc.New` is called at server startup
- **THEN** it requires only `db` and `log`, not `encryptKey` or platform clients
