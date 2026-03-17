## Why

The Dashboard (首页) currently hard-codes a 7-day window when loading stats. Users have no way to compare different periods (today vs. last month, 近14天 vs. 上月, etc.), which limits its usefulness as a monitoring tool. The backend `GET /stats` endpoint already accepts `start_date` / `end_date` params and `StatsService.overview()` already plumbs them through — the gap is entirely on the iOS side.

## What Changes

- **Extend `DateRangeFilter`** (currently in `AdsSummaryCardView.swift`) with four new cases: `last14Days`, `thisMonth`, `lastMonth`, `custom`, and move it to a shared `Models/` file so both Dashboard and Ads screens can use it.
- **Add `dateFilter` state to `DashboardViewModel`**, defaulting to `.last7Days`, and pass the derived date range to `StatsService.overview()`.
- **Add a date-filter chip** in `DashboardView` header (below the platform tabs) showing the active range label and date string (e.g. `近7天  03.10 – 03.16 ▾`).
- **Add `DashboardDatePickerSheet`** — a bottom sheet listing all preset options with date previews, plus a custom date range picker (two `DatePicker`s) and Confirm / Cancel buttons.

## Capabilities

### New Capabilities

- `dashboard-date-filter`: Dashboard date range selector with preset options and custom range

### Modified Capabilities

- `date-range-filter-shared`: `DateRangeFilter` enum extended and moved to shared location

## Impact

- **iOS only** — no backend changes needed.
- Touches: `AdsSummaryCardView.swift` (import new location), `DashboardView.swift` (ViewModel + UI), new file `DashboardDatePickerSheet.swift`, new file `Models/DateRangeFilter.swift`.
- The existing `DateRangeTabView` component in `AdsSummaryCardView.swift` continues to work unchanged; it just imports from the new shared location.
