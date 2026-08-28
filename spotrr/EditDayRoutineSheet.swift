//
//  EditDayRoutineSheet.swift
//  spotrr
//
//  Created by Spottr on 28/08/2026.
//

import SwiftUI

struct EditDayRoutineSheet: View {
    @EnvironmentObject var store: SpottrStore
    @Environment(\.dismiss) private var dismiss

    @State var routine: DayRoutine
    @State private var newExerciseName: String = ""
    @State private var newExerciseSets: Int = 3
    @State private var newExerciseReps: String = "8–10"
    @State private var newExerciseWeight: String = ""
    @State private var showAddRow: Bool = false

    var body: some View {
        NavigationStack {
            ZStack {
                SpottrTheme.background.ignoresSafeArea()

                Form {
                    // Day & Title Section
                    Section {
                        TextField("Workout Title (e.g. Chest & Triceps)", text: $routine.title)
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(SpottrTheme.textPrimary)

                        Toggle("Rest Day", isOn: $routine.isRestDay)
                            .tint(SpottrTheme.accent)
                    } header: {
                        Text("\(routine.weekday.fullName.uppercased()) ROUTINE")
                            .font(.system(size: 11, weight: .heavy, design: .rounded))
                            .foregroundStyle(SpottrTheme.textMuted)
                    }
                    .listRowBackground(SpottrTheme.card)

                    // Exercises Section
                    if !routine.isRestDay {
                        Section {
                            ForEach($routine.exercises) { $exercise in
                                exerciseEditRow(exercise: $exercise)
                            }
                            .onDelete { offsets in
                                routine.exercises.remove(atOffsets: offsets)
                            }
                            .onMove { from, to in
                                routine.exercises.move(fromOffsets: from, toOffset: to)
                            }

                            // Add New Exercise Row
                            if showAddRow {
                                newExerciseInlineForm
                            } else {
                                Button {
                                    withAnimation(.spring(response: 0.3)) {
                                        showAddRow = true
                                    }
                                } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: "plus.circle.fill")
                                        Text("Add Exercise")
                                            .font(.system(size: 15, weight: .bold, design: .rounded))
                                    }
                                    .foregroundStyle(SpottrTheme.accent)
                                }
                            }
                        } header: {
                            HStack {
                                Text("EXERCISES (\(routine.exercises.count))")
                                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                                    .foregroundStyle(SpottrTheme.textMuted)
                                Spacer()
                                EditButton()
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(SpottrTheme.accent)
                            }
                        }
                        .listRowBackground(SpottrTheme.card)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Edit \(routine.weekday.fullName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(SpottrTheme.textSecondary)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.updateRoutine(routine)
                        dismiss()
                    }
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(SpottrTheme.accent)
                }
            }
        }
    }

    // MARK: - Exercise Edit Row
    private func exerciseEditRow(exercise: Binding<ExerciseItem>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField("Exercise Name", text: exercise.name)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(SpottrTheme.textPrimary)

            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    Text("Sets:")
                        .font(.system(size: 12))
                        .foregroundStyle(SpottrTheme.textMuted)
                    Stepper("\(exercise.wrappedValue.sets)", value: exercise.sets, in: 1...20)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                }

                HStack(spacing: 4) {
                    Text("Reps:")
                        .font(.system(size: 12))
                        .foregroundStyle(SpottrTheme.textMuted)
                    TextField("8–10", text: exercise.reps)
                        .font(.system(size: 12, weight: .medium))
                        .frame(width: 50)
                }

                HStack(spacing: 4) {
                    Text("Lbs:")
                        .font(.system(size: 12))
                        .foregroundStyle(SpottrTheme.textMuted)
                    TextField("Weight", text: exercise.weight)
                        .font(.system(size: 12, weight: .medium))
                        .frame(width: 50)
                }
            }
            .foregroundStyle(SpottrTheme.textSecondary)
        }
        .padding(.vertical, 4)
    }

    // MARK: - New Exercise Form
    private var newExerciseInlineForm: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Exercise Name (e.g. Incline Bench)", text: $newExerciseName)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(SpottrTheme.textPrimary)

            HStack(spacing: 12) {
                Stepper("Sets: \(newExerciseSets)", value: $newExerciseSets, in: 1...20)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))

                TextField("Reps (e.g. 10)", text: $newExerciseReps)
                    .font(.system(size: 12))
                    .frame(width: 70)

                TextField("Lbs", text: $newExerciseWeight)
                    .font(.system(size: 12))
                    .frame(width: 60)
            }
            .foregroundStyle(SpottrTheme.textSecondary)

            HStack {
                Button("Cancel") {
                    withAnimation {
                        resetNewExerciseForm()
                    }
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(SpottrTheme.textMuted)

                Spacer()

                Button("Add to Split") {
                    guard !newExerciseName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                    let item = ExerciseItem(
                        name: newExerciseName,
                        sets: newExerciseSets,
                        reps: newExerciseReps.isEmpty ? "10" : newExerciseReps,
                        weight: newExerciseWeight
                    )
                    routine.exercises.append(item)
                    resetNewExerciseForm()
                }
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.black)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(SpottrTheme.accent)
                .clipShape(Capsule())
                .disabled(newExerciseName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.top, 4)
        }
        .padding(.vertical, 6)
    }

    private func resetNewExerciseForm() {
        newExerciseName = ""
        newExerciseSets = 3
        newExerciseReps = "8–10"
        newExerciseWeight = ""
        showAddRow = false
    }
}

