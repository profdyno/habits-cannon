import SwiftUI
import SwiftData
import PhotosUI

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Habit.createdAt) private var habits: [Habit]
    @Query(sort: \GratitudeEntry.createdAt, order: .reverse) private var gratitudes: [GratitudeEntry]
    @Query(sort: \DayPhoto.createdAt, order: .reverse) private var photos: [DayPhoto]
    @Query(sort: \MoodEntry.date, order: .reverse) private var moods: [MoodEntry]
    @Query(sort: \AffirmationEntry.createdAt, order: .reverse) private var affirmations: [AffirmationEntry]

    @State private var showAddHabit = false
    @State private var gratitudeText = ""
    @State private var selectedMood: MoodType = .good
    @State private var moodNote = ""
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
                                SectionHeader(title: "Today's Habits", subtitle: "Complete the actions that shape your orbit.", systemImage: "checkmark.circle")

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

                                Text("\u{201C}\(displayedAffirmation)\u{201D}")
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
