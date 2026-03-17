## ADDED Requirements

### Requirement: DashboardViewModel holds a dateFilter state
`DashboardViewModel` SHALL expose `@Published var dateFilter: DateRangeFilter` defaulting to `.last7Days`. Changing `dateFilter` SHALL trigger a data reload via `didSet`.

#### Scenario: Default date filter is last 7 days
- **WHEN** `DashboardViewModel` is initialised
- **THEN** `dateFilter` equals `.last7Days` and the initial load uses the corresponding date range

#### Scenario: Changing dateFilter reloads stats
- **WHEN** `vm.dateFilter` is set to `.thisMonth`
- **THEN** `load()` is called automatically and the API request uses the month-to-date range

### Requirement: Dashboard header shows an active date-range chip
`DashboardView` SHALL display a tappable chip between the platform filter tabs and the stats grid showing `"\(dateFilter.label)  \(dateFilter.subtitle)"` and a chevron-down icon.

#### Scenario: Chip displays current filter label and dates
- **WHEN** `dateFilter` is `.last7Days` and today is 2026-03-17
- **THEN** the chip reads `"近7天  03.11 – 03.17"`

#### Scenario: Tapping chip opens the date picker sheet
- **WHEN** the user taps the date chip
- **THEN** `DashboardDatePickerSheet` is presented as a sheet

### Requirement: DashboardDatePickerSheet lists all preset options
The sheet SHALL show a scrollable list of all eight `DateRangeFilter` cases. Each row displays: the case `label` (bold), the case `subtitle` (secondary colour), and a checkmark on the currently selected case.

#### Scenario: Currently active filter is highlighted
- **WHEN** the sheet opens with `dateFilter == .last7Days`
- **THEN** the `"近7天"` row shows a checkmark and is visually distinct from others

#### Scenario: Tapping a preset row selects it and dismisses
- **WHEN** the user taps the `"近30天"` row
- **THEN** `dateFilter` updates to `.last30Days` and the sheet dismisses

### Requirement: Custom date range supports arbitrary start and end dates
When the `"自定义"` row is selected in the sheet, two `DatePicker` controls SHALL appear (start date and end date). The user MUST tap "确认" to commit the custom range.

#### Scenario: Custom row reveals date pickers
- **WHEN** the user taps the `"自定义"` row
- **THEN** start-date and end-date `DatePicker` controls expand inline; the sheet does not yet dismiss

#### Scenario: Confirm commits custom range
- **WHEN** start date = 2026-03-01, end date = 2026-03-10, and user taps "确认"
- **THEN** `dateFilter` is set to `.custom(from: 2026-03-01, to: 2026-03-10)` and the sheet dismisses

#### Scenario: End date cannot precede start date
- **WHEN** the user sets end date earlier than start date in the custom picker
- **THEN** the "确认" button is disabled

### Requirement: Stats API call includes the resolved date range
`StatsService.overview()` SHALL be called with `startDate` and `endDate` derived from `vm.dateFilter.dateRange` on every load and refresh.

#### Scenario: Date params match the active filter
- **WHEN** `dateFilter == .thisMonth` and today is 2026-03-17
- **THEN** the request to `GET /api/v1/stats` includes `start_date=2026-03-01&end_date=2026-03-17`
