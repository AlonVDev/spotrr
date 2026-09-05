//
//  SplitView.swift
//  spotrr
//

import SwiftUI

struct SplitView: View {
    @EnvironmentObject var store: SpottrStore

    @State private var isAddingExercise = false
    @State private var editingExerciseID: UUID?
    @State private var exerciseName = ""
    @State private var exerciseWeight = ""
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case title, exerciseName, exerciseWeight
    }

    private var currentRoutine: DayRoutine {
        store.routine(for: store.selectedWeekday)
    }

    private var isToday: Bool {
        store.selectedWeekday == Weekday.today()
    }

    private var titleBinding: Binding<String> {
        Binding(
            get: { currentRoutine.title },
            set: { title in
                var routine = currentRoutine
                routine.title = title
                store.updateRoutine(routine)
            }
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                SpottrTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        weekdaySelectorStrip
                        headerCard

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
        }
    }

    private var weekdaySelectorStrip: some View {
        HStack(spacing: 6) {
            ForEach(store.orderedWeekdays) { weekday in
                let isSelected = store.selectedWeekday == weekday
                let isCurrentDay = Weekday.today() == weekday
                let dayRoutine = store.routine(for: weekday)

                Button {
                    select(weekday: weekday)
                } label: {
                    VStack(spacing: 6) {
                        Text(weekday.singleLetter)
                            .font(.system(size: 18, weight: .black, design: .rounded))
                            .foregroundStyle(isSelected ? .black : (isCurrentDay ? SpottrTheme.accent : SpottrTheme.textSecondary))

                        Circle()
                            .fill(isSelected ? .black : (dayRoutine.isRestDay ? SpottrTheme.textMuted.opacity(0.3) : SpottrTheme.accent))
                            .frame(width: 6, height: 6)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(isSelected ? SpottrTheme.accent : SpottrTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(isSelected ? Color.clear : (isCurrentDay ? SpottrTheme.accent.opacity(0.4) : SpottrTheme.border), lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

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

            HStack(alignment: .center, spacing: 12) {
                TextField(currentRoutine.isRestDay ? "Rest Day" : "Workout Day", text: titleBinding)
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundStyle(currentRoutine.isRestDay ? SpottrTheme.restColor : SpottrTheme.textPrimary)
                    .focused($focusedField, equals: .title)
                    .submitLabel(.done)

                Button {
                    withAnimation(.spring(response: 0.3)) {
                        store.toggleRestDay(for: store.selectedWeekday)
                    }
                } label: {
                    Image(systemName: currentRoutine.isRestDay ? "dumbbell.fill" : "bed.double.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(currentRoutine.isRestDay ? SpottrTheme.accent : SpottrTheme.restColor)
                        .frame(width: 38, height: 38)
                        .background(SpottrTheme.cardSubtle)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }

            if !currentRoutine.isRestDay && currentRoutine.totalCount > 0 {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(SpottrTheme.cardSubtle).frame(height: 4)
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

    private var exercisesSection: some View {
        VStack(spacing: 10) {
            ForEach(currentRoutine.exercises) { exercise in
                if editingExerciseID == exercise.id {
                    inlineExerciseEditor
                } else {
                    exerciseRow(exercise)
                }
            }

            if isAddingExercise {
                inlineExerciseEditor
            } else {
                Button {
                    beginAddingExercise()
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
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(SpottrTheme.accent.opacity(0.3), lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func exerciseRow(_ exercise: ExerciseItem) -> some View {
        HStack(spacing: 12) {
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

            Image(systemName: "pencil")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(SpottrTheme.textMuted)
        }
        .padding(14)
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .onTapGesture {
            beginEditing(exercise)
        }
        .background(SpottrTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(exercise.isCompleted ? SpottrTheme.accent.opacity(0.3) : SpottrTheme.border, lineWidth: 1)
        }
    }

    private var inlineExerciseEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Exercise Name (e.g. Incline Bench)", text: $exerciseName)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(SpottrTheme.textPrimary)
                .focused($focusedField, equals: .exerciseName)

            HStack(spacing: 10) {
                TextField("Weight (\(store.weightUnit.rawValue))", text: $exerciseWeight)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .keyboardType(.numbersAndPunctuation)
                    .focused($focusedField, equals: .exerciseWeight)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(SpottrTheme.cardSubtle)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                Spacer()

                Button("Cancel") {
                    cancelExerciseEditing()
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(SpottrTheme.textMuted)

                Button(editingExerciseID == nil ? "Add" : "Save") {
                    saveExercise()
                }
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.black)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(exerciseName.trimmingCharacters(in: .whitespaces).isEmpty ? SpottrTheme.cardSubtle : SpottrTheme.accent)
                .clipShape(Capsule())
                .disabled(exerciseName.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            if let exerciseID = editingExerciseID {
                Button(role: .destructive) {
                    store.deleteExercise(from: store.selectedWeekday, exerciseId: exerciseID)
                    cancelExerciseEditing()
                } label: {
                    Label("Delete Exercise", systemImage: "trash")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                }
                .foregroundStyle(.red)
            }
        }
        .spottrCard(padding: 14)
    }

    private var restDayCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "bed.double.fill")
                .font(.system(size: 36))
                .foregroundStyle(SpottrTheme.restColor)
                .padding(.top, 8)

            Text("Rest & Recovery")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(SpottrTheme.textPrimary)

            Text("Tap the dumbbell icon above to switch to a workout day.")
                .font(.system(size: 13))
                .foregroundStyle(SpottrTheme.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
        }
        .frame(maxWidth: .infinity)
        .spottrCard(padding: 24)
    }

    private func select(weekday: Weekday) {
        withAnimation(.spring(response: 0.3)) {
            store.selectedWeekday = weekday
            cancelExerciseEditing()
            focusedField = nil
        }
    }

    private func beginAddingExercise() {
        withAnimation(.spring(response: 0.3)) {
            editingExerciseID = nil
            isAddingExercise = true
            exerciseName = ""
            exerciseWeight = ""
            focusedField = .exerciseName
        }
    }

    private func beginEditing(_ exercise: ExerciseItem) {
        withAnimation(.spring(response: 0.3)) {
            isAddingExercise = false
            editingExerciseID = exercise.id
            exerciseName = exercise.name
            exerciseWeight = exercise.weight
            focusedField = .exerciseName
        }
    }

    private func saveExercise() {
        let trimmedName = exerciseName.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        if let exerciseID = editingExerciseID,
           var exercise = currentRoutine.exercises.first(where: { $0.id == exerciseID }) {
            exercise.name = trimmedName
            exercise.weight = exerciseWeight.trimmingCharacters(in: .whitespaces)
            store.updateExercise(weekday: store.selectedWeekday, exercise: exercise)
        } else {
            store.addExercise(to: store.selectedWeekday, name: trimmedName, weight: exerciseWeight)
        }
        cancelExerciseEditing()
    }

    private func cancelExerciseEditing() {
        withAnimation(.spring(response: 0.25)) {
            isAddingExercise = false
            editingExerciseID = nil
            exerciseName = ""
            exerciseWeight = ""
            if focusedField == .exerciseName || focusedField == .exerciseWeight {
                focusedField = nil
            }
        }
    }
}

#Preview {
    SplitView()
        .environmentObject(SpottrStore())
}
