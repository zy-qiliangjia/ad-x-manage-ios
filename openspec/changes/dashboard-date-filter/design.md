## Context

Current state:
- `DashboardViewModel.load()` calls `StatsService.overview(platform:)` with no date args, relying on the service's 7-day default.
- `DateRangeFilter` enum (4 cases: today, yesterday, last7Days, last30Days) lives inside `AdsSummaryCardView.swift`. It is already used by the Ads summary card with a `DateRangeTabView` strip.
- `StatsService.overview(platform:startDate:endDate:)` already accepts date strings — no service changes needed.
- The backend `GET /api/v1/stats` handler already handles `start_date` / `end_date` — no backend changes needed.

## Goals / Non-Goals

**Goals:**
- Let Dashboard users pick any of 8 preset date ranges or a custom range
- Show the active range in a compact chip in the header
- Reload stats whenever the date range or platform filter changes

**Non-Goals:**
- Wiring the chart to real data (separate concern, tracked elsewhere)
- Adding date filtering to the Ads tab's DimensionTabRow views (already uses DateRangeTabView strip)
- Any backend changes

## Decisions

**Decision: Extend `DateRangeFilter` and move to `Models/DateRangeFilter.swift`**
The enum is already shared-adjacent (used in Ads). Adding 4 cases and moving it to `Models/` avoids duplication and lets both Dashboard and Ads import one canonical definition. `AdsSummaryCardView.swift` just removes the local definition and imports nothing extra (same module).

New cases: `last14Days`, `thisMonth`, `lastMonth`, `custom(from: Date, to: Date)`.

`custom` carries associated `Date` values so the picker can preview the formatted range inline. `dateRange` computed property on `custom` derives `(from, to)` from the associated values.

**Decision: Bottom sheet picker, not inline tab strip**
The 8 options + custom date pickers don't fit a horizontal strip. A `sheet` with a `List`-style option picker matches the reference design and is idiomatic SwiftUI.

**Decision: `@State var dateFilter: DateRangeFilter` lives in `DashboardViewModel`, not the View**
Keeping it in the VM means `load()` / `refresh()` always see the current filter, and the `didSet` observer triggers a reload automatically — consistent with how `platformFilter` works.

**Decision: Custom range uses two `DatePicker` controls in the sheet**
The reference image shows "选择起止日期" for the custom option. Two `DatePicker(.graphical)` or `.compact` pickers (start / end) inside the sheet body, shown only when the "自定义" row is selected, then committed on "确认".

## Risks / Trade-offs

- [Risk] `DateRangeFilter.custom` breaks `CaseIterable` (associated values can't be iterated). → Mitigation: Drop `CaseIterable` conformance; replace any `allCases` usage in `DateRangeTabView` with an explicit ordered array of presets. `DateRangeTabView` only shows 4 fixed cases anyway so this is a non-issue.
- [Trade-off] Moving `DateRangeFilter` changes the file where it's defined; `AdsSummaryCardView.swift` must delete the old declaration. → Low risk since it's the only definition.

## Migration Plan

1. Create `Models/DateRangeFilter.swift` with the extended enum (8 cases including `custom`).
2. Delete the `DateRangeFilter` + `DateRangeTabView` declarations from `AdsSummaryCardView.swift` (they're still in the same module so no import needed).
3. Add `dateFilter` to `DashboardViewModel`; wire `load()` to use `dateFilter.dateRange`.
4. Update `DashboardView` header: add the date chip button + sheet presentation.
5. Create `DashboardDatePickerSheet.swift`.

## Open Questions

None — the reference images fully specify the UI.
