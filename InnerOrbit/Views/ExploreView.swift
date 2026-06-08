import SwiftUI
import SwiftData

struct ExploreView: View {
    @Query(sort: \Habit.createdAt) private var habits: [Habit]
    @Query(sort: \GratitudeEntry.createdAt, order: .reverse) private var gratitudes: [GratitudeEntry]
    @Query(sort: \DayPhoto.createdAt, order: .reverse) private var photos: [DayPhoto]
    @Query(sort: \MoodEntry.date, order: .reverse) private var moods: [MoodEntry]

    @State private var searchText = ""
    @State private var filter: ExploreFilter = .all

    var body: some View {
        NavigationStack {
            ZStack {
                CosmicBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        OrbitCard {
                            VStack(alignment: .leading, spacing: 14) {
                                SectionHeader(title: "Explore History", subtitle: "Search keywords across past days and patterns.", systemImage: "magnifyingglass")

                                TextField("Search gratitude, mood notes, photo captions, or habit names", text: $searchText)
                                    .textFieldStyle(OrbitTextFieldStyle())

                                Picker("Filter", selection: $filter) {
                                    ForEach(ExploreFilter.allCases) { option in
                                        Text(option.rawValue).tag(option)
                                    }
                                }
                                .pickerStyle(.segmented)
                            }
                        }

                        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            OrbitCard {
                                Text("Start with a keyword like family, grateful, calm, stretch, walk, work, church, trip, health, or photo captions.")
                                    .foregroundStyle(OrbitTheme.textSecondary)
                            }
                        } else if filteredDays.isEmpty {
                            OrbitCard {
                                Text("No historic days matched that keyword.")
                                    .foregroundStyle(OrbitTheme.textSecondary)
                            }
                        } else {
                            ForEach(filteredDays) { day in
                                OrbitCard {
                                    VStack(alignment: .leading, spacing: 14) {
                                        SectionHeader(
                                            title: day.day.formatted(.dateTime.weekday(.wide).month().day().year()),
                                            subtitle: daySummary(for: day),
                                            systemImage: "calendar"
                                        )

                                        if !day.completedHabits.isEmpty {
                                            ExploreSectionLabel(title: "Completed Habits")
                                            WrapTagsView(tags: day.completedHabits.map(\.name))
                                        }

                                        if !day.gratitudes.isEmpty {
                                            ExploreSectionLabel(title: "Gratitudes")
                                            VStack(spacing: 8) {
                                                ForEach(day.gratitudes) { gratitude in
                                                    OrbitMiniCard {
                                                        Text(highlightedText(gratitude.text, keyword: searchText))
                                                            .foregroundStyle(OrbitTheme.textPrimary)
                                                    }
                                                }
                                            }
                                        }

                                        if !day.moods.isEmpty {
                                            ExploreSectionLabel(title: "Mood Notes")
                                            VStack(spacing: 8) {
                                                ForEach(day.moods) { mood in
                                                    OrbitMiniCard {
                                                        VStack(alignment: .leading, spacing: 6) {
                                                            Text("\(mood.mood.emoji) \(mood.mood.rawValue)")
                                                                .foregroundStyle(OrbitTheme.textPrimary)
                                                            if !mood.note.isEmpty {
                                                                Text(highlightedText(mood.note, keyword: searchText))
                                                                    .foregroundStyle(OrbitTheme.textSecondary)
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }

                                        if !day.photos.isEmpty {
                                            ExploreSectionLabel(title: "Photos")
                                            ScrollView(.horizontal, showsIndicators: false) {
                                                HStack(spacing: 12) {
                                                    ForEach(day.photos) { photo in
                                                        ExplorePhotoTile(photo: photo)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle("Explore")
        }
    }

    private var filteredDays: [ExploreDay] {
        let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !keyword.isEmpty else { return [] }

        let calendar = Calendar.current
        let allDates = Set(
            gratitudes.map { calendar.startOfDay(for: $0.createdAt) } +
            moods.map { calendar.startOfDay(for: $0.date) } +
            photos.map { calendar.startOfDay(for: $0.date) } +
            habits.flatMap { habit in habit.completions.map { calendar.startOfDay(for: $0.date) } }
        )

        let days = allDates.sorted(by: >).compactMap { day -> ExploreDay? in
            let dayGratitudes = gratitudes.filter { calendar.isDate($0.createdAt, inSameDayAs: day) }
            let dayMoods = moods.filter { calendar.isDate($0.date, inSameDayAs: day) }
            let dayPhotos = photos.filter { calendar.isDate($0.date, inSameDayAs: day) }
            let dayCompletedHabits = habits.filter { $0.isCompleted(on: day, calendar: calendar) }

            let matchesGratitudes = dayGratitudes.filter { $0.text.localizedCaseInsensitiveContains(keyword) }
            let matchesMoods = dayMoods.filter { $0.note.localizedCaseInsensitiveContains(keyword) || $0.mood.rawValue.localizedCaseInsensitiveContains(keyword) }
            let matchesPhotos = dayPhotos.filter { $0.caption.localizedCaseInsensitiveContains(keyword) }
            let matchesHabits = dayCompletedHabits.filter { $0.name.localizedCaseInsensitiveContains(keyword) || $0.detail.localizedCaseInsensitiveContains(keyword) }

            let matches: Bool = switch filter {
            case .all:
                !matchesGratitudes.isEmpty || !matchesMoods.isEmpty || !matchesPhotos.isEmpty || !matchesHabits.isEmpty
            case .gratitudes:
                !matchesGratitudes.isEmpty
            case .moods:
                !matchesMoods.isEmpty
            case .photos:
                !matchesPhotos.isEmpty
            case .habits:
                !matchesHabits.isEmpty
            }

            guard matches else { return nil }

            return ExploreDay(
                day: day,
                gratitudes: filter == .all || filter == .gratitudes ? (matchesGratitudes.isEmpty && filter == .all ? dayGratitudes : matchesGratitudes) : [],
                moods: filter == .all || filter == .moods ? (matchesMoods.isEmpty && filter == .all ? dayMoods : matchesMoods) : [],
                photos: filter == .all || filter == .photos ? (matchesPhotos.isEmpty && filter == .all ? dayPhotos : matchesPhotos) : [],
                completedHabits: filter == .all || filter == .habits ? (matchesHabits.isEmpty && filter == .all ? dayCompletedHabits : matchesHabits) : []
            )
        }

        return days
    }

    private func daySummary(for day: ExploreDay) -> String {
        let parts = [
            day.completedHabits.isEmpty ? nil : "\(day.completedHabits.count) habits",
            day.gratitudes.isEmpty ? nil : "\(day.gratitudes.count) gratitudes",
            day.moods.isEmpty ? nil : "\(day.moods.count) moods",
            day.photos.isEmpty ? nil : "\(day.photos.count) photos"
        ].compactMap { $0 }

        return parts.joined(separator: " \u{2022} ")
    }

    private func highlightedText(_ text: String, keyword: String) -> AttributedString {
        var attributed = AttributedString(text)
        let lower = text.lowercased()
        let key = keyword.lowercased()

        if let range = lower.range(of: key),
           let attributedRange = Range(range, in: attributed) {
            attributed[attributedRange].foregroundColor = UIColor.systemBlue
            attributed[attributedRange].font = .systemFont(ofSize: 17, weight: .semibold)
        }

        return attributed
    }
}
