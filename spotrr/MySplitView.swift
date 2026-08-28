//
//  MySplitView.swift
//  spotrr
//
//  Created by Spottr on 28/08/2026.
//

import SwiftUI

struct MySplitView: View {
    @EnvironmentObject var store: SpottrStore
    @State private var editingWeekday: Weekday? = nil

    private let weekdays: [Weekday] = [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday]

    var body: some View {
        NavigationStack {
            ZStack {
                SpottrTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(weekdays) { weekday in
                            dayCard(for: weekday)
                        }

                        Spacer().frame(height: 30)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
            .navigationTitle("My Split")
            .sheet(item: $editingWeekday) { weekday in
                EditDayRoutineSheet(routine: store.routine(for: weekday))
            }
        }
    }

    // MARK: - Day Card
    private func dayCard(for weekday: Weekday) -> some View {
        let routine = store.routine(for: weekday)
        let isToday = (Weekday.today() == weekday)

        return Button {
            editingWeekday = weekday
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                // Header Row
                HStack {
                    Text(weekday.fullName.uppercased())
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .foregroundStyle(isToday ? SpottrTheme.accent : SpottrTheme.textMuted)
                        .tracking(1)

                    if isToday {
                        Text("TODAY")
                            .font(.system(size: 9, weight: .heavy, design: .rounded))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(SpottrTheme.accent)
                            .clipShape(Capsule())
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(SpottrTheme.textMuted)
                }

                // Routine Title
                Text(routine.title.isEmpty ? (routine.isRestDay ? "Rest Day" : "Workout Day") : routine.title)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(routine.isRestDay ? SpottrTheme.green : SpottrTheme.textPrimary)

                // Exercises Bullet Preview
                if !routine.isRestDay && !routine.exercises.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(routine.exercises.prefix(4)) { ex in
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(SpottrTheme.textMuted)
                                    .frame(width: 3, height: 3)
                                Text(ex.name)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(SpottrTheme.textSecondary)
                                    .lineLimit(1)
                            }
                        }

                        if routine.exercises.count > 4 {
                            Text("+\(routine.exercises.count - 4) more exercises")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundStyle(SpottrTheme.textMuted)
                                .padding(.top, 2)
                        }
                    }
                } else if routine.isRestDay {
                    Text("Recovery • Mobility")
                        .font(.system(size: 13))
                        .foregroundStyle(SpottrTheme.textMuted)
                } else {
                    Text("No exercises added • Tap to edit")
                        .font(.system(size: 13))
                        .foregroundStyle(SpottrTheme.textMuted)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .spottrCard(padding: 14)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isToday ? SpottrTheme.accent.opacity(0.4) : SpottrTheme.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    MySplitView()
        .environmentObject(SpottrStore())
}

