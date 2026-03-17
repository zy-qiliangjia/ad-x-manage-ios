## ADDED Requirements

### Requirement: DateRangeFilter enum has eight preset cases plus custom
`DateRangeFilter` SHALL be defined in `Models/DateRangeFilter.swift` and provide the following cases: `today`, `yesterday`, `last7Days`, `last14Days`, `last30Days`, `thisMonth`, `lastMonth`, `custom(from: Date, to: Date)`.

#### Scenario: Each preset case computes its own date range
- **WHEN** `dateRange` is accessed on any preset case
- **THEN** it returns a `(from: String, to: String)` tuple in `"yyyy-MM-dd"` format matching the case semantics (e.g. `last14Days` returns 14 days ending today)

#### Scenario: Custom case computes range from associated dates
- **WHEN** `dateRange` is accessed on `.custom(from: d1, to: d2)`
- **THEN** it returns `(from: "yyyy-MM-dd" string of d1, to: "yyyy-MM-dd" string of d2)`

### Requirement: DateRangeFilter provides a human-readable display label
Each case SHALL expose a `label: String` property returning a localised Chinese short name (e.g. `"近7天"`, `"本月"`, `"自定义"`).

#### Scenario: Label for preset cases
- **WHEN** `label` is read on `.last14Days`
- **THEN** it returns `"近14天"`

#### Scenario: Label for custom case
- **WHEN** `label` is read on `.custom(...)`
- **THEN** it returns `"自定义"`

### Requirement: DateRangeFilter provides a formatted date-range subtitle
Each case SHALL expose a `subtitle: String` property showing the concrete date span (e.g. `"03.10 – 03.16"`) for display in the picker list and the header chip.

#### Scenario: Subtitle reflects resolved dates
- **WHEN** `subtitle` is accessed on `.last7Days` on 2026-03-17
- **THEN** it returns `"03.11 – 03.17"` (6 days back through today)

#### Scenario: Custom subtitle reflects chosen dates
- **WHEN** `subtitle` is accessed on `.custom(from: 2026-03-01, to: 2026-03-10)`
- **THEN** it returns `"03.01 – 03.10"`

### Requirement: AdsSummaryCardView continues to compile after the enum is moved
The `DateRangeFilter` and `DateRangeTabView` declarations SHALL be removed from `AdsSummaryCardView.swift`; the view SHALL still build and function identically since both files are in the same module.

#### Scenario: No duplicate definition
- **WHEN** the project compiles
- **THEN** there is exactly one definition of `DateRangeFilter` in the codebase
