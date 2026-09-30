//
//  ExerciseLibraryView.swift
//  spotrr
//
//  Created by Spottr on 28/08/2026.
//

import SwiftUI

// MARK: - Master Exercise Model (Dynamically Aggregated by Name)
struct MasterExercise: Identifiable {
    var id: String { name.trimmingCharacters(in: .whitespaces).lowercased() }
    var name: String
    var weight: String
    var reps: String
    var notes: String
    var usedInDays: [Weekday]
    var usedInRoutines: [String]

    var usedInLabel: String {
        let sortedDays = usedInDays.sorted()
        if sortedDays.isEmpty {
            return "Not currently assigned"
        }
        return "Used in: " + sortedDays.map { $0.fullName }.joined(separator: ", ")
    }
}

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
                    if existing.reps.isEmpty && !ex.reps.isEmpty {
                        existing.reps = ex.reps
                    }
                    if existing.notes.isEmpty && !ex.notes.isEmpty {
                        existing.notes = ex.notes
                    }
                    map[key] = existing
                } else {
                    map[key] = MasterExercise(
                        name: cleanName,
                        weight: ex.weight,
                        reps: ex.reps,
                        notes: ex.notes,
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
                                masterExerciseCard(exercise)
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
            EditLibraryExerciseSheet(exercise: exercise)
        }
        .sheet(isPresented: $showAddSheet) {
            AddLibraryExerciseSheet()
        }
    }

    private func masterExerciseCard(_ exercise: MasterExercise) -> some View {
        Button {
            editingMasterExercise = exercise
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .center) {
                    Text(exercise.name)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(SpottrTheme.textPrimary)

                    Spacer()

                    Image(systemName: "pencil")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(SpottrTheme.textMuted)
                }

                // Weight and reps
                let weightStr = exercise.weight.isEmpty ? nil : "\(exercise.weight) \(store.weightUnit.rawValue)"
                let repsStr = exercise.reps.isEmpty ? nil : "\(exercise.reps) reps"
                let detailParts = [weightStr, repsStr].compactMap { $0 }
                if !detailParts.isEmpty {
                    Text(detailParts.joined(separator: " • "))
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(SpottrTheme.textSecondary)
                }

                // Notes preview
                if !exercise.notes.isEmpty {
                    Text(exercise.notes)
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(SpottrTheme.textMuted)
                        .lineLimit(1)
                }

                // Used In: label
                Text(exercise.usedInLabel)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(SpottrTheme.accent.opacity(0.85))
                    .padding(.top, 2)
            }
            .padding(14)
            .background(SpottrTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(SpottrTheme.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
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

// MARK: - Edit Master Library Exercise Sheet

struct EditLibraryExerciseSheet: View {
    @EnvironmentObject var store: SpottrStore
    @Environment(\.dismiss) private var dismiss

    let exercise: MasterExercise

    @State private var name: String
    @State private var weight: String
    @State private var reps: String
    @State private var notes: String

    init(exercise: MasterExercise) {
        self.exercise = exercise
        self._name = State(initialValue: exercise.name)
        self._weight = State(initialValue: exercise.weight)
        self._reps = State(initialValue: exercise.reps)
        self._notes = State(initialValue: exercise.notes)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                SpottrTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Editable Fields
                        VStack(spacing: 12) {
                            fieldRow(label: "EXERCISE NAME", placeholder: "Exercise name", text: $name)
                            Divider().overlay(SpottrTheme.border)
                            fieldRow(label: "WEIGHT (\(store.weightUnit.rawValue))", placeholder: "e.g. 185", text: $weight, keyboard: .numbersAndPunctuation)
                            Divider().overlay(SpottrTheme.border)
                            fieldRow(label: "TARGET REPS", placeholder: "e.g. 8–10", text: $reps)
                            Divider().overlay(SpottrTheme.border)
                            fieldRow(label: "NOTES", placeholder: "e.g. Drop set on last set", text: $notes)
                        }
                        .spottrCard(padding: 16)

                        // Used-In Days info
                        VStack(alignment: .leading, spacing: 8) {
                            Text("USED IN")
                                .font(.system(size: 11, weight: .heavy, design: .rounded))
                                .foregroundStyle(SpottrTheme.textMuted)
                                .tracking(1.2)
                                .padding(.horizontal, 4)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(exercise.usedInDays.sorted()) { weekday in
                                        Text(weekday.fullName)
                                            .font(.system(size: 12, weight: .bold, design: .rounded))
                                            .foregroundStyle(SpottrTheme.accent)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(SpottrTheme.accent.opacity(0.12))
                                            .clipShape(Capsule())
                                    }
                                }
                            }
                            Text("Saving updates this exercise dynamically across every day listed above.")
                                .font(.system(size: 12))
                                .foregroundStyle(SpottrTheme.textMuted)
                                .padding(.horizontal, 4)
                        }

                        // Delete from All Days Button
                        Button(role: .destructive) {
                            store.deleteMasterExercise(name: exercise.name)
                            dismiss()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "trash")
                                Text("Delete from All Days")
                            }
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(SpottrTheme.card)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Color.red.opacity(0.3), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)

                        Spacer().frame(height: 20)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Edit Master Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(SpottrTheme.textMuted)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                        dismiss()
                    }
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(name.trimmingCharacters(in: .whitespaces).isEmpty ? SpottrTheme.textMuted : SpottrTheme.accent)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func fieldRow(label: String, placeholder: String, text: Binding<String>, keyboard: UIKeyboardType = .default) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .foregroundStyle(SpottrTheme.textMuted)
                .tracking(0.8)

            TextField(placeholder, text: text)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(SpottrTheme.textPrimary)
                .keyboardType(keyboard)
        }
    }

    private func saveChanges() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        store.updateMasterExercise(
            originalName: exercise.name,
            newName: trimmedName,
            weight: weight,
            reps: reps,
            notes: notes
        )
    }
}

// MARK: - Add Library Exercise Sheet

struct AddLibraryExerciseSheet: View {
    @EnvironmentObject var store: SpottrStore
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var weight = ""
    @State private var reps = ""
    @State private var notes = ""
    @State private var selectedDays: Set<Weekday> = []

    private var canAdd: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !selectedDays.isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                SpottrTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Exercise details
                        VStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("EXERCISE NAME")
                                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                                    .foregroundStyle(SpottrTheme.textMuted)
                                    .tracking(0.8)
                                TextField("e.g. Bench Press", text: $name)
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                                    .foregroundStyle(SpottrTheme.textPrimary)
                            }

                            Divider().overlay(SpottrTheme.border)

                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("WEIGHT (\(store.weightUnit.rawValue))")
                                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                                        .foregroundStyle(SpottrTheme.textMuted)
                                        .tracking(0.8)
                                    TextField("e.g. 185", text: $weight)
                                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                                        .foregroundStyle(SpottrTheme.textPrimary)
                                        .keyboardType(.numbersAndPunctuation)
                                }
                                Divider().overlay(SpottrTheme.border)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("REPS")
                                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                                        .foregroundStyle(SpottrTheme.textMuted)
                                        .tracking(0.8)
                                    TextField("e.g. 8–10", text: $reps)
                                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                                        .foregroundStyle(SpottrTheme.textPrimary)
                                }
                            }

                            Divider().overlay(SpottrTheme.border)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("NOTES")
                                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                                    .foregroundStyle(SpottrTheme.textMuted)
                                    .tracking(0.8)
                                TextField("e.g. 3 sets, RPE 8", text: $notes)
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                                    .foregroundStyle(SpottrTheme.textPrimary)
                            }
                        }
                        .spottrCard(padding: 16)

                        // Day picker
                        VStack(alignment: .leading, spacing: 8) {
                            Text("ADD TO DAYS")
                                .font(.system(size: 11, weight: .heavy, design: .rounded))
                                .foregroundStyle(SpottrTheme.textMuted)
                                .tracking(1.2)
                                .padding(.horizontal, 4)

                            VStack(spacing: 0) {
                                ForEach(store.orderedWeekdays) { weekday in
                                    let r = store.routine(for: weekday)
                                    if !r.isRestDay {
                                        let isSelected = selectedDays.contains(weekday)
                                        Button {
                                            if isSelected { selectedDays.remove(weekday) }
                                            else { selectedDays.insert(weekday) }
                                            store.triggerHaptic(.light)
                                        } label: {
                                            HStack {
                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text(weekday.fullName)
                                                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                                                        .foregroundStyle(SpottrTheme.textPrimary)
                                                    if !r.title.isEmpty {
                                                        Text(r.title)
                                                            .font(.system(size: 12, design: .rounded))
                                                            .foregroundStyle(SpottrTheme.textMuted)
                                                    }
                                                }
                                                Spacer()
                                                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                                    .foregroundStyle(isSelected ? SpottrTheme.accent : SpottrTheme.textMuted)
                                            }
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 12)
                                        }
                                        .buttonStyle(.plain)

                                        if weekday != store.orderedWeekdays.last {
                                            Divider().overlay(SpottrTheme.border).padding(.horizontal, 16)
                                        }
                                    }
                                }
                            }
                            .background(SpottrTheme.card)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(SpottrTheme.border, lineWidth: 1)
                            )
                        }

                        Button {
                            addExercise()
                            dismiss()
                        } label: {
                            Text("Add to Selected Days")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(canAdd ? SpottrTheme.accent : SpottrTheme.cardSubtle)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .disabled(!canAdd)

                        Spacer().frame(height: 20)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Add Master Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(SpottrTheme.textMuted)
                }
            }
        }
    }

    private func addExercise() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        for weekday in selectedDays {
            store.addExercise(
                to: weekday,
                name: trimmedName,
                weight: weight.trimmingCharacters(in: .whitespaces),
                reps: reps.trimmingCharacters(in: .whitespaces),
                notes: notes.trimmingCharacters(in: .whitespaces)
            )
        }
    }
}

#Preview {
    NavigationStack {
        ExerciseLibraryView()
            .environmentObject(SpottrStore())
    }
}
