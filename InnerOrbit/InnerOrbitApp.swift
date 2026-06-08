import SwiftUI
import SwiftData
import PhotosUI
import Charts
import UIKit
import UserNotifications

// MARK: - Theme

enum OrbitTheme {
    static let bgTop = Color(red: 0.02, green: 0.05, blue: 0.13)
    static let bgBottom = Color(red: 0.01, green: 0.01, blue: 0.05)
    static let card = Color.white.opacity(0.07)
    static let cardBorder = Color.white.opacity(0.12)
    static let cardGlow = Color(red: 0.44, green: 0.63, blue: 1.0).opacity(0.16)
    static let accent = Color(red: 0.43, green: 0.66, blue: 1.0)
    static let accent2 = Color(red: 0.56, green: 0.42, blue: 0.96)
    static let accent3 = Color(red: 0.34, green: 0.83, blue: 0.88)
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.72)
    static let textTertiary = Color.white.opacity(0.46)
}

// MARK: - Models

enum HabitFrequency: String, Codable, CaseIterable, Identifiable {
    case daily = "Daily"
    case weekly = "Weekly"
    case monthly = "Monthly"
    case yearly = "Yearly"

    var id: String { rawValue }
}

enum TimeRange: String, CaseIterable, Identifiable {
    case sevenDays = "7D"
    case thirtyDays = "30D"
    case ninetyDays = "90D"
    case year = "1Y"
    case all = "All"

    var id: String { rawValue }

    func startDate(from now: Date = .now, calendar: Calendar = .current) -> Date {
        switch self {
        case .sevenDays:
            return calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: now)) ?? now
        case .thirtyDays:
            return calendar.date(byAdding: .day, value: -29, to: calendar.startOfDay(for: now)) ?? now
        case .ninetyDays:
            return calendar.date(byAdding: .day, value: -89, to: calendar.startOfDay(for: now)) ?? now
        case .year:
            return calendar.date(byAdding: .year, value: -1, to: calendar.startOfDay(for: now)) ?? now
        case .all:
            return .distantPast
        }
    }
}

enum MoodType: String, Codable, CaseIterable, Identifiable {
    case low = "Low"
    case okay = "Okay"
    case good = "Good"
    case great = "Great"
    case stellar = "Stellar"

    var id: String { rawValue }

    var score: Int {
        switch self {
        case .low: return 1
        case .okay: return 2
        case .good: return 3
        case .great: return 4
        case .stellar: return 5
        }
    }

    var emoji: String {
        switch self {
        case .low: return "🌑"
        case .okay: return "🌒"
        case .good: return "🌓"
        case .great: return "🌔"
        case .stellar: return "🌕"
        }
    }
}

@Model
final class Habit {
    var id: UUID
    var name: String
    var detail: String
    var frequencyRaw: String
    var reminderEnabled: Bool = false
    var reminderHour: Int = 8
    var reminderMinute: Int = 0
    var createdAt: Date
    @Relationship(deleteRule: .cascade) var completions: [HabitCompletion]

    init(
        id: UUID = UUID(),
        name: String,
        detail: String = "",
        frequency: HabitFrequency = .daily,
        reminderEnabled: Bool = false,
        reminderHour: Int = 8,
        reminderMinute: Int = 0,
        createdAt: Date = .now,
        completions: [HabitCompletion] = []
    ) {
        self.id = id
        self.name = name
        self.detail = detail
        self.frequencyRaw = frequency.rawValue
        self.reminderEnabled = reminderEnabled
        self.reminderHour = reminderHour
        self.reminderMinute = reminderMinute
        self.createdAt = createdAt
        self.completions = completions
    }

    var frequency: HabitFrequency {
        get { HabitFrequency(rawValue: frequencyRaw) ?? .daily }
        set { frequencyRaw = newValue.rawValue }
    }

    func isCompleted(on date: Date, calendar: Calendar = .current) -> Bool {
        completions.contains { calendar.isDate($0.date, inSameDayAs: date) }
    }

    func currentStreak(calendar: Calendar = .current) -> Int {
        var streak = 0
        var day = calendar.startOfDay(for: .now)

        while isCompleted(on: day, calendar: calendar) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }

        return streak
    }

    func completionCount(in component: Calendar.Component, for date: Date = .now, calendar: Calendar = .current) -> Int {
        completions.filter {
            switch component {
            case .weekOfYear:
                return calendar.isDate($0.date, equalTo: date, toGranularity: .weekOfYear)
            case .month:
                return calendar.isDate($0.date, equalTo: date, toGranularity: .month)
            case .year:
                return calendar.isDate($0.date, equalTo: date, toGranularity: .year)
            default:
                return calendar.isDate($0.date, inSameDayAs: date)
            }
        }.count
    }

    var reminderDate: Date {
        get {
            Calendar.current.date(bySettingHour: reminderHour, minute: reminderMinute, second: 0, of: .now) ?? .now
        }
        set {
            let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
            reminderHour = components.hour ?? 8
            reminderMinute = components.minute ?? 0
        }
    }

    var reminderSummary: String {
        reminderEnabled
            ? "\(frequency.rawValue) at \(reminderDate.formatted(date: .omitted, time: .shortened))"
            : "No reminder set"
    }
}

@Model
final class HabitCompletion {
    var id: UUID
    var date: Date

    init(id: UUID = UUID(), date: Date = .now) {
        self.id = id
        self.date = date
    }
}

@Model
final class GratitudeEntry {
    var id: UUID
    var text: String
    var createdAt: Date

    init(id: UUID = UUID(), text: String, createdAt: Date = .now) {
        self.id = id
        self.text = text
        self.createdAt = createdAt
    }

    var tags: [String] {
        GratitudeTagger.extractTags(from: text)
    }
}

@Model
final class DayPhoto {
    var id: UUID
    var date: Date
    var imageData: Data
    var caption: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        date: Date = .now,
        imageData: Data,
        caption: String = "",
        createdAt: Date = .now
    ) {
        self.id = id
        self.date = date
        self.imageData = imageData
        self.caption = caption
        self.createdAt = createdAt
    }
}

@Model
final class MoodEntry {
    var id: UUID
    var date: Date
    var moodRaw: String
    var note: String

    init(id: UUID = UUID(), date: Date = .now, mood: MoodType, note: String = "") {
        self.id = id
        self.date = date
        self.moodRaw = mood.rawValue
        self.note = note
    }

    var mood: MoodType {
        get { MoodType(rawValue: moodRaw) ?? .good }
        set { moodRaw = newValue.rawValue }
    }
}

@Model
final class AffirmationEntry {
    var id: UUID
    var text: String
    var createdAt: Date
    var isFavorite: Bool

    init(id: UUID = UUID(), text: String, createdAt: Date = .now, isFavorite: Bool = false) {
        self.id = id
        self.text = text
        self.createdAt = createdAt
        self.isFavorite = isFavorite
    }
}

@Model
final class WakeEntry {
    var id: UUID
    var date: Date
    var wakeTime: Date

    init(id: UUID = UUID(), date: Date = .now, wakeTime: Date) {
        self.id = id
        self.date = date
        self.wakeTime = wakeTime
    }

    var minutesAfterMidnight: Double {
        let components = Calendar.current.dateComponents([.hour, .minute], from: wakeTime)
        return Double((components.hour ?? 0) * 60 + (components.minute ?? 0))
    }
}

// MARK: - Support Types

struct DailyCountPoint: Identifiable {
    let id = UUID()
    let date: Date
    let count: Int
}

struct MoodPoint: Identifiable {
    let id = UUID()
    let date: Date
    let score: Int
}

struct WakePoint: Identifiable {
    let id = UUID()
    let date: Date
    let minutesAfterMidnight: Double
}

struct TagCount: Identifiable {
    let id = UUID()
    let tag: String
    let count: Int
}

enum StatsMode: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case habit = "Habit"
    case mood = "Mood"
    case gratitude = "Gratitudes"
    case wake = "Wake"

    var id: String { rawValue }
}

enum ExploreFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case gratitudes = "Gratitudes"
    case moods = "Moods"
    case photos = "Photos"
    case habits = "Habits"

    var id: String { rawValue }
}

struct ExploreDay: Identifiable {
    let id = UUID()
    let day: Date
    let gratitudes: [GratitudeEntry]
    let moods: [MoodEntry]
    let photos: [DayPhoto]
    let completedHabits: [Habit]
}

enum GratitudeTagger {
    static let stopWords: Set<String> = [
        "the", "and", "for", "that", "with", "this", "from", "have", "today", "about", "into",
        "your", "their", "there", "been", "were", "what", "when", "where", "which", "while",
        "because", "just", "very", "really", "then", "than", "them", "they", "will", "would",
        "could", "should", "being", "having", "after", "before", "under", "over", "through",
        "still", "such", "more", "most", "some", "much", "only", "also", "like", "love",
        "feel", "felt", "made", "make", "makes", "good", "great"
    ]

    static func extractTags(from text: String) -> [String] {
        let lowered = text.lowercased()
        let cleaned = lowered.replacingOccurrences(of: "[^a-z0-9 ]", with: " ", options: .regularExpression)
        let words = cleaned
            .split(separator: " ")
            .map(String.init)
            .filter { $0.count >= 3 && !stopWords.contains($0) }

        return Array(Set(words)).sorted()
    }
}

// MARK: - Notifications

@MainActor
enum HabitReminderScheduler {
    static func schedule(for habit: Habit) async {
        guard habit.reminderEnabled else {
            cancel(for: habit)
            return
        }

        do {
            let center = UNUserNotificationCenter.current()
            let settings = await center.notificationSettings()
            let allowed: Bool

            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                allowed = true
            case .notDetermined:
                allowed = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            case .denied:
                allowed = false
            @unknown default:
                allowed = false
            }

            guard allowed else { return }
            cancel(for: habit)

            let content = UNMutableNotificationContent()
            content.title = "Inner Orbit"
            content.body = "Time for \(habit.name)."
            content.sound = .default

            var components = DateComponents()
            components.hour = habit.reminderHour
            components.minute = habit.reminderMinute
            let calendar = Calendar.current

            switch habit.frequency {
            case .daily:
                break
            case .weekly:
                components.weekday = calendar.component(.weekday, from: .now)
            case .monthly:
                components.day = calendar.component(.day, from: .now)
            case .yearly:
                components.month = calendar.component(.month, from: .now)
                components.day = calendar.component(.day, from: .now)
            }

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let request = UNNotificationRequest(identifier: identifier(for: habit), content: content, trigger: trigger)
            try await center.add(request)
        } catch {
            print("Unable to schedule habit reminder: \(error)")
        }
    }

    static func cancel(for habit: Habit) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier(for: habit)])
    }

    private static func identifier(for habit: Habit) -> String {
        "habit-reminder-\(habit.id.uuidString)"
    }
}

// MARK: - App Entry

@main
struct InnerOrbitApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Habit.self,
            HabitCompletion.self,
            GratitudeEntry.self,
            DayPhoto.self,
            MoodEntry.self,
            AffirmationEntry.self,
            WakeEntry.self
        ])

        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            print("Could not open persistent ModelContainer: \(error)")

            do {
                let fallbackConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                return try ModelContainer(for: schema, configurations: [fallbackConfiguration])
            } catch {
                fatalError("Could not create fallback ModelContainer: \(error)")
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
        }
        .modelContainer(sharedModelContainer)
    }
}

// MARK: - Root

struct RootView: View {
    var body: some View {
        TabView {
            TodayView()
                .tabItem {
                    Label("Today", systemImage: "sparkles")
                }

            StatsView()
                .tabItem {
                    Label("Insights", systemImage: "chart.xyaxis.line")
                }

            ExploreView()
                .tabItem {
                    Label("Explore", systemImage: "magnifyingglass")
                }

            LibraryView()
                .tabItem {
                    Label("Library", systemImage: "square.grid.2x2")
                }
        }
        .tint(OrbitTheme.accent)
    }
}

// MARK: - Today

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Habit.createdAt) private var habits: [Habit]
    @Query(sort: \GratitudeEntry.createdAt, order: .reverse) private var gratitudes: [GratitudeEntry]
    @Query(sort: \DayPhoto.createdAt, order: .reverse) private var photos: [DayPhoto]
    @Query(sort: \MoodEntry.date, order: .reverse) private var moods: [MoodEntry]
    @Query(sort: \AffirmationEntry.createdAt, order: .reverse) private var affirmations: [AffirmationEntry]
    @Query(sort: \WakeEntry.date, order: .reverse) private var wakeEntries: [WakeEntry]

    @State private var showAddHabit = false
    @State private var gratitudeText = ""
    @State private var selectedMood: MoodType = .good
    @State private var moodNote = ""
    @State private var wakeTime = Date.now
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var affirmationText = ""
    @State private var currentAffirmationIndex = 0

    private let columns = [GridItem(.adaptive(minimum: 104), spacing: 12)]

    private let defaultAffirmations = [
        "I am becoming the kind of person I want to be.",
        "Small daily actions create lasting change.",
        "I can build peace and momentum at the same time.",
        "Consistency is stronger than intensity.",
        "I honor progress, not perfection.",
        "My habits shape my orbit.",
        "I am allowed to grow slowly and still arrive.",
        "My attention creates my reality.",
        "I can reset my orbit at any moment."
    ]

    private var todayPhotos: [DayPhoto] {
        let calendar = Calendar.current
        return photos.filter { calendar.isDate($0.date, inSameDayAs: .now) }
    }

    private var todayGratitudes: [GratitudeEntry] {
        let calendar = Calendar.current
        return gratitudes.filter { calendar.isDateInToday($0.createdAt) }
    }

    private var todayMood: MoodEntry? {
        let calendar = Calendar.current
        return moods.first(where: { calendar.isDate($0.date, inSameDayAs: .now) })
    }

    private var todayWakeEntry: WakeEntry? {
        wakeEntries.first(where: { Calendar.current.isDate($0.date, inSameDayAs: .now) })
    }

    private var completedToday: Int {
        habits.filter { $0.isCompleted(on: .now) }.count
    }

    private var allAffirmations: [String] {
        let custom = affirmations.map(\.text)
        return Array(NSOrderedSet(array: custom + defaultAffirmations)) as? [String] ?? defaultAffirmations
    }

    private var displayedAffirmation: String {
        guard !allAffirmations.isEmpty else { return "Today is a fresh start." }
        let index = min(currentAffirmationIndex, allAffirmations.count - 1)
        return allAffirmations[index]
    }

    var body: some View {
        NavigationStack {
            ZStack {
                CosmicBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        HeroHeaderCard(completedToday: completedToday, totalHabits: habits.count, photoCount: todayPhotos.count)

                        OrbitCard {
                            VStack(alignment: .leading, spacing: 16) {
                                SectionHeader(title: "Wake Time", subtitle: "When did your day begin?", systemImage: "sunrise.fill")

                                DatePicker("Time I woke up", selection: $wakeTime, displayedComponents: .hourAndMinute)
                                    .foregroundStyle(OrbitTheme.textPrimary)
                                    .tint(OrbitTheme.accent)

                                Button(todayWakeEntry == nil ? "Save Wake Time" : "Update Wake Time") {
                                    saveWakeTime()
                                }
                                .buttonStyle(PrimaryOrbitButtonStyle())
                            }
                        }

                        OrbitCard {
                            VStack(alignment: .leading, spacing: 16) {
                                SectionHeader(title: "Mood", subtitle: "How does your orbit feel today?", systemImage: "moonphase.waxing.gibbous")

                                HStack(spacing: 8) {
                                    ForEach(MoodType.allCases) { mood in
                                        MoodChip(title: mood.emoji, isSelected: selectedMood == mood) {
                                            selectedMood = mood
                                            softHaptic()
                                        }
                                    }
                                }

                                TextField("Optional mood note", text: $moodNote)
                                    .textFieldStyle(OrbitTextFieldStyle())

                                Button(todayMood == nil ? "Save Mood" : "Update Mood") {
                                    saveMood()
                                }
                                .buttonStyle(PrimaryOrbitButtonStyle())
                            }
                        }

                        OrbitCard {
                            VStack(alignment: .leading, spacing: 16) {
                                SectionHeader(title: "Today’s Habits", subtitle: "Complete the actions that shape your orbit.", systemImage: "checkmark.circle")

                                if habits.isEmpty {
                                    EmptyOrbitState(title: "No habits yet", subtitle: "Create your first daily rhythm.", buttonTitle: "Add Habit") {
                                        showAddHabit = true
                                    }
                                } else {
                                    VStack(spacing: 12) {
                                        ForEach(habits) { habit in
                                            NavigationLink {
                                                HabitDetailView(habit: habit)
                                            } label: {
                                                OrbitHabitRow(habit: habit)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                            }
                        }

                        OrbitCard {
                            VStack(alignment: .leading, spacing: 16) {
                                SectionHeader(title: "Gratitudes", subtitle: "Capture what grounded you today.", systemImage: "heart.text.square")

                                HStack(spacing: 10) {
                                    TextField("Write one gratitude...", text: $gratitudeText)
                                        .textFieldStyle(OrbitTextFieldStyle())

                                    Button(action: addGratitude) {
                                        Image(systemName: "plus")
                                            .font(.headline)
                                            .frame(width: 42, height: 42)
                                    }
                                    .buttonStyle(PrimaryOrbitButtonStyle())
                                    .disabled(gratitudeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                }

                                if todayGratitudes.isEmpty {
                                    Text("Nothing added yet.")
                                        .foregroundStyle(OrbitTheme.textSecondary)
                                } else {
                                    VStack(spacing: 10) {
                                        ForEach(todayGratitudes) { entry in
                                            OrbitMiniCard {
                                                VStack(alignment: .leading, spacing: 8) {
                                                    Text(entry.text)
                                                        .foregroundStyle(OrbitTheme.textPrimary)

                                                    if !entry.tags.isEmpty {
                                                        ScrollView(.horizontal, showsIndicators: false) {
                                                            HStack(spacing: 6) {
                                                                ForEach(entry.tags, id: \.self) { tag in
                                                                    TagChip(text: tag)
                                                                }
                                                            }
                                                        }
                                                    }

                                                    Text(entry.createdAt.formatted(date: .omitted, time: .shortened))
                                                        .font(.caption)
                                                        .foregroundStyle(OrbitTheme.textSecondary)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        OrbitCard {
                            VStack(alignment: .leading, spacing: 16) {
                                SectionHeader(title: "Affirmations", subtitle: "A grounding thought for your orbit.", systemImage: "sparkles.rectangle.stack")

                                Text("“\(displayedAffirmation)”")
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(OrbitTheme.textPrimary)

                                HStack(spacing: 10) {
                                    Button("Shuffle") {
                                        currentAffirmationIndex = Int.random(in: 0..<max(allAffirmations.count, 1))
                                        softHaptic()
                                    }
                                    .buttonStyle(SecondaryOrbitButtonStyle())

                                    Button("Save Current") {
                                        saveCurrentAffirmation()
                                    }
                                    .buttonStyle(PrimaryOrbitButtonStyle())
                                }

                                TextField("Add your own affirmation", text: $affirmationText)
                                    .textFieldStyle(OrbitTextFieldStyle())

                                Button("Add Custom Affirmation") {
                                    addCustomAffirmation()
                                }
                                .buttonStyle(SecondaryOrbitButtonStyle())
                                .disabled(affirmationText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            }
                        }

                        OrbitCard {
                            VStack(alignment: .leading, spacing: 16) {
                                SectionHeader(title: "Photos", subtitle: "Attach moments to this day.", systemImage: "photo.on.rectangle")

                                PhotosPicker(selection: $selectedPhotoItems, maxSelectionCount: 8, matching: .images) {
                                    HStack {
                                        Image(systemName: "photo.badge.plus")
                                        Text("Add Photos")
                                        Spacer()
                                    }
                                }
                                .buttonStyle(SecondaryOrbitButtonStyle())

                                if todayPhotos.isEmpty {
                                    Text("No photos for today yet.")
                                        .foregroundStyle(OrbitTheme.textSecondary)
                                } else {
                                    LazyVGrid(columns: columns, spacing: 12) {
                                        ForEach(todayPhotos) { photo in
                                            OrbitPhotoTile(photo: photo)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Inner Orbit")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddHabit = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                    }
                    .tint(OrbitTheme.accent)
                }
            }
            .sheet(isPresented: $showAddHabit) {
                AddHabitView()
                    .presentationDetents([.medium])
            }
            .task(id: selectedPhotoItems) {
                await importSelectedPhotos()
            }
            .onAppear {
                if let todayMood {
                    selectedMood = todayMood.mood
                    moodNote = todayMood.note
                }
                if let todayWakeEntry {
                    wakeTime = todayWakeEntry.wakeTime
                }
            }
        }
    }

    private func addGratitude() {
        let text = gratitudeText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        modelContext.insert(GratitudeEntry(text: text))
        try? modelContext.save()
        gratitudeText = ""
        softHaptic()
    }

    private func saveMood() {
        let calendar = Calendar.current
        if let existing = moods.first(where: { calendar.isDate($0.date, inSameDayAs: .now) }) {
            existing.mood = selectedMood
            existing.note = moodNote
        } else {
            modelContext.insert(MoodEntry(date: .now, mood: selectedMood, note: moodNote))
        }
        try? modelContext.save()
        softHaptic()
    }

    private func saveWakeTime() {
        if let existing = todayWakeEntry {
            existing.wakeTime = wakeTime
        } else {
            modelContext.insert(WakeEntry(date: .now, wakeTime: wakeTime))
        }
        try? modelContext.save()
        softHaptic()
    }

    private func saveCurrentAffirmation() {
        let text = displayedAffirmation.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        guard !affirmations.contains(where: { $0.text.caseInsensitiveCompare(text) == .orderedSame }) else { return }
        modelContext.insert(AffirmationEntry(text: text, isFavorite: true))
        try? modelContext.save()
        softHaptic()
    }

    private func addCustomAffirmation() {
        let text = affirmationText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        modelContext.insert(AffirmationEntry(text: text, isFavorite: true))
        try? modelContext.save()
        affirmationText = ""
        currentAffirmationIndex = 0
        softHaptic()
    }

    private func importSelectedPhotos() async {
        guard !selectedPhotoItems.isEmpty else { return }
        let items = selectedPhotoItems
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self) {
                modelContext.insert(DayPhoto(date: .now, imageData: data))
            }
        }
        try? modelContext.save()
        selectedPhotoItems = []
        softHaptic()
    }

    private func softHaptic() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}

// MARK: - Insights

struct StatsView: View {
    @Query(sort: \Habit.createdAt) private var habits: [Habit]
    @Query(sort: \MoodEntry.date) private var moods: [MoodEntry]
    @Query(sort: \GratitudeEntry.createdAt, order: .reverse) private var gratitudes: [GratitudeEntry]
    @Query(sort: \WakeEntry.date) private var wakeEntries: [WakeEntry]

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
                                .pickerStyle(.menu)

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
                                        ("Top Tag", gratitudeTagCounts.first?.tag.capitalized ?? "—")
                                    ])
                                }
                            }

                        case .wake:
                            OrbitCard {
                                VStack(alignment: .leading, spacing: 16) {
                                    SectionHeader(title: "Wake Time Trend", subtitle: "See how consistently your days begin.", systemImage: "sunrise.fill")

                                    if wakePoints.isEmpty {
                                        Text("Save a wake time on the Today screen to begin your trend.")
                                            .foregroundStyle(OrbitTheme.textSecondary)
                                    } else {
                                        WakeTimeChart(points: wakePoints)
                                            .frame(height: 220)

                                        KPIGrid(items: [
                                            ("Average", formattedWakeTime(averageWakeMinutes)),
                                            ("Earliest", formattedWakeTime(wakePoints.map(\.minutesAfterMidnight).min())),
                                            ("Latest", formattedWakeTime(wakePoints.map(\.minutesAfterMidnight).max()))
                                        ])
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
        guard !filteredMoods.isEmpty else { return "—" }
        let avg = Double(filteredMoods.map { $0.mood.score }.reduce(0, +)) / Double(filteredMoods.count)
        return String(format: "%.1f/5", avg)
    }

    private var bestMoodText: String {
        filteredMoods.max(by: { $0.mood.score < $1.mood.score })?.mood.rawValue ?? "—"
    }

    private var wakePoints: [WakePoint] {
        wakeEntries
            .filter { dateRange.contains($0.date) }
            .map { WakePoint(date: $0.date, minutesAfterMidnight: $0.minutesAfterMidnight) }
    }

    private var averageWakeMinutes: Double? {
        guard !wakePoints.isEmpty else { return nil }
        return wakePoints.map(\.minutesAfterMidnight).reduce(0, +) / Double(wakePoints.count)
    }

    private func formattedWakeTime(_ minutes: Double?) -> String {
        guard let minutes else { return "—" }
        let total = Int(minutes.rounded())
        let date = Calendar.current.date(bySettingHour: total / 60, minute: total % 60, second: 0, of: .now) ?? .now
        return date.formatted(date: .omitted, time: .shortened)
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

// MARK: - Explore

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

        return parts.joined(separator: " • ")
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

// MARK: - Library

struct LibraryView: View {
    @Query(sort: \Habit.createdAt) private var habits: [Habit]
    @Query(sort: \DayPhoto.createdAt, order: .reverse) private var photos: [DayPhoto]
    @Query(sort: \AffirmationEntry.createdAt, order: .reverse) private var affirmations: [AffirmationEntry]

    var body: some View {
        NavigationStack {
            ZStack {
                CosmicBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        OrbitCard {
                            VStack(alignment: .leading, spacing: 14) {
                                SectionHeader(title: "Habit Library", subtitle: "Browse everything you’re building.", systemImage: "books.vertical")

                                if habits.isEmpty {
                                    Text("No habits created yet.")
                                        .foregroundStyle(OrbitTheme.textSecondary)
                                } else {
                                    ForEach(habits) { habit in
                                        NavigationLink {
                                            HabitDetailView(habit: habit)
                                        } label: {
                                            OrbitHabitRow(habit: habit)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }

                        OrbitCard {
                            VStack(alignment: .leading, spacing: 14) {
                                SectionHeader(title: "Saved Affirmations", subtitle: "Words you wanted to keep close.", systemImage: "sparkles")

                                if affirmations.isEmpty {
                                    Text("No custom or saved affirmations yet.")
                                        .foregroundStyle(OrbitTheme.textSecondary)
                                } else {
                                    VStack(spacing: 10) {
                                        ForEach(affirmations) { affirmation in
                                            OrbitMiniCard {
                                                Text("“\(affirmation.text)”")
                                                    .foregroundStyle(OrbitTheme.textPrimary)
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        OrbitCard {
                            VStack(alignment: .leading, spacing: 14) {
                                SectionHeader(title: "Photo Archive", subtitle: "Moments attached to your days.", systemImage: "photo.stack")

                                if photos.isEmpty {
                                    Text("No photos yet.")
                                        .foregroundStyle(OrbitTheme.textSecondary)
                                } else {
                                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 12)], spacing: 12) {
                                        ForEach(photos) { photo in
                                            OrbitPhotoTile(photo: photo)
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
            .navigationTitle("Library")
        }
    }
}

// MARK: - Habit Detail

struct HabitDetailView: View {
    let habit: Habit
    @State private var selectedRange: TimeRange = .thirtyDays
    @State private var showReminderEditor = false

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

                    OrbitCard {
                        VStack(alignment: .leading, spacing: 14) {
                            SectionHeader(
                                title: "Reminder",
                                subtitle: habit.reminderSummary,
                                systemImage: habit.reminderEnabled ? "bell.fill" : "bell"
                            )

                            Button {
                                showReminderEditor = true
                            } label: {
                                Label(habit.reminderEnabled ? "Edit Reminder" : "Set Reminder", systemImage: "calendar.badge.clock")
                            }
                            .buttonStyle(SecondaryOrbitButtonStyle())
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
        .sheet(isPresented: $showReminderEditor) {
            HabitReminderEditorView(habit: habit)
                .presentationDetents([.medium])
        }
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

// MARK: - Add Habit

struct AddHabitView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var name = ""
    @State private var detail = ""
    @State private var frequency: HabitFrequency = .daily
    @State private var reminderEnabled = false
    @State private var reminderTime = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: .now) ?? .now

    var body: some View {
        NavigationStack {
            ZStack {
                CosmicBackground()

                VStack(spacing: 18) {
                    OrbitCard {
                        VStack(alignment: .leading, spacing: 14) {
                            SectionHeader(title: "New Habit", subtitle: "Add the next action to your orbit.", systemImage: "plus.circle")

                            TextField("Habit name", text: $name)
                                .textFieldStyle(OrbitTextFieldStyle())

                            TextField("Notes (optional)", text: $detail)
                                .textFieldStyle(OrbitTextFieldStyle())

                            Picker("Frequency", selection: $frequency) {
                                ForEach(HabitFrequency.allCases) { frequency in
                                    Text(frequency.rawValue).tag(frequency)
                                }
                            }
                            .pickerStyle(.segmented)

                            Divider()
                                .overlay(Color.white.opacity(0.08))

                            Toggle(isOn: $reminderEnabled) {
                                Label("Remind me", systemImage: "bell")
                                    .foregroundStyle(OrbitTheme.textPrimary)
                            }
                            .tint(OrbitTheme.accent)

                            if reminderEnabled {
                                DatePicker("Reminder time", selection: $reminderTime, displayedComponents: .hourAndMinute)
                                    .foregroundStyle(OrbitTheme.textPrimary)
                                    .tint(OrbitTheme.accent)
                            }
                        }
                    }

                    Button("Save Habit") {
                        saveHabit()
                    }
                    .buttonStyle(PrimaryOrbitButtonStyle())
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    Spacer()
                }
                .padding(16)
            }
            .navigationTitle("Add Habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                        .tint(OrbitTheme.accent)
                }
            }
        }
    }

    private func saveHabit() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        let components = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
        let habit = Habit(
            name: trimmedName,
            detail: detail,
            frequency: frequency,
            reminderEnabled: reminderEnabled,
            reminderHour: components.hour ?? 8,
            reminderMinute: components.minute ?? 0
        )
        modelContext.insert(habit)
        try? modelContext.save()
        Task {
            await HabitReminderScheduler.schedule(for: habit)
        }
        dismiss()
    }
}

struct HabitReminderEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let habit: Habit
    @State private var reminderEnabled: Bool
    @State private var reminderTime: Date

    init(habit: Habit) {
        self.habit = habit
        _reminderEnabled = State(initialValue: habit.reminderEnabled)
        _reminderTime = State(initialValue: habit.reminderDate)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                CosmicBackground()

                VStack(spacing: 18) {
                    OrbitCard {
                        VStack(alignment: .leading, spacing: 14) {
                            SectionHeader(title: "Habit Reminder", subtitle: "Stay accountable to \(habit.name.lowercased()).", systemImage: "bell.badge")

                            Toggle("Remind me", isOn: $reminderEnabled)
                                .tint(OrbitTheme.accent)

                            if reminderEnabled {
                                DatePicker("Reminder time", selection: $reminderTime, displayedComponents: .hourAndMinute)
                                    .tint(OrbitTheme.accent)

                                Text("Repeats \(habit.frequency.rawValue.lowercased()).")
                                    .font(.subheadline)
                                    .foregroundStyle(OrbitTheme.textSecondary)
                            }
                        }
                    }

                    Button("Save Reminder") {
                        habit.reminderEnabled = reminderEnabled
                        habit.reminderDate = reminderTime
                        try? modelContext.save()
                        Task {
                            await HabitReminderScheduler.schedule(for: habit)
                        }
                        dismiss()
                    }
                    .buttonStyle(PrimaryOrbitButtonStyle())

                    Spacer()
                }
                .padding(16)
            }
            .navigationTitle("Reminder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                        .tint(OrbitTheme.accent)
                }
            }
        }
    }
}

// MARK: - Shared UI

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
                if habit.reminderEnabled {
                    Label(habit.reminderDate.formatted(date: .omitted, time: .shortened), systemImage: "bell.fill")
                        .font(.caption)
                        .foregroundStyle(OrbitTheme.accent)
                }
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

struct WakeTimeChart: View {
    let points: [WakePoint]

    private var domain: ClosedRange<Double> {
        let values = points.map(\.minutesAfterMidnight)
        let lower = min(max((values.min() ?? 360) - 45, 0), 1379)
        let upper = min(max((values.max() ?? 540) + 45, lower + 60), 1439)
        return lower...upper
    }

    var body: some View {
        Chart(points) { point in
            LineMark(
                x: .value("Date", point.date, unit: .day),
                y: .value("Wake Time", point.minutesAfterMidnight)
            )
            .foregroundStyle(OrbitTheme.accent3)
            .interpolationMethod(.catmullRom)

            PointMark(
                x: .value("Date", point.date, unit: .day),
                y: .value("Wake Time", point.minutesAfterMidnight)
            )
            .foregroundStyle(OrbitTheme.accent3)
        }
        .chartYScale(domain: domain)
        .chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                AxisGridLine()
                AxisTick()
                AxisValueLabel {
                    if let minutes = value.as(Double.self) {
                        let total = Int(minutes.rounded())
                        let date = Calendar.current.date(bySettingHour: total / 60, minute: total % 60, second: 0, of: .now) ?? .now
                        Text(date.formatted(.dateTime.hour().minute()))
                    }
                }
            }
        }
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
