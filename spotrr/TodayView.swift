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

    // Quick Inline Add state
    @State private var newExerciseName: String = ""
    @State private var newExerciseWeight: String = ""
    @State private var isAddingInline: Bool = false
    @FocusState private var isNameFocused: Bool

    // Quick Edit Single Exercise state
    @State private var editingExercise: ExerciseItem? = nil

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
                    VStack(spacing: 16) {
                        // Weekday Selector Strip (Mon - Sun or Sun - Sat based on Settings)
                        weekdaySelectorStrip

                        // Header (Day & Split Title)
                        headerCard

                        // Main Content: Exercises Checklist or Rest Day View
                        if currentRoutine.isRestDay {
                            restDayCard
                        } else {
                            exercisesSection
                        }

                        Spacer().frame(height: 50)
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
                            Text("Today")
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
                            Label("Edit Split Title & Rest Day", systemImage: "pencil")
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
            .sheet(item: $editingExercise) { ex in
                QuickExerciseEditSheet(weekday: store.selectedWeekday, exercise: ex)
            }
        }
    }

    // MARK: - Weekday Selector Strip
    private var weekdaySelectorStrip: some View {
        HStack(spacing: 8) {
            ForEach(store.orderedWeekdays) { weekday in
                let isSelected = (store.selectedWeekday == weekday)
                let isCurrentDay = (Weekday.today() == weekday)
                let dayRoutine = store.routine(for: weekday)

                Button {
                    withAnimation(.spring(response: 0.3)) {
                        store.selectedWeekday = weekday
                        isAddingInline = false
                    }
                } label: {
                    VStack(spacing: 5) {
                        Text(weekday.singleLetter)
                            .font(.system(size: 12, weight: .black, design: .rounded))
                            .foregroundStyle(isSelected ? .black : (isCurrentDay ? SpottrTheme.accent : SpottrTheme.textSecondary))

                        // Dot (Rest vs Training)
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
            HStack(alignment: .center) {
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
                            .frame(height: 4)

                        Capsule()
                            .fill(SpottrTheme.accent)
                            .frame(width: geo.size.width * CGFloat(Double(currentRoutine.completedCount) / Double(currentRoutine.totalCount)), height: 4)
                    }
                }
                .frame(height: 4)
            }
        }
        .spottrCard()
    }

    // MARK: - Exercises Section
    private var exercisesSection: some View {
        VStack(spacing: 10) {
            // Exercise Checklist Rows
            ForEach(currentRoutine.exercises) { exercise in
                exerciseRow(exercise: exercise)
            }

            // Direct Inline "+ Add Exercise" Card
            if isAddingInline {
                inlineAddExerciseCard
            } else {
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        isAddingInline = true
                        isNameFocused = true
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 16, weight: .bold))
                        Text("Add Exercise")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(SpottrTheme.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(SpottrTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(SpottrTheme.accent.opacity(0.3), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Exercise Row
    private func exerciseRow(exercise: ExerciseItem) -> some View {
        HStack(spacing: 12) {
            // Checkmark button
            Button {
                withAnimation(.spring(response: 0.25)) {
                    store.toggleExercise(weekday: store.selectedWeekday, exerciseId: exercise.id)
                }
            } label: {
                Image(systemName: exercise.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(exercise.isCompleted ? SpottrTheme.accent : SpottrTheme.textMuted)
            }
            .buttonStyle(.plain)

            // Exercise Name & Detail
            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.name)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(exercise.isCompleted ? SpottrTheme.textMuted : SpottrTheme.textPrimary)
                    .strikethrough(exercise.isCompleted, color: SpottrTheme.textMuted)

                let detail = exercise.formattedDetail(unit: store.weightUnit)
                if !detail.isEmpty {
                    Text(detail)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(SpottrTheme.textMuted)
                }
            }

            Spacer()

            // Tap Weight to edit
            Button {
                editingExercise = exercise
            } label: {
                HStack(spacing: 4) {
                    if !exercise.weight.isEmpty {
                        Text("\(exercise.weight) \(store.weightUnit.rawValue)")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(SpottrTheme.accent)
                    } else {
                        Text("+ Weight")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(SpottrTheme.textMuted)
                    }
                    Image(systemName: "pencil")
                        .font(.system(size: 9))
                        .foregroundStyle(SpottrTheme.textMuted)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(SpottrTheme.cardSubtle)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(SpottrTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(exercise.isCompleted ? SpottrTheme.accent.opacity(0.3) : SpottrTheme.border, lineWidth: 1)
        )
        .contextMenu {
            Button {
                editingExercise = exercise
            } label: {
                Label("Edit Weight", systemImage: "pencil")
            }

            Button(role: .destructive) {
                store.deleteExercise(from: store.selectedWeekday, exerciseId: exercise.id)
            } label: {
                Label("Delete Exercise", systemImage: "trash")
            }
        }
    }

    // MARK: - Inline Add Exercise Card
    private var inlineAddExerciseCard: some View {
        VStack(spacing: 12) {
            TextField("Exercise Name (e.g. Incline Bench)", text: $newExerciseName)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(SpottrTheme.textPrimary)
                .focused($isNameFocused)

            HStack(spacing: 10) {
                TextField("Weight (\(store.weightUnit.rawValue))", text: $newExerciseWeight)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .keyboardType(.numbersAndPunctuation)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(SpottrTheme.cardSubtle)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                Spacer()

                Button("Cancel") {
                    withAnimation {
                        resetInlineAdd()
                    }
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(SpottrTheme.textMuted)

                Button("Add") {
                    saveInlineExercise()
                }
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.black)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(newExerciseName.trimmingCharacters(in: .whitespaces).isEmpty ? SpottrTheme.cardSubtle : SpottrTheme.accent)
                .clipShape(Capsule())
                .disabled(newExerciseName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .spottrCard(padding: 14)
    }

    private func saveInlineExercise() {
        guard !newExerciseName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        store.addExercise(
            to: store.selectedWeekday,
            name: newExerciseName,
            weight: newExerciseWeight
        )
        resetInlineAdd()
    }

    private func resetInlineAdd() {
        newExerciseName = ""
        newExerciseWeight = ""
        isAddingInline = false
        isNameFocused = false
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

            Text("No workout scheduled for today. Rebuild muscle fibers, hydrate, and prepare for your next session.")
                .font(.system(size: 13))
                .foregroundStyle(SpottrTheme.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)

            Button {
                store.toggleRestDay(for: store.selectedWeekday)
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
}

// MARK: - Quick Single Exercise Edit Sheet
struct QuickExerciseEditSheet: View {
    @EnvironmentObject var store: SpottrStore
    @Environment(\.dismiss) private var dismiss

    let weekday: Weekday
    @State var exercise: ExerciseItem

    var body: some View {
        NavigationStack {
            ZStack {
                SpottrTheme.background.ignoresSafeArea()

                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("EXERCISE NAME")
                            .font(.system(size: 11, weight: .heavy, design: .rounded))
                            .foregroundStyle(SpottrTheme.textMuted)

                        TextField("Exercise Name", text: $exercise.name)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(SpottrTheme.textPrimary)
                            .padding(12)
                            .background(SpottrTheme.card)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("WEIGHT (\(store.weightUnit.uppercaseName))")
                            .font(.system(size: 11, weight: .heavy, design: .rounded))
                            .foregroundStyle(SpottrTheme.textMuted)

                        TextField("e.g. 185", text: $exercise.weight)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .keyboardType(.numbersAndPunctuation)
                            .foregroundStyle(SpottrTheme.accent)
                            .padding(12)
                            .background(SpottrTheme.card)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    Button(role: .destructive) {
                        store.deleteExercise(from: weekday, exerciseId: exercise.id)
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("Delete Exercise")
                        }
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.red)
                        .padding(.top, 10)
                    }

                    Spacer()
                }
                .padding(20)
            }
            .navigationTitle("Edit Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(SpottrTheme.textSecondary)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.updateExercise(weekday: weekday, exercise: exercise)
                        dismiss()
                    }
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(SpottrTheme.accent)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    TodayView()
        .environmentObject(SpottrStore())
}
