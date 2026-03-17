## ADDED Requirements

### Requirement: Cross-advertiser campaign list is accessible
The system SHALL serve `GET /api/v1/campaigns` with paginated results for the authenticated user's campaigns across all advertisers, with optional `platform` and `keyword` filtering.

#### Scenario: Successful cross-advertiser campaigns request
- **WHEN** an authenticated user sends `GET /api/v1/campaigns?page=1&page_size=20`
- **THEN** the server returns HTTP 200 with a JSON payload containing `data` (array of campaign items) and `pagination`

#### Scenario: Platform filter applied
- **WHEN** an authenticated user sends `GET /api/v1/campaigns?platform=tiktok&page=1&page_size=20`
- **THEN** the response contains only campaigns belonging to TikTok advertisers owned by the user

### Requirement: Cross-advertiser adgroup list is accessible
The system SHALL serve `GET /api/v1/adgroups` with paginated results across all the user's advertisers.

#### Scenario: Successful cross-advertiser adgroups request
- **WHEN** an authenticated user sends `GET /api/v1/adgroups?page=1&page_size=20`
- **THEN** the server returns HTTP 200 with adgroup items and pagination

### Requirement: Cross-advertiser ad list is accessible
The system SHALL serve `GET /api/v1/ads` with paginated results across all the user's advertisers.

#### Scenario: Successful cross-advertiser ads request
- **WHEN** an authenticated user sends `GET /api/v1/ads?page=1&page_size=20`
- **THEN** the server returns HTTP 200 with ad items and pagination

### Requirement: Campaign and adgroup tables have performance metric columns
The database MUST contain `clicks`, `impressions`, `conversions`, and `objective` columns on the `campaigns` table, and `clicks`, `impressions`, `conversions`, `bid_type`, `bid_price` columns on the `ad_groups` table.

#### Scenario: AutoMigrate adds missing columns
- **WHEN** the migration is run (`go run ./backend/migrations/migrate.go`) on a DB that lacks these columns
- **THEN** all columns are added with `DEFAULT 0` without data loss
