import SwiftUI
import SwiftData
import Charts

// MARK: - Cosmic Background

struct CosmicBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [OrbitTheme.bgTop, OrbitTheme.bgBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [OrbitTheme.accent.opacity(0.20), .clear],
                center: .topTrailing,
                startRadius: 20,
                endRadius: 300
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [OrbitTheme.accent2.opacity(0.18), .clear],
                center: .bottomLeading,
                startRadius: 20,
                endRadius: 320
            )
            .ignoresSafeArea()

            StarFieldView()
                .allowsHitTesting(false)
        }
    }
}

struct StarFieldView: View {
    private let stars: [StarPoint] = (0..<45).map { _ in
        StarPoint(
            x: CGFloat.random(in: 0.02...0.98),
            y: CGFloat.random(in: 0.02...0.98),
            size: CGFloat.random(in: 1.0...2.6),
            opacity: Double.random(in: 0.18...0.7)
        )
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ForEach(stars) { star in
                    Circle()
                        .fill(Color.white.opacity(star.opacity))
                        .frame(width: star.size, height: star.size)
                        .position(x: star.x * proxy.size.width, y: star.y * proxy.size.height)
                }
            }
        }
        .ignoresSafeArea()
    }
}

struct StarPoint: Identifiable {
    let id = UUID()
    let x: CGFloat
    let y: CGFloat
    let size: CGFloat
    let opacity: Double
}

// MARK: - Cards

struct OrbitCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading) {
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThinMaterial.opacity(0.65))
                .overlay(
                    LinearGradient(
                        colors: [Color.white.opacity(0.06), Color.white.opacity(0.02)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(OrbitTheme.cardBorder, lineWidth: 1)
        )
        .shadow(color: OrbitTheme.cardGlow, radius: 16, x: 0, y: 10)
    }
}

struct OrbitMiniCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.05))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Hero Header

struct HeroHeaderCard: View {
    let completedToday: Int
    let totalHabits: Int
    let photoCount: Int

    var body: some View {
        OrbitCard {
            VStack(alignment: .leading, spacing: 14) {
                Text(Date.now.formatted(.dateTime.weekday(.wide).month().day()))
                    .font(.subheadline)
                    .foregroundStyle(OrbitTheme.textSecondary)

                Text("Build your inner orbit.")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(OrbitTheme.textPrimary)

                Text("Track habits, mood, gratitude, affirmations, and moments in one daily rhythm.")
                    .font(.subheadline)
                    .foregroundStyle(OrbitTheme.textSecondary)

                HStack(spacing: 10) {
                    MetricBubble(title: "Done", value: "\(completedToday)/\(max(totalHabits, 1))")
                    MetricBubble(title: "Photos", value: "\(photoCount)")
                    MetricBubble(title: "Focus", value: completedToday == totalHabits && totalHabits > 0 ? "Locked" : "Live")
                }
            }
        }
    }
}

struct MetricBubble: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.headline)
                .foregroundStyle(OrbitTheme.textPrimary)
            Text(title)
                .font(.caption)
                .foregroundStyle(OrbitTheme.textSecondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.07))
        .clipShape(Capsule())
    }
}

// MARK: - Section Headers & Labels

struct SectionHeader: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .foregroundStyle(OrbitTheme.textPrimary)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(OrbitTheme.textSecondary)
        }
    }
}

struct ExploreSectionLabel: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(OrbitTheme.textTertiary)
            .textCase(.uppercase)
    }
}

// MARK: - Chips & Tags

struct TagChip: View {
    let text: String

    var body: some View {
        Text("#\(text)")
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.08))
            .foregroundStyle(OrbitTheme.accent3)
            .clipShape(Capsule())
    }
}

struct MoodChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.title3)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(isSelected ? OrbitTheme.accent.opacity(0.24) : Color.white.opacity(0.05))
                .overlay(
                    Capsule().stroke(isSelected ? OrbitTheme.accent : Color.white.opacity(0.08), lineWidth: 1)
                )
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Empty State

struct EmptyOrbitState: View {
    let title: String
    let subtitle: String
    let buttonTitle: String
    let action: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.largeTitle)
                .foregroundStyle(OrbitTheme.accent)
            Text(title)
                .font(.headline)
                .foregroundStyle(OrbitTheme.textPrimary)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(OrbitTheme.textSecondary)
            Button(buttonTitle, action: action)
                .buttonStyle(PrimaryOrbitButtonStyle())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }
}

// MARK: - Habit Row

struct OrbitHabitRow: View {
    @Environment(\.modelContext) private var modelContext
    let habit: Habit

    var body: some View {
        HStack(spacing: 14) {
            Button(action: toggleToday) {
                ZStack {
                    Circle()
                        .fill(habit.isCompleted(on: .now) ? OrbitTheme.accent.opacity(0.22) : Color.white.opacity(0.06))
                        .frame(width: 42, height: 42)
                    Image(systemName: habit.isCompleted(on: .now) ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(habit.isCompleted(on: .now) ? OrbitTheme.accent : OrbitTheme.textSecondary)
                }
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                Text(habit.name)
                    .font(.headline)
                    .foregroundStyle(OrbitTheme.textPrimary)
                Text(habit.detail.isEmpty ? habit.frequency.rawValue : habit.detail)
                    .font(.subheadline)
                    .foregroundStyle(OrbitTheme.textSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("\(habit.currentStreak())")
                    .font(.headline)
                    .foregroundStyle(OrbitTheme.textPrimary)
                Text("streak")
                    .font(.caption)
                    .foregroundStyle(OrbitTheme.textSecondary)
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.05))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func toggleToday() {
        let calendar = Calendar.current
        if let existing = habit.completions.first(where: { calendar.isDate($0.date, inSameDayAs: .now) }) {
            modelContext.delete(existing)
        } else {
            let completion = HabitCompletion(date: .now)
            habit.completions.append(completion)
            modelContext.insert(completion)
        }
        try? modelContext.save()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}

// MARK: - Photo Tiles

struct OrbitPhotoTile: View {
    let photo: DayPhoto

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let image = UIImage(data: photo.imageData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 110)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }

            if !photo.caption.isEmpty {
                Text(photo.caption)
                    .font(.caption)
                    .foregroundStyle(OrbitTheme.textSecondary)
                    .lineLimit(1)
            } else {
                Text(photo.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(OrbitTheme.textSecondary)
            }
        }
    }
}

struct ExplorePhotoTile: View {
    let photo: DayPhoto

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let image = UIImage(data: photo.imageData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 120, height: 120)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }

            Text(photo.caption.isEmpty ? photo.date.formatted(date: .abbreviated, time: .omitted) : photo.caption)
                .font(.caption)
                .foregroundStyle(OrbitTheme.textSecondary)
                .lineLimit(1)
        }
        .frame(width: 120, alignment: .leading)
    }
}

// MARK: - KPI Grid

struct KPIGrid: View {
    let items: [(String, String)]

    var body: some View {
        HStack(spacing: 10) {
            ForEach(items.indices, id: \.self) { index in
                let item = items[index]
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.1)
                        .font(.headline)
                        .foregroundStyle(OrbitTheme.textPrimary)
                    Text(item.0)
                        .font(.caption)
                        .foregroundStyle(OrbitTheme.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
    }
}

// MARK: - Wrap Tags

struct WrapTagsView: View {
    let tags: [String]

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 8)], alignment: .leading, spacing: 8) {
            ForEach(tags, id: \.self) { tag in
                TagChip(text: tag)
            }
        }
    }
}

// MARK: - Charts

struct OverviewChart: View {
    let points: [DailyCountPoint]

    var body: some View {
        Chart(points) { point in
            BarMark(
                x: .value("Date", point.date, unit: .day),
                y: .value("Completions", point.count)
            )
            .foregroundStyle(LinearGradient(colors: [OrbitTheme.accent, OrbitTheme.accent3], startPoint: .top, endPoint: .bottom))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) }
        .chartYAxis { AxisMarks(position: .leading) }
        .chartPlotStyle { plotArea in
            plotArea.background(Color.white.opacity(0.03)).clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
}

struct HabitTrendChart: View {
    let points: [DailyCountPoint]

    var body: some View {
        Chart(points) { point in
            AreaMark(
                x: .value("Date", point.date, unit: .day),
                y: .value("Completed", point.count)
            )
            .foregroundStyle(LinearGradient(colors: [OrbitTheme.accent.opacity(0.45), .clear], startPoint: .top, endPoint: .bottom))

            LineMark(
                x: .value("Date", point.date, unit: .day),
                y: .value("Completed", point.count)
            )
            .foregroundStyle(OrbitTheme.accent)

            PointMark(
                x: .value("Date", point.date, unit: .day),
                y: .value("Completed", point.count)
            )
            .foregroundStyle(OrbitTheme.accent)
        }
        .chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) }
        .chartYAxis { AxisMarks(position: .leading) }
        .chartPlotStyle { plotArea in
            plotArea.background(Color.white.opacity(0.03)).clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
}

struct MoodTrendChart: View {
    let points: [MoodPoint]

    var body: some View {
        Chart(points) { point in
            LineMark(
                x: .value("Date", point.date, unit: .day),
                y: .value("Mood", point.score)
            )
            .foregroundStyle(OrbitTheme.accent2)

            PointMark(
                x: .value("Date", point.date, unit: .day),
                y: .value("Mood", point.score)
            )
            .foregroundStyle(OrbitTheme.accent2)
        }
        .chartYScale(domain: 1...5)
        .chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) }
        .chartYAxis { AxisMarks(position: .leading) }
        .chartPlotStyle { plotArea in
            plotArea.background(Color.white.opacity(0.03)).clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
}

struct GratitudeTagChart: View {
    let points: [TagCount]

    var body: some View {
        Chart(points) { point in
            BarMark(
                x: .value("Count", point.count),
                y: .value("Tag", point.tag)
            )
            .foregroundStyle(LinearGradient(colors: [OrbitTheme.accent2, OrbitTheme.accent], startPoint: .leading, endPoint: .trailing))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .chartXAxis { AxisMarks(position: .bottom) }
        .chartYAxis { AxisMarks(position: .leading) }
        .chartPlotStyle { plotArea in
            plotArea.background(Color.white.opacity(0.03)).clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
}

// MARK: - Button Styles

struct OrbitTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.06))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .foregroundStyle(OrbitTheme.textPrimary)
    }
}

struct PrimaryOrbitButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(
                    colors: [OrbitTheme.accent, OrbitTheme.accent2],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .opacity(configuration.isPressed ? 0.85 : 1)
            .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct SecondaryOrbitButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(OrbitTheme.textPrimary)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(Color.white.opacity(configuration.isPressed ? 0.08 : 0.05))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
