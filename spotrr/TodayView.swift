//
//  TodayView.swift
//  spotrr
//
//  Created by Spottr on 28/08/2026.
//

import SwiftUI

struct TodayView: View {
    @EnvironmentObject var store: SpottrStore
    @State private var showEditSheet: Bool = false
    @State private var showAddExerciseSheet: Bool = false

    private var currentRoutine: DayRoutine {
        store.routine(for: store.selectedWeekday)
    }

    private var isToday: Bool {
        store.selectedWeekday == Weekday.today()
    }

    var body: some View {
        NavigationStack {
            ZStack {
                SpottrTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Weekday Selector Strip (Mon - Sun)
                        weekdaySelectorStrip

                        // Header (Day, Date & Split Title)
                        headerCard

                        // Main Content: Exercises Checklist or Rest Day View
                        if currentRoutine.isRestDay {
                            restDayCard
                        } else if currentRoutine.exercises.isEmpty {
                            emptyRoutineCard
                        } else {
                            exercisesChecklist
                        }

                        Spacer().frame(height: 40)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !isToday {
                        Button {
                            withAnimation(.spring(response: 0.3)) {
                                store.selectedWeekday = Weekday.today()
                            }
                        } label: {
                            Text("Go to Today")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(SpottrTheme.accent)
                        }
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showEditSheet = true
                        } label: {
                            Label("Edit Routine & Exercises", systemImage: "pencil")
                        }

                        if !currentRoutine.isRestDay && !currentRoutine.exercises.isEmpty {
                            Button(role: .destructive) {
                                store.resetDayChecks(for: store.selectedWeekday)
                            } label: {
                                Label("Reset Checkmarks", systemImage: "arrow.counterclockwise")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 18))
                            .foregroundStyle(SpottrTheme.textSecondary)
                    }
                }
            }
            .sheet(isPresented: $showEditSheet) {
                EditDayRoutineSheet(routine: currentRoutine)
            }
        }
    }

    // MARK: - Weekday Selector Strip
    private var weekdaySelectorStrip: some View {
        HStack(spacing: 8) {
            ForEach(Weekday.allCases) { weekday in
                let isSelected = (store.selectedWeekday == weekday)
                let isCurrentDay = (Weekday.today() == weekday)
                let dayRoutine = store.routine(for: weekday)

                Button {
                    withAnimation(.spring(response: 0.3)) {
                        store.selectedWeekday = weekday
                    }
                } label: {
                    VStack(spacing: 5) {
                        Text(weekday.singleLetter)
                            .font(.system(size: 12, weight: .black, design: .rounded))
                            .foregroundStyle(isSelected ? .black : (isCurrentDay ? SpottrTheme.accent : SpottrTheme.textSecondary))

                        // Mini Indicator dot (Rest vs Training)
                        Circle()
                            .fill(isSelected ? .black : (dayRoutine.isRestDay ? SpottrTheme.textMuted.opacity(0.3) : SpottrTheme.accent))
                            .frame(width: 4, height: 4)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(isSelected ? SpottrTheme.accent : SpottrTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(isSelected ? Color.clear : (isCurrentDay ? SpottrTheme.accent.opacity(0.4) : SpottrTheme.border), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Header Card
    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(isToday ? "\(store.selectedWeekday.fullName.uppercased()) • TODAY" : store.selectedWeekday.fullName.uppercased())
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundStyle(SpottrTheme.textMuted)
                    .tracking(1.2)

                Spacer()

                if !currentRoutine.isRestDay && currentRoutine.totalCount > 0 {
                    Text("\(currentRoutine.completedCount) of \(currentRoutine.totalCount) done")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(currentRoutine.completedCount == currentRoutine.totalCount ? SpottrTheme.accent : SpottrTheme.textSecondary)
                }
            }

            Text(currentRoutine.title.isEmpty ? (currentRoutine.isRestDay ? "Rest Day" : "Workout Day") : currentRoutine.title)
                .font(.system(size: 26, weight: .black, design: .rounded))
                .foregroundStyle(currentRoutine.isRestDay ? SpottrTheme.green : SpottrTheme.textPrimary)

            // Progress bar
            if !currentRoutine.isRestDay && currentRoutine.totalCount > 0 {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(SpottrTheme.cardSubtle)
                            .frame(height: 5)

                        Capsule()
                            .fill(SpottrTheme.accent)
                            .frame(width: geo.size.width * CGFloat(Double(currentRoutine.completedCount) / Double(currentRoutine.totalCount)), height: 5)
                    }
                }
                .frame(height: 5)
            }
        }
        .spottrCard()
    }

    // MARK: - Exercises Checklist
    private var exercisesChecklist: some View {
        VStack(spacing: 8) {
            ForEach(currentRoutine.exercises) { exercise in
                Button {
                    withAnimation(.spring(response: 0.25)) {
                        store.toggleExercise(weekday: store.selectedWeekday, exerciseId: exercise.id)
                    }
                } label: {
                    HStack(spacing: 14) {
                        // Clean Checkmark Circle
                        Image(systemName: exercise.isCompleted ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(exercise.isCompleted ? SpottrTheme.accent : SpottrTheme.textMuted)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(exercise.name)
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundStyle(exercise.isCompleted ? SpottrTheme.textMuted : SpottrTheme.textPrimary)
                                .strikethrough(exercise.isCompleted, color: SpottrTheme.textMuted)

                            if !exercise.detailText.isEmpty {
                                Text(exercise.detailText)
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .foregroundStyle(SpottrTheme.textMuted)
                            }
                        }

                        Spacer()
                    }
                    .padding(14)
                    .background(SpottrTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(exercise.isCompleted ? SpottrTheme.accent.opacity(0.3) : SpottrTheme.border, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }

            // Quick "+ Add Movement" link
            Button {
                showEditSheet = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))
                    Text("Edit / Add Exercises")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                }
                .foregroundStyle(SpottrTheme.textMuted)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Rest Day Card
    private var restDayCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "bed.double.fill")
                .font(.system(size: 36))
                .foregroundStyle(SpottrTheme.green)
                .padding(.top, 8)

            Text("Rest & Recovery")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(SpottrTheme.textPrimary)

            Text("No workout scheduled for today. Rebuild muscle fibers, hydrate, and get ready for your next session.")
                .font(.system(size: 13))
                .foregroundStyle(SpottrTheme.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)

            Button {
                showEditSheet = true
            } label: {
                Text("Change to Workout Day")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(SpottrTheme.accent)
                    .padding(.top, 6)
            }
        }
        .frame(maxWidth: .infinity)
        .spottrCard(padding: 24)
    }

    // MARK: - Empty Routine Card
    private var emptyRoutineCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "square.and.pencil")
                .font(.system(size: 32))
                .foregroundStyle(SpottrTheme.accent)

            Text("No Exercises Added Yet")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(SpottrTheme.textPrimary)

            Text("Type in your exercises just like writing a quick note.")
                .font(.system(size: 13))
                .foregroundStyle(SpottrTheme.textSecondary)
                .multilineTextAlignment(.center)

            Button {
                showEditSheet = true
            } label: {
                Text("+ Add Exercises")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(SpottrTheme.accent)
                    .clipShape(Capsule())
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .spottrCard(padding: 24)
    }
}

#Preview {
    TodayView()
        .environmentObject(SpottrStore())
}

