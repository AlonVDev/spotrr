//
//  ExerciseFormView.swift
//  spotrr
//
//  Created by Spottr on 11/10/2026.
//

import SwiftUI

struct ExerciseFormView: View {
    @EnvironmentObject var store: SpottrStore
    @Environment(\.dismiss) private var dismiss

    /// Mode detection: If nil, mode is "Add New Exercise"; if present, mode is "Edit Exercise".
    let exerciseToEdit: MasterExercise?

    // Form inputs
    @State private var name: String = ""
    @State private var weight: String = ""
    @State private var sets: String = "3"
    @State private var reps: String = "8–10"
    @State private var notes: String = ""
    @State private var customVariables: [ExerciseCustomVariable] = []
    @State private var selectedDays: Set<Weekday> = []

    init(exerciseToEdit: MasterExercise? = nil) {
        self.exerciseToEdit = exerciseToEdit
        if let ex = exerciseToEdit {
            _name = State(initialValue: ex.name)
            _weight = State(initialValue: ex.weight)
            _sets = State(initialValue: ex.sets.isEmpty ? "3" : ex.sets)
            _reps = State(initialValue: ex.reps.isEmpty ? "8–10" : ex.reps)
            _notes = State(initialValue: ex.notes)
            _customVariables = State(initialValue: ex.customVariables)
            _selectedDays = State(initialValue: Set(ex.usedInDays))
        } else {
            _name = State(initialValue: "")
            _weight = State(initialValue: "")
            _sets = State(initialValue: "3")
            _reps = State(initialValue: "8–10")
            _notes = State(initialValue: "")
            _customVariables = State(initialValue: [])
            _selectedDays = State(initialValue: [Weekday.today()])
        }
    }

    private var isEditMode: Bool {
        exerciseToEdit != nil
    }

    private var canSubmit: Bool {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return false }
        if !isEditMode && selectedDays.isEmpty { return false }
        return true
    }

    // Live computed summary line for preview
    private var liveSummaryLine: String {
        let dummyItem = ExerciseItem(
            name: name,
            weight: weight,
            sets: sets,
            reps: reps,
            notes: notes,
            customVariables: customVariables
        )
        return dummyItem.summaryLine(unit: store.weightUnit)
    }

    private var liveWorkingWeight: String {
        let trimmed = weight.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return "" }
        if trimmed.hasSuffix("lbs") || trimmed.hasSuffix("kg") {
            return trimmed
        }
        return "\(trimmed) \(store.weightUnit.rawValue)"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                SpottrTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // MARK: - Live Preview Card (Compact Layout)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("PREVIEW")
                                .font(.system(size: 11, weight: .heavy, design: .rounded))
                                .foregroundStyle(SpottrTheme.textMuted)
                                .tracking(1.2)
                                .padding(.horizontal, 4)

                            CompactExerciseCardView(
                                name: name.isEmpty ? "Exercise Name" : name,
                                workingWeight: liveWorkingWeight,
                                summaryLine: liveSummaryLine,
                                notes: notes,
                                isCompleted: false,
                                showCheckbox: false
                            )
                        }

                        // MARK: - Core Exercise Details
                        VStack(alignment: .leading, spacing: 8) {
                            Text("EXERCISE DETAILS")
                                .font(.system(size: 11, weight: .heavy, design: .rounded))
                                .foregroundStyle(SpottrTheme.textMuted)
                                .tracking(1.2)
                                .padding(.horizontal, 4)

                            VStack(spacing: 12) {
                                // Exercise Name
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("EXERCISE NAME")
                                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                                        .foregroundStyle(SpottrTheme.textMuted)
                                        .tracking(0.8)
                                    TextField("e.g. Incline DB Bench Press", text: $name)
                                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                                        .foregroundStyle(SpottrTheme.textPrimary)
                                }

                                Divider().overlay(SpottrTheme.border)

                                // Weight, Sets, Reps Row
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("WORKING WEIGHT")
                                            .font(.system(size: 10, weight: .heavy, design: .rounded))
                                            .foregroundStyle(SpottrTheme.textMuted)
                                            .tracking(0.8)
                                        HStack(spacing: 4) {
                                            TextField("185", text: $weight)
                                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                                .foregroundStyle(SpottrTheme.textPrimary)
                                                .keyboardType(.numbersAndPunctuation)
                                            Text(store.weightUnit.rawValue)
                                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                                .foregroundStyle(SpottrTheme.textMuted)
                                        }
                                    }

                                    Divider().overlay(SpottrTheme.border)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("SETS")
                                            .font(.system(size: 10, weight: .heavy, design: .rounded))
                                            .foregroundStyle(SpottrTheme.textMuted)
                                            .tracking(0.8)
                                        TextField("3", text: $sets)
                                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                                            .foregroundStyle(SpottrTheme.textPrimary)
                                    }

                                    Divider().overlay(SpottrTheme.border)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("REPS")
                                            .font(.system(size: 10, weight: .heavy, design: .rounded))
                                            .foregroundStyle(SpottrTheme.textMuted)
                                            .tracking(0.8)
                                        TextField("8–10", text: $reps)
                                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                                            .foregroundStyle(SpottrTheme.textPrimary)
                                    }
                                }

                                Divider().overlay(SpottrTheme.border)

                                // Personal Notes
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("PERSONAL NOTES")
                                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                                        .foregroundStyle(SpottrTheme.textMuted)
                                        .tracking(0.8)
                                    TextField("e.g. Pause 1s at bottom, drop set on last set", text: $notes)
                                        .font(.system(size: 14, weight: .medium, design: .rounded))
                                        .foregroundStyle(SpottrTheme.textPrimary)
                                }
                            }
                            .spottrCard(padding: 16)
                        }

                        // MARK: - Dynamic Custom Info Variables
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("CUSTOM INFO VARIABLES")
                                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                                    .foregroundStyle(SpottrTheme.textMuted)
                                    .tracking(1.2)

                                Spacer()

                                Button {
                                    withAnimation(.spring(response: 0.3)) {
                                        customVariables.append(ExerciseCustomVariable(name: "", value: "", unit: "free text"))
                                    }
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "plus")
                                            .font(.system(size: 11, weight: .bold))
                                        Text("Add Variable")
                                            .font(.system(size: 12, weight: .bold, design: .rounded))
                                    }
                                    .foregroundStyle(SpottrTheme.accent)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 4)

                            // Quick suggestion chips
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    suggestionChip(title: "+ Seat Height", name: "Seat Height", unit: "free text")
                                    suggestionChip(title: "+ Target RPE", name: "Target RPE", unit: "RPE")
                                    suggestionChip(title: "+ Warmup Strategy", name: "Warmup Strategy", unit: "free text")
                                    suggestionChip(title: "+ Rest Time", name: "Rest Time", unit: "free text")
                                }
                                .padding(.horizontal, 4)
                            }

                            if customVariables.isEmpty {
                                Text("No custom variables added. Tap suggestions above or 'Add Variable' to track seat height, RPE, tempo, warmup sets, etc.")
                                    .font(.system(size: 12, design: .rounded))
                                    .foregroundStyle(SpottrTheme.textMuted)
                                    .padding(14)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(SpottrTheme.card)
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .stroke(SpottrTheme.border, lineWidth: 1)
                                    )
                            } else {
                                VStack(spacing: 10) {
                                    ForEach(Array(customVariables.enumerated()), id: \.element.id) { index, item in
                                        customVariableRow(index: index)
                                    }
                                }
                            }
                        }

                        // MARK: - Mode Specific Section
                        if isEditMode, let ex = exerciseToEdit {
                            // Used-in Info
                            VStack(alignment: .leading, spacing: 8) {
                                Text("SCHEDULE USAGE")
                                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                                    .foregroundStyle(SpottrTheme.textMuted)
                                    .tracking(1.2)
                                    .padding(.horizontal, 4)

                                Text(ex.usedInLabel)
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundStyle(SpottrTheme.accent)
                                    .padding(14)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(SpottrTheme.card)
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .stroke(SpottrTheme.border, lineWidth: 1)
                                    )

                                Text("Saving updates this exercise dynamically across all scheduled days and routine links.")
                                    .font(.system(size: 12))
                                    .foregroundStyle(SpottrTheme.textMuted)
                                    .padding(.horizontal, 4)
                            }

                            // Delete from All Days Button
                            Button(role: .destructive) {
                                store.deleteMasterExercise(name: ex.name)
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
                        } else {
                            // Add to Days Picker
                            VStack(alignment: .leading, spacing: 8) {
                                Text("ASSIGN TO DAYS")
                                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                                    .foregroundStyle(SpottrTheme.textMuted)
                                    .tracking(1.2)
                                    .padding(.horizontal, 4)

                                VStack(spacing: 0) {
                                    ForEach(store.orderedWeekdays) { weekday in
                                        let r = store.routine(for: weekday)
                                        let isSelected = selectedDays.contains(weekday)

                                        Button {
                                            if isSelected {
                                                selectedDays.remove(weekday)
                                            } else {
                                                selectedDays.insert(weekday)
                                            }
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
                                                    .font(.system(size: 20))
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
                                .background(SpottrTheme.card)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(SpottrTheme.border, lineWidth: 1)
                                )
                            }
                        }

                        // Submit Button
                        Button {
                            submitForm()
                        } label: {
                            Text(isEditMode ? "Save Changes" : "Add to Split")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(canSubmit ? SpottrTheme.accent : SpottrTheme.cardSubtle)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .disabled(!canSubmit)

                        Spacer().frame(height: 20)
                    }
                    .padding(16)
                }
            }
            .navigationTitle(isEditMode ? "Edit Exercise" : "Add New Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(SpottrTheme.textMuted)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditMode ? "Save" : "Add") {
                        submitForm()
                    }
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(canSubmit ? SpottrTheme.accent : SpottrTheme.textMuted)
                    .disabled(!canSubmit)
                }
            }
        }
    }

    // MARK: - Custom Variable Components

    private func suggestionChip(title: String, name: String, unit: String) -> some View {
        Button {
            withAnimation(.spring(response: 0.3)) {
                customVariables.append(ExerciseCustomVariable(name: name, value: "", unit: unit))
            }
            store.triggerHaptic(.light)
        } label: {
            Text(title)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(SpottrTheme.accent)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(SpottrTheme.accent.opacity(0.12))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func customVariableRow(index: Int) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                // Name field
                TextField("Variable Name (e.g. Seat)", text: $customVariables[index].name)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(SpottrTheme.textPrimary)
                    .padding(8)
                    .background(SpottrTheme.cardSubtle)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                // Delete button
                Button {
                    withAnimation(.spring(response: 0.25)) {
                        customVariables.remove(at: index)
                    }
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 13))
                        .foregroundStyle(.red.opacity(0.8))
                        .padding(8)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 8) {
                // Value field
                TextField("Value (e.g. 4)", text: $customVariables[index].value)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(SpottrTheme.textPrimary)
                    .padding(8)
                    .background(SpottrTheme.cardSubtle)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                // Unit Picker Menu
                Menu {
                    ForEach(ExerciseCustomVariable.unitOptions, id: \.self) { opt in
                        Button(opt) {
                            customVariables[index].unit = opt
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(customVariables[index].unit)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 10))
                    }
                    .foregroundStyle(SpottrTheme.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(SpottrTheme.cardSubtle)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding(12)
        .background(SpottrTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(SpottrTheme.border, lineWidth: 1)
        )
    }

    // MARK: - Submission

    private func submitForm() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        let cleanVars = customVariables.filter {
            !$0.name.trimmingCharacters(in: .whitespaces).isEmpty ||
            !$0.value.trimmingCharacters(in: .whitespaces).isEmpty
        }

        if let existing = exerciseToEdit {
            store.updateMasterExercise(
                originalName: existing.name,
                newName: trimmedName,
                weight: weight,
                sets: sets,
                reps: reps,
                notes: notes,
                customVariables: cleanVars
            )
        } else {
            for day in selectedDays {
                store.addExercise(
                    to: day,
                    name: trimmedName,
                    weight: weight,
                    sets: sets,
                    reps: reps,
                    notes: notes,
                    customVariables: cleanVars
                )
            }
        }

        dismiss()
    }
}

#Preview {
    ExerciseFormView()
        .environmentObject(SpottrStore())
}
