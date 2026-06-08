import SwiftUI
import Charts

struct HabitDetailView: View {
    let habit: Habit
    @State private var selectedRange: TimeRange = .thirtyDays

    var body: some View {
        ZStack {
            CosmicBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    OrbitCard {
                        VStack(alignment: .leading, spacing: 16) {
                            SectionHeader(
                                title: habit.name,
                                subtitle: habit.detail.isEmpty ? habit.frequency.rawValue : habit.detail,
                                systemImage: "scope"
                            )

                            HabitTrendChart(points: points)
                                .frame(height: 220)

                            Picker("Range", selection: $selectedRange) {
                                ForEach(TimeRange.allCases) { range in
                                    Text(range.rawValue).tag(range)
                                }
                            }
                            .pickerStyle(.segmented)

                            KPIGrid(items: [
                                ("Streak", "\(habit.currentStreak())"),
                                ("Week", "\(habit.completionCount(in: .weekOfYear))"),
                                ("Month", "\(habit.completionCount(in: .month))")
                            ])
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
        }
        .navigationTitle(habit.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var points: [DailyCountPoint] {
        let range = selectedRange.startDate()...Date.now
        let calendar = Calendar.current
        var values: [DailyCountPoint] = []
        var current = calendar.startOfDay(for: range.lowerBound)
        let end = calendar.startOfDay(for: range.upperBound)

        while current <= end {
            values.append(DailyCountPoint(date: current, count: habit.isCompleted(on: current, calendar: calendar) ? 1 : 0))
            current = calendar.date(byAdding: .day, value: 1, to: current) ?? end.addingTimeInterval(1)
        }

        return values
    }
}
