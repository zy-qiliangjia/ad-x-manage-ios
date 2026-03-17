## 1. Shared DateRangeFilter Model

- [x] 1.1 Create `ios/AdXManage/AdXManage/Models/DateRangeFilter.swift` with all 8 cases: `today`, `yesterday`, `last7Days`, `last14Days`, `last30Days`, `thisMonth`, `lastMonth`, `custom(from: Date, to: Date)`
- [x] 1.2 Implement `label: String` on each case (e.g. `"近7天"`, `"近14天"`, `"本月"`, `"上月"`, `"自定义"`)
- [x] 1.3 Implement `subtitle: String` returning the formatted date span `"MM.dd – MM.dd"` for each case; for `custom` use the associated dates
- [x] 1.4 Implement `dateRange: (from: String, to: String)` returning `"yyyy-MM-dd"` strings for each case; for `thisMonth` use first day of current month through today; for `lastMonth` use full previous month; for `custom` use associated dates
- [x] 1.5 Remove the `DateRangeFilter` enum and `DateRangeTabView` struct declarations from `AdsSummaryCardView.swift` (they are now in the shared file, same module — no import needed)

## 2. DashboardViewModel Date Filter Integration

- [x] 2.1 Add `@Published var dateFilter: DateRangeFilter = .last7Days { didSet { Task { await load() } } }` to `DashboardViewModel`
- [x] 2.2 Update `DashboardViewModel.load()` to call `service.overview(platform: platformFilter?.rawValue, startDate: dateFilter.dateRange.from, endDate: dateFilter.dateRange.to)` instead of the current no-date call
- [x] 2.3 Confirm `refresh()` (pull-to-refresh) also passes the date range — it calls `load()` so it inherits the fix automatically

## 3. Dashboard Header — Date Chip Button

- [x] 3.1 Add `@State private var showDatePicker = false` to `DashboardView`
- [x] 3.2 Add the date chip button in the header section of `DashboardView`, positioned below the platform filter tabs: display `"\(vm.dateFilter.label)  \(vm.dateFilter.subtitle)"` with a `chevron.down` trailing icon, styled as a pill button with the theme's surface background and primary text
- [x] 3.3 Wire the chip button to set `showDatePicker = true`
- [x] 3.4 Add `.sheet(isPresented: $showDatePicker)` on `DashboardView` body presenting `DashboardDatePickerSheet(dateFilter: $vm.dateFilter)`

## 4. DashboardDatePickerSheet

- [x] 4.1 Create `ios/AdXManage/AdXManage/Features/Dashboard/DashboardDatePickerSheet.swift`
- [x] 4.2 Define the view with `@Binding var dateFilter: DateRangeFilter` and local state: `@State private var pendingPreset: DateRangeFilter`, `@State private var customFrom: Date`, `@State private var customTo: Date`, `@Environment(\.dismiss) private var dismiss`
- [x] 4.3 On appear, initialise `pendingPreset` to the current `dateFilter`; if `dateFilter` is `.custom(from:to:)` extract the dates into `customFrom` / `customTo`
- [x] 4.4 Build the preset list: for each case in the ordered array `[.today, .yesterday, .last7Days, .last14Days, .last30Days, .thisMonth, .lastMonth, .custom(...)]`, render a row with `label` (bold, primary), `subtitle` (secondary), and a `checkmark` if it matches `pendingPreset`
- [x] 4.5 When a non-custom row is tapped: set `pendingPreset` to that case, update `dateFilter` to that case, and call `dismiss()`
- [x] 4.6 When the custom row is tapped: set `pendingPreset = .custom(from: customFrom, to: customTo)` and show the inline date pickers (toggle `@State var showCustomPickers = true`)
- [x] 4.7 Inline custom date pickers: two `DatePicker` controls (label "开始日期" and "结束日期", `displayedComponents: .date`) bound to `customFrom` and `customTo`, visible only when `showCustomPickers == true`
- [x] 4.8 Add "确认" button (disabled when `customTo < customFrom`): sets `dateFilter = .custom(from: customFrom, to: customTo)` and calls `dismiss()`
- [x] 4.9 Add "取消" button: calls `dismiss()` without changing `dateFilter`
- [x] 4.10 Style the sheet with a drag indicator, a title "选择时间", and consistent `AppTheme` colours

## 5. Validation

- [ ] 5.1 Launch the app and confirm the header chip shows "近7天  MM.dd – MM.dd" by default
- [ ] 5.2 Tap the chip — confirm the sheet opens with the correct rows and "近7天" checked
- [ ] 5.3 Select "本月" — confirm the chip updates and a new API call fires with `start_date=YYYY-03-01`
- [ ] 5.4 Select "自定义", pick custom dates, tap "确认" — confirm chip updates to the custom range
- [ ] 5.5 Confirm "确认" is disabled when end date < start date in custom mode
- [ ] 5.6 Confirm pull-to-refresh respects the current date filter (stats reload with same range)
