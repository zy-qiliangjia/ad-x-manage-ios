## ADDED Requirements

### Requirement: Advertiser list item carries budget fields
`AdvertiserListItem` SHALL include `spend: Double`, `budget: Double`, `budgetMode: String` fields decoded from the API response. When the backend omits these fields, they MUST default to `0.0`, `0.0`, and `""` respectively.

#### Scenario: Fields present in response
- **WHEN** the advertisers list API returns `spend`, `budget`, `budget_mode` for an item
- **THEN** `AdvertiserListItem` decodes them correctly and the account card displays the values

#### Scenario: Fields absent in response
- **WHEN** the advertisers list API omits budget fields (legacy backend)
- **THEN** `AdvertiserListItem` uses default values and the card shows "不限" / "--" without crashing

### Requirement: Account card shows budget and spend metrics
The `AdsAccountCardView` SHALL display a spend metric cell and a budget metric cell consistent with `CampaignManageCard` styling.

#### Scenario: Budget is finite
- **WHEN** `budgetMode` is `BUDGET_MODE_DAY` and `budget > 0`
- **THEN** the card shows "¥{Int(budget)}" in the budget cell

#### Scenario: Budget is unlimited
- **WHEN** `budgetMode` is `BUDGET_MODE_INFINITE` or `budget == 0`
- **THEN** the card shows "不限" in the budget cell

### Requirement: User can edit advertiser budget
The iOS client SHALL present `BudgetEditSheet` when the user taps "调整预算" on an account card. On confirmation, the client MUST call `PATCH /advertisers/:id/budget` with `{ "budget": <value> }` and refresh the item's local state.

#### Scenario: Successful budget update
- **WHEN** user submits a valid budget amount in the sheet
- **THEN** `PATCH /advertisers/:id/budget` is called, the sheet dismisses, and the card reflects the new budget

#### Scenario: API failure
- **WHEN** the budget update API returns an error
- **THEN** an alert is shown with the error message and the card retains its previous budget value
