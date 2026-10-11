//
//  ExerciseLibraryView.swift
//  spotrr
//
//  Created by Spottr on 28/08/2026.
//

import SwiftUI

struct ExerciseLibraryView: View {
    @EnvironmentObject var store: SpottrStore
    @State private var searchText = ""
    @State private var editingMasterExercise: MasterExercise? = nil
    @State private var showAddSheet = false

    /// Dynamically aggregates all exercises across every day in the schedule into unique master entries.
    private var allMasterExercises: [MasterExercise] {
        var map: [String: MasterExercise] = [:]

        for weekday in store.orderedWeekdays {
            let routine = store.routine(for: weekday)
            guard !routine.isRestDay else { continue }

            let routineTitle = routine.title.trimmingCharacters(in: .whitespaces).isEmpty ? weekday.fullName : routine.title

            for ex in routine.exercises {
                let cleanName = ex.name.trimmingCharacters(in: .whitespaces)
                let key = cleanName.lowercased()
                guard !key.isEmpty else { continue }

                if var existing = map[key] {
                    if !existing.usedInDays.contains(weekday) {
                        existing.usedInDays.append(weekday)
                    }
                    if !existing.usedInRoutines.contains(routineTitle) {
                        existing.usedInRoutines.append(routineTitle)
                    }
                    if existing.weight.isEmpty && !ex.weight.isEmpty {
                        existing.weight = ex.weight
                    }
                    if existing.sets.isEmpty && !ex.sets.isEmpty {
                        existing.sets = ex.sets
                    }
                    if existing.reps.isEmpty && !ex.reps.isEmpty {
                        existing.reps = ex.reps
                    }
                    if existing.notes.isEmpty && !ex.notes.isEmpty {
                        existing.notes = ex.notes
                    }
                    if existing.customVariables.isEmpty && !ex.customVariables.isEmpty {
                        existing.customVariables = ex.customVariables
                    }
                    map[key] = existing
                } else {
                    map[key] = MasterExercise(
                        name: cleanName,
                        weight: ex.weight,
                        sets: ex.sets,
                        reps: ex.reps,
                        notes: ex.notes,
                        customVariables: ex.customVariables,
                        usedInDays: [weekday],
                        usedInRoutines: [routineTitle]
                    )
                }
            }
        }

        return map.values.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var filteredExercises: [MasterExercise] {
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        if query.isEmpty {
            return allMasterExercises
        }
        return allMasterExercises.filter { ex in
            ex.name.lowercased().contains(query) ||
            ex.usedInDays.contains { $0.fullName.lowercased().contains(query) || $0.shortName.lowercased().contains(query) }
        }
    }

    var body: some View {
        ZStack {
            SpottrTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Search bar
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(SpottrTheme.textMuted)

                    TextField("Search exercises or days...", text: $searchText)
                        .font(.system(size: 15, design: .rounded))
                        .foregroundStyle(SpottrTheme.textPrimary)

                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(SpottrTheme.textMuted)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(12)
                .background(SpottrTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(SpottrTheme.border, lineWidth: 1)
                )
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)

                if filteredExercises.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(filteredExercises) { exercise in
                                VStack(alignment: .leading, spacing: 4) {
                                    CompactExerciseCardView(
                                        name: exercise.name,
                                        workingWeight: exercise.formattedWorkingWeight(unit: store.weightUnit),
                                        summaryLine: exercise.summaryLine(unit: store.weightUnit),
                                        notes: exercise.notes,
                                        isCompleted: false,
                                        showCheckbox: false,
                                        onEdit: {
                                            editingMasterExercise = exercise
                                        }
                                    )

                                    // Used In Label below card
                                    Text(exercise.usedInLabel)
                                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                                        .foregroundStyle(SpottrTheme.accent.opacity(0.85))
                                        .padding(.horizontal, 6)
                                }
                            }
                            Spacer().frame(height: 40)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 4)
                    }
                }
            }
        }
        .navigationTitle("Exercise Library")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showAddSheet = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(SpottrTheme.accent)
                }
            }
        }
        .sheet(item: $editingMasterExercise) { exercise in
            ExerciseFormView(exerciseToEdit: exercise)
        }
        .sheet(isPresented: $showAddSheet) {
            ExerciseFormView(exerciseToEdit: nil)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "dumbbell")
                .font(.system(size: 44))
                .foregroundStyle(SpottrTheme.accent.opacity(0.4))

            if searchText.isEmpty {
                Text("No Exercises Yet")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(SpottrTheme.textPrimary)

                Text("Exercises you add to any workout day will automatically appear in your master library.")
                    .font(.system(size: 14))
                    .foregroundStyle(SpottrTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            } else {
                Text("No Results")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(SpottrTheme.textPrimary)

                Text("No exercises match \"\(searchText)\"")
                    .font(.system(size: 14))
                    .foregroundStyle(SpottrTheme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, 60)
    }
}

#Preview {
    NavigationStack {
        ExerciseLibraryView()
            .environmentObject(SpottrStore())
    }
}
