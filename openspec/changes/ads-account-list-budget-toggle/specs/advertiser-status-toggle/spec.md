## ADDED Requirements

### Requirement: Account card shows status toggle
The `AdsAccountCardView` SHALL display a `Toggle` switch reflecting the advertiser's active state, consistent with `CampaignManageCard` styling.

#### Scenario: Active advertiser
- **WHEN** `advertiser.isActive == true`
- **THEN** the toggle is rendered in the ON position (green tint)

#### Scenario: Inactive advertiser
- **WHEN** `advertiser.isActive == false`
- **THEN** the toggle is rendered in the OFF position

### Requirement: Toggle requires confirmation before applying
Tapping the toggle on an account card MUST show a `confirmationDialog` (title: "确认暂停账号？" or "确认开启账号？") before calling the API. The toggle SHALL NOT change state until confirmed.

#### Scenario: User confirms toggle
- **WHEN** user taps the toggle and confirms in the dialog
- **THEN** `PATCH /advertisers/:id/status` is called with `{ "action": "pause" | "enable" }`, and the card updates to reflect the new status

#### Scenario: User cancels toggle
- **WHEN** user taps the toggle and cancels the dialog
- **THEN** no API call is made and the toggle remains at its original position

### Requirement: Loading indicator during status update
While the status update API call is in-flight, the account card MUST replace the toggle with a `ProgressView` for that specific item, identified by `updatingStatusID`.

#### Scenario: In-flight status update
- **WHEN** a status update is in progress for advertiser ID X
- **THEN** only the card for advertiser X shows a spinner; other cards remain interactive

### Requirement: Backend status update endpoint
`PATCH /advertisers/:id/status` SHALL accept `{ "action": "enable" | "pause" }` and update the advertiser's `status` field (1 = active, 0 = inactive). It MUST log the operation to `operation_logs`.

#### Scenario: Enable action
- **WHEN** action is "enable"
- **THEN** advertiser status is set to 1 and an operation log entry is created

#### Scenario: Pause action
- **WHEN** action is "pause"
- **THEN** advertiser status is set to 0 and an operation log entry is created
