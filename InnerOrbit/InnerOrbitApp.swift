import SwiftUI
import SwiftData
import PhotosUI
import Charts
import UIKit

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
    var createdAt: Date
    @Relationship(deleteRule: .cascade) var completions: [HabitCompletion]

    init(
        id: UUID = UUID(),
        name: String,
        detail: String = "",
        frequency: HabitFrequency = .daily,
        createdAt: Date = .now,
        completions: [HabitCompletion] = []
    ) {
        self.id = id
        self.name = name
        self.detail = detail
        self.frequencyRaw = frequency.rawValue
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
            AffirmationEntry.self
        ])

        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
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
