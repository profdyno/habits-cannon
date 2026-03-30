import SwiftUI
import SwiftData

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
                                SectionHeader(title: "Habit Library", subtitle: "Browse everything you're building.", systemImage: "books.vertical")

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
                                                Text("\u{201C}\(affirmation.text)\u{201D}")
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
