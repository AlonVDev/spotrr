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
                                HStack {
                                    TextField("Exercise Name", text: $exercise.name)
                                        .font(.system(size: 15, weight: .bold, design: .rounded))
                                        .foregroundStyle(SpottrTheme.textPrimary)

                                    Spacer()

                                    HStack(spacing: 4) {
                                        TextField("Weight", text: $exercise.weight)
                                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                                            .foregroundStyle(SpottrTheme.accent)
                                            .multilineTextAlignment(.trailing)
                                            .frame(width: 60)

                                        Text(store.weightUnit.rawValue)
                                            .font(.system(size: 12, weight: .bold, design: .rounded))
                                            .foregroundStyle(SpottrTheme.textMuted)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                            .onDelete { offsets in
                                routine.exercises.remove(atOffsets: offsets)
                            }
                            .onMove { from, to in
                                routine.exercises.move(fromOffsets: from, toOffset: to)
                            }

                            // Add New Exercise Row
                            if showAddRow {
                                VStack(alignment: .leading, spacing: 10) {
                                    TextField("Exercise Name (e.g. Incline Bench)", text: $newExerciseName)
                                        .font(.system(size: 15, weight: .bold, design: .rounded))
                                        .foregroundStyle(SpottrTheme.textPrimary)

                                    HStack {
                                        TextField("Weight (\(store.weightUnit.rawValue))", text: $newExerciseWeight)
                                            .font(.system(size: 13, weight: .medium, design: .rounded))
                                            .keyboardType(.numbersAndPunctuation)

                                        Spacer()

                                        Button("Cancel") {
                                            withAnimation {
                                                newExerciseName = ""
                                                newExerciseWeight = ""
                                                showAddRow = false
                                            }
                                        }
                                        .font(.system(size: 13))
                                        .foregroundStyle(SpottrTheme.textMuted)

                                        Button("Add") {
                                            guard !newExerciseName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                                            routine.exercises.append(ExerciseItem(
                                                name: newExerciseName.trimmingCharacters(in: .whitespaces),
                                                weight: newExerciseWeight.trimmingCharacters(in: .whitespaces)
                                            ))
                                            newExerciseName = ""
                                            newExerciseWeight = ""
                                            showAddRow = false
                                        }
                                        .font(.system(size: 13, weight: .bold, design: .rounded))
                                        .foregroundStyle(.black)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 6)
                                        .background(SpottrTheme.accent)
                                        .clipShape(Capsule())
                                        .disabled(newExerciseName.trimmingCharacters(in: .whitespaces).isEmpty)
                                    }
                                }
                                .padding(.vertical, 6)
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
}
