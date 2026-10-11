//
//  ImportSplitSheet.swift
//  spotrr
//
//  Created by Spottr on 11/10/2026.
//

import SwiftUI

enum ImportSourceType: String, CaseIterable, Identifiable {
    case friend = "From Buddy"
    case text = "From Notes"
    case fileOrCode = "File / Code"

    var id: String { rawValue }
}

struct ImportSplitSheet: View {
    @EnvironmentObject var store: SpottrStore
    @Environment(\.dismiss) private var dismiss

    @State private var selectedSource: ImportSourceType = .friend

    // Text import input
    @State private var notesText: String = ""

    // Code / JSON import input
    @State private var codeText: String = ""

    // Parsed preview state
    @State private var parsedSplitName: String = ""
    @State private var previewRoutines: [Weekday: DayRoutine]? = nil
    @State private var selectedBuddyName: String? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                SpottrTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Source Picker
                        Picker("Import Source", selection: $selectedSource) {
                            ForEach(ImportSourceType.allCases) { src in
                                Text(src.rawValue).tag(src)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal, 4)

                        // Source Input Section
                        switch selectedSource {
                        case .friend:
                            friendSourceSection
                        case .text:
                            textSourceSection
                        case .fileOrCode:
                            codeSourceSection
                        }

                        // Preview Section (if parsed)
                        if let routines = previewRoutines {
                            previewSection(routines)
                        }

                        Spacer().frame(height: 30)
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Import Split")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(SpottrTheme.textMuted)
                }
            }
            .onAppear {
                if let firstBuddy = store.buddies.first {
                    loadBuddyPreview(firstBuddy)
                }
            }
        }
    }

    // MARK: - Source 1: Friend / Buddy
    private var friendSourceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("SELECT A BUDDY TO CLONE")
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .foregroundStyle(SpottrTheme.textMuted)
                .tracking(1.2)
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                ForEach(store.buddies) { buddy in
                    let isSelected = selectedBuddyName == buddy.name
                    Button {
                        loadBuddyPreview(buddy)
                    } label: {
                        HStack(spacing: 12) {
                            // Avatar initials
                            Text(buddy.initials)
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(isSelected ? .black : SpottrTheme.accent)
                                .frame(width: 38, height: 38)
                                .background(isSelected ? SpottrTheme.accent : SpottrTheme.accent.opacity(0.12))
                                .clipShape(Circle())

                            VStack(alignment: .leading, spacing: 2) {
                                Text(buddy.name)
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                                    .foregroundStyle(SpottrTheme.textPrimary)

                                Text(buddy.splitTitle)
                                    .font(.system(size: 12, design: .rounded))
                                    .foregroundStyle(SpottrTheme.textMuted)
                            }

                            Spacer()

                            Image(systemName: isSelected ? "checkmark.circle.fill" : "chevron.right")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(isSelected ? SpottrTheme.accent : SpottrTheme.textMuted)
                        }
                        .padding(14)
                    }
                    .buttonStyle(.plain)

                    if buddy.id != store.buddies.last?.id {
                        Divider().overlay(SpottrTheme.border).padding(.horizontal, 14)
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

    private func loadBuddyPreview(_ buddy: FriendStatus) {
        selectedBuddyName = buddy.name
        let result = store.generateBuddySplit(for: buddy.name, splitTitle: buddy.splitTitle)
        parsedSplitName = result.name
        previewRoutines = result.routines
        store.triggerHaptic(.light)
    }

    // MARK: - Source 2: Notes / Plain Text
    private var textSourceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("PASTE NOTES OR SCHEDULE")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundStyle(SpottrTheme.textMuted)
                    .tracking(1.2)

                Spacer()

                Button("Paste Example") {
                    notesText = """
                    Mon: Push Day
                    - Bench Press: 185 lbs 3x8 (Drop set on last set)
                    - Incline DB Press: 65 lbs 3x10
                    - Lateral Raises: 25 lbs 4x15
                    Tue: Pull Day
                    - Pull-ups: BW 3x10
                    - Barbell Row: 155 lbs 4x8
                    - Bicep Curls: 30 lbs 3x12
                    Wed: Rest Day
                    Thu: Leg Day
                    - Squats: 225 lbs 4x6
                    - Romanian Deadlift: 185 lbs 3x10
                    Fri: Upper Body
                    - Overhead Press: 105 lbs 3x8
                    - Lat Pulldown: 130 lbs 3x10
                    Sat: Rest Day
                    Sun: Rest Day
                    """
                    parseTextSchedule()
                }
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(SpottrTheme.accent)
            }
            .padding(.horizontal, 4)

            ZStack(alignment: .topLeading) {
                if notesText.isEmpty {
                    Text("e.g.\nMonday: Chest & Triceps\n- Bench Press: 185 lbs 3x8\n- Incline DB: 60 lbs 3x10\nTuesday: Back & Biceps\nWednesday: Rest Day...")
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(SpottrTheme.textMuted)
                        .padding(14)
                }

                TextEditor(text: $notesText)
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(SpottrTheme.textPrimary)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 140)
                    .padding(10)
            }
            .background(SpottrTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(SpottrTheme.border, lineWidth: 1)
            )

            Button {
                parseTextSchedule()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                    Text("Parse & Preview Schedule")
                }
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(notesText.trimmingCharacters(in: .whitespaces).isEmpty ? SpottrTheme.cardSubtle : SpottrTheme.accent)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(notesText.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    private func parseTextSchedule() {
        let parsed = store.parseScheduleFromText(notesText)
        parsedSplitName = parsed.name
        previewRoutines = parsed.routines
        store.triggerHaptic(.medium)
    }

    // MARK: - Source 3: File / JSON Code
    private var codeSourceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("PASTE SPOTTR JSON / CODE")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundStyle(SpottrTheme.textMuted)
                    .tracking(1.2)

                Spacer()

                Button("Paste Current JSON") {
                    codeText = store.exportCurrentSplitAsJSON()
                    parseCodeSchedule()
                }
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(SpottrTheme.accent)
            }
            .padding(.horizontal, 4)

            ZStack(alignment: .topLeading) {
                if codeText.isEmpty {
                    Text("Paste Spottr JSON schema or deep link invite string here...")
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(SpottrTheme.textMuted)
                        .padding(14)
                }

                TextEditor(text: $codeText)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(SpottrTheme.textPrimary)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 120)
                    .padding(10)
            }
            .background(SpottrTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(SpottrTheme.border, lineWidth: 1)
            )

            Button {
                parseCodeSchedule()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "curlybraces")
                    Text("Parse JSON / Code")
                }
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(codeText.trimmingCharacters(in: .whitespaces).isEmpty ? SpottrTheme.cardSubtle : SpottrTheme.accent)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(codeText.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    private func parseCodeSchedule() {
        if let parsed = store.parseSplitFromJSON(codeText) {
            parsedSplitName = parsed.name
            previewRoutines = parsed.routines
            store.triggerHaptic(.medium)
        }
    }

    // MARK: - Preview & Apply Section
    private func previewSection(_ routines: [Weekday: DayRoutine]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Divider().overlay(SpottrTheme.border).padding(.vertical, 6)

            HStack {
                Text("IMPORT PREVIEW")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundStyle(SpottrTheme.textMuted)
                    .tracking(1.2)

                Spacer()

                Text(parsedSplitName)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(SpottrTheme.accent)
            }
            .padding(.horizontal, 4)

            // Weekly day breakdown
            VStack(spacing: 8) {
                ForEach(store.orderedWeekdays) { weekday in
                    let routine = routines[weekday] ?? DayRoutine(weekday: weekday, title: "", isRestDay: true, exercises: [])
                    dayPreviewRow(weekday: weekday, routine: routine)
                }
            }

            // Action Buttons
            VStack(spacing: 10) {
                Button {
                    store.applyImportedSplit(
                        name: parsedSplitName,
                        routines: routines,
                        asNewProfile: false
                    )
                    dismiss()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Apply to Current Split")
                    }
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(SpottrTheme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)

                Button {
                    store.applyImportedSplit(
                        name: parsedSplitName,
                        routines: routines,
                        asNewProfile: true
                    )
                    dismiss()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.rectangle.on.rectangle")
                        Text("Save as New Split Profile")
                    }
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(SpottrTheme.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(SpottrTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(SpottrTheme.border, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 8)
        }
    }

    private func dayPreviewRow(weekday: Weekday, routine: DayRoutine) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(weekday.fullName)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(SpottrTheme.textPrimary)

                Spacer()

                if routine.isRestDay {
                    Text("Rest Day")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(SpottrTheme.textMuted)
                } else {
                    Text(routine.title.isEmpty ? "Workout" : routine.title)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(SpottrTheme.accent)
                }
            }

            if !routine.isRestDay && !routine.exercises.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(routine.exercises.prefix(4)) { ex in
                        HStack(spacing: 6) {
                            Circle().fill(SpottrTheme.accent).frame(width: 4, height: 4)
                            Text(ex.name)
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(SpottrTheme.textSecondary)

                            Spacer()

                            let detail = ex.summaryLine(unit: store.weightUnit)
                            let weightStr = ex.formattedWorkingWeight(unit: store.weightUnit)
                            let combined = [weightStr, detail].filter { !$0.isEmpty }.joined(separator: " • ")
                            if !combined.isEmpty {
                                Text(combined)
                                    .font(.system(size: 11, design: .rounded))
                                    .foregroundStyle(SpottrTheme.textMuted)
                            }
                        }
                    }
                    if routine.exercises.count > 4 {
                        Text("+ \(routine.exercises.count - 4) more exercises")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(SpottrTheme.textMuted)
                            .padding(.top, 1)
                    }
                }
                .padding(.top, 2)
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
}

#Preview {
    NavigationStack {
        ImportSplitSheet()
            .environmentObject(SpottrStore())
    }
}
