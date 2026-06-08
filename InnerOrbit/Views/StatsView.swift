import SwiftUI
import SwiftData
import Charts

struct StatsView: View {
    @Query(sort: \Habit.createdAt) private var habits: [Habit]
    @Query(sort: \MoodEntry.date) private var moods: [MoodEntry]
    @Query(sort: \GratitudeEntry.createdAt, order: .reverse) private var gratitudes: [GratitudeEntry]

    @State private var selectedMode: StatsMode = .overview
    @State private var selectedRange: TimeRange = .thirtyDays
    @State private var selectedHabitID: UUID?

    private var selectedHabit: Habit? {
        habits.first(where: { $0.id == selectedHabitID }) ?? habits.first
    }

    private var dateRange: ClosedRange<Date> {
        selectedRange.startDate()...Date.now
    }

    private var filteredGratitudes: [GratitudeEntry] {
        gratitudes.filter { dateRange.contains($0.createdAt) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                CosmicBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        OrbitCard {
                            VStack(spacing: 14) {
                                Picker("Mode", selection: $selectedMode) {
                                    ForEach(StatsMode.allCases) { mode in
                                        Text(mode.rawValue).tag(mode)
                                    }
                                }
                                .pickerStyle(.segmented)

                                Picker("Range", selection: $selectedRange) {
                                    ForEach(TimeRange.allCases) { range in
                                        Text(range.rawValue).tag(range)
                                    }
                                }
                                .pickerStyle(.segmented)
                            }
                        }

                        switch selectedMode {
                        case .overview:
                            OrbitCard {
                                VStack(alignment: .leading, spacing: 16) {
                                    SectionHeader(title: "All Habits", subtitle: "See your orbit over time.", systemImage: "chart.bar.xaxis")
                                    OverviewChart(points: overviewPoints)
                                        .frame(height: 220)

                                    KPIGrid(items: [
                                        ("Total", "\(overviewPoints.reduce(0) { $0 + $1.count })"),
                                        ("Habits", "\(habits.count)"),
                                        ("Avg/Day", averagePerDayText)
                                    ])
                                }
                            }

                        case .habit:
                            OrbitCard {
                                VStack(alignment: .leading, spacing: 16) {
                                    SectionHeader(title: "Specific Habit", subtitle: "Isolate one habit and inspect the trend.", systemImage: "scope")

                                    if habits.isEmpty {
                                        Text("Add a habit to unlock habit-specific charts.")
                                            .foregroundStyle(OrbitTheme.textSecondary)
                                    } else {
                                        Picker("Habit", selection: Binding(
                                            get: { selectedHabitID ?? habits.first?.id },
                                            set: { selectedHabitID = $0 }
                                        )) {
                                            ForEach(habits) { habit in
                                                Text(habit.name).tag(Optional(habit.id))
                                            }
                                        }
                                        .pickerStyle(.menu)

                                        if let selectedHabit {
                                            HabitTrendChart(points: habitPoints(for: selectedHabit))
                                                .frame(height: 220)

                                            KPIGrid(items: [
                                                ("Streak", "\(selectedHabit.currentStreak())"),
                                                ("Week", "\(selectedHabit.completionCount(in: .weekOfYear))"),
                                                ("Month", "\(selectedHabit.completionCount(in: .month))")
                                            ])
                                        }
                                    }
                                }
                            }

                        case .mood:
                            OrbitCard {
                                VStack(alignment: .leading, spacing: 16) {
                                    SectionHeader(title: "Mood Trend", subtitle: "Track emotional momentum over time.", systemImage: "waveform.path.ecg")
                                    MoodTrendChart(points: moodPoints)
                                        .frame(height: 220)

                                    KPIGrid(items: [
                                        ("Entries", "\(filteredMoods.count)"),
                                        ("Average", averageMoodText),
                                        ("Best", bestMoodText)
                                    ])
                                }
                            }

                        case .gratitude:
                            OrbitCard {
                                VStack(alignment: .leading, spacing: 16) {
                                    SectionHeader(title: "Gratitude Tags", subtitle: "Recurring themes across your gratitude entries.", systemImage: "tag")
                                    GratitudeTagChart(points: gratitudeTagCounts)
                                        .frame(height: 240)

                                    KPIGrid(items: [
                                        ("Entries", "\(filteredGratitudes.count)"),
                                        ("Unique Tags", "\(gratitudeTagCounts.count)"),
                                        ("Top Tag", gratitudeTagCounts.first?.tag.capitalized ?? "\u{2014}")
                                    ])
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle("Insights")
            .onAppear {
                if selectedHabitID == nil {
                    selectedHabitID = habits.first?.id
                }
            }
        }
    }

    private var overviewPoints: [DailyCountPoint] {
        let calendar = Calendar.current
        return generateDays(in: dateRange).map { day in
            DailyCountPoint(
                date: day,
                count: habits.reduce(0) { partial, habit in
                    partial + (habit.isCompleted(on: day, calendar: calendar) ? 1 : 0)
                }
            )
        }
    }

    private func habitPoints(for habit: Habit) -> [DailyCountPoint] {
        let calendar = Calendar.current
        return generateDays(in: dateRange).map { day in
            DailyCountPoint(date: day, count: habit.isCompleted(on: day, calendar: calendar) ? 1 : 0)
        }
    }

    private var filteredMoods: [MoodEntry] {
        moods.filter { dateRange.contains($0.date) }
    }

    private var moodPoints: [MoodPoint] {
        filteredMoods
            .sorted { $0.date < $1.date }
            .map { MoodPoint(date: $0.date, score: $0.mood.score) }
    }

    private var gratitudeTagCounts: [TagCount] {
        let tags = filteredGratitudes.flatMap(\.tags)
        let counts = Dictionary(grouping: tags, by: { $0 }).mapValues(\.count)
        return counts
            .map { TagCount(tag: $0.key, count: $0.value) }
            .sorted { lhs, rhs in
                if lhs.count == rhs.count { return lhs.tag < rhs.tag }
                return lhs.count > rhs.count
            }
            .prefix(8)
            .map { $0 }
    }

    private var averageMoodText: String {
        guard !filteredMoods.isEmpty else { return "\u{2014}" }
        let avg = Double(filteredMoods.map { $0.mood.score }.reduce(0, +)) / Double(filteredMoods.count)
        return String(format: "%.1f/5", avg)
    }

    private var bestMoodText: String {
        filteredMoods.max(by: { $0.mood.score < $1.mood.score })?.mood.rawValue ?? "\u{2014}"
    }

    private var averagePerDayText: String {
        guard !overviewPoints.isEmpty else { return "0.0" }
        let avg = Double(overviewPoints.reduce(0) { $0 + $1.count }) / Double(overviewPoints.count)
        return String(format: "%.1f", avg)
    }

    private func generateDays(in range: ClosedRange<Date>) -> [Date] {
        let calendar = Calendar.current
        var values: [Date] = []
        var current = calendar.startOfDay(for: range.lowerBound)
        let end = calendar.startOfDay(for: range.upperBound)

        while current <= end {
            values.append(current)
            current = calendar.date(byAdding: .day, value: 1, to: current) ?? end.addingTimeInterval(1)
        }

        return values
    }
}
