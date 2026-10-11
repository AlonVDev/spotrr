//
//  SplitModels.swift
//  spotrr
//
//  Created by Spottr on 28/08/2026.
//

import SwiftUI

// MARK: - Weight Unit
enum WeightUnit: String, CaseIterable, Codable, Identifiable {
    case lbs = "lbs"
    case kg = "kg"

    var id: String { rawValue }
    var uppercaseName: String { rawValue.uppercased() }
}

// MARK: - Week Start Order
enum WeekStart: String, CaseIterable, Codable, Identifiable {
    case monday = "MON"
    case sunday = "SUN"

    var id: String { rawValue }

    var orderedWeekdays: [Weekday] {
        switch self {
        case .monday:
            return [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday]
        case .sunday:
            return [.sunday, .monday, .tuesday, .wednesday, .thursday, .friday, .saturday]
        }
    }
}

// MARK: - Weekday
enum Weekday: Int, CaseIterable, Codable, Identifiable, Comparable {
    case monday = 2
    case tuesday = 3
    case wednesday = 4
    case thursday = 5
    case friday = 6
    case saturday = 7
    case sunday = 1

    var id: Int { rawValue }

    static func < (lhs: Weekday, rhs: Weekday) -> Bool {
        lhs.sortIndex < rhs.sortIndex
    }

    var sortIndex: Int {
        switch self {
        case .monday: return 0
        case .tuesday: return 1
        case .wednesday: return 2
        case .thursday: return 3
        case .friday: return 4
        case .saturday: return 5
        case .sunday: return 6
        }
    }

    var shortName: String {
        switch self {
        case .monday: return "Mon"
        case .tuesday: return "Tue"
        case .wednesday: return "Wed"
        case .thursday: return "Thu"
        case .friday: return "Fri"
        case .saturday: return "Sat"
        case .sunday: return "Sun"
        }
    }

    var fullName: String {
        switch self {
        case .monday: return "Monday"
        case .tuesday: return "Tuesday"
        case .wednesday: return "Wednesday"
        case .thursday: return "Thursday"
        case .friday: return "Friday"
        case .saturday: return "Saturday"
        case .sunday: return "Sunday"
        }
    }

    var singleLetter: String {
        String(shortName.prefix(1))
    }

    static func today() -> Weekday {
        let calendar = Calendar.current
        let weekdayInt = calendar.component(.weekday, from: Date())
        return Weekday(rawValue: weekdayInt) ?? .monday
    }
}

// MARK: - Custom Info Variable
struct ExerciseCustomVariable: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String = ""         // e.g. "Seat Height", "Target RPE", "Warmup Strategy"
    var value: String = ""        // e.g. "4", "8.5", "12×40k, 6×60k"
    var unit: String = "free text" // e.g. "free text", "% of weight", "inches/cm", "reps", "kg/lbs"

    static let unitOptions = [
        "free text",
        "% of weight",
        "inches/cm",
        "reps",
        "kg/lbs",
        "RPE"
    ]
}

// MARK: - Exercise Item
struct ExerciseItem: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var weight: String = "" // e.g. "185"
    var sets: String = ""   // e.g. "3"
    var reps: String = ""   // e.g. "8–10"
    var notes: String = ""  // e.g. "Drop set on last set"
    var customVariables: [ExerciseCustomVariable] = []
    var isCompleted: Bool = false

    enum CodingKeys: CodingKey {
        case id, name, weight, sets, reps, notes, customVariables, isCompleted
    }

    init(
        id: UUID = UUID(),
        name: String,
        weight: String = "",
        sets: String = "",
        reps: String = "",
        notes: String = "",
        customVariables: [ExerciseCustomVariable] = [],
        isCompleted: Bool = false
    ) {
        self.id = id
        self.name = name
        self.weight = weight
        self.sets = sets
        self.reps = reps
        self.notes = notes
        self.customVariables = customVariables
        self.isCompleted = isCompleted
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decode(String.self, forKey: .name)
        weight = try container.decodeIfPresent(String.self, forKey: .weight) ?? ""
        sets = try container.decodeIfPresent(String.self, forKey: .sets) ?? ""
        reps = try container.decodeIfPresent(String.self, forKey: .reps) ?? ""
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        customVariables = try container.decodeIfPresent([ExerciseCustomVariable].self, forKey: .customVariables) ?? []
        isCompleted = try container.decodeIfPresent(Bool.self, forKey: .isCompleted) ?? false
    }

    /// Formats the centered summary line: "3 × 8–10 • 🔥 12×40k, 6×60k • ⚙️ Seat 4"
    func summaryLine(unit: WeightUnit) -> String {
        var parts: [String] = []

        let trimmedSets = sets.trimmingCharacters(in: .whitespaces)
        let trimmedReps = reps.trimmingCharacters(in: .whitespaces)
        if !trimmedSets.isEmpty && !trimmedReps.isEmpty {
            parts.append("\(trimmedSets) × \(trimmedReps)")
        } else if !trimmedSets.isEmpty {
            parts.append("\(trimmedSets) sets")
        } else if !trimmedReps.isEmpty {
            parts.append("\(trimmedReps) reps")
        }

        for v in customVariables {
            let n = v.name.trimmingCharacters(in: .whitespaces)
            let val = v.value.trimmingCharacters(in: .whitespaces)
            let u = v.unit.trimmingCharacters(in: .whitespaces)
            guard !val.isEmpty || !n.isEmpty else { continue }

            let unitSuffix = (u == "free text" || u.isEmpty) ? "" : (u.hasPrefix("%") ? u : " \(u)")

            if n.localizedCaseInsensitiveContains("warmup") {
                parts.append("🔥 \(val)\(unitSuffix)")
            } else if n.localizedCaseInsensitiveContains("seat") {
                parts.append("⚙️ \(n) \(val)\(unitSuffix)")
            } else if n.localizedCaseInsensitiveContains("rpe") {
                parts.append("🎯 RPE \(val)")
            } else if n.isEmpty {
                parts.append("\(val)\(unitSuffix)")
            } else {
                parts.append("\(n): \(val)\(unitSuffix)")
            }
        }

        return parts.joined(separator: " • ")
    }

    func formattedWorkingWeight(unit: WeightUnit) -> String {
        let trimmed = weight.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return "" }
        if trimmed.hasSuffix("lbs") || trimmed.hasSuffix("kg") {
            return trimmed
        }
        return "\(trimmed) \(unit.rawValue)"
    }

    func formattedDetail(unit: WeightUnit) -> String {
        let line = summaryLine(unit: unit)
        if !line.isEmpty {
            return line
        }
        return formattedWorkingWeight(unit: unit)
    }
}

// MARK: - Routine Link (Shared Workout Routine)
struct RoutineLink: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var assignedDays: [Weekday] = []
    var exercises: [ExerciseItem] = []
}

// MARK: - Day Routine
struct DayRoutine: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var weekday: Weekday
    var title: String
    var isRestDay: Bool = false
    var exercises: [ExerciseItem] = []
    var routineLinkId: UUID? = nil

    var completedCount: Int {
        exercises.filter { $0.isCompleted }.count
    }

    var totalCount: Int {
        exercises.count
    }
}

// MARK: - Split Profile (Multiple Routines Management)
struct SplitProfile: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var isActive: Bool = false
    var scheduleSlots: [Weekday: RoutineLink] = [:]
    var routines: [Weekday: DayRoutine] = [:]
    var routineLinks: [UUID: RoutineLink] = [:]
}

// MARK: - Buddy Split Status
struct FriendStatus: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var handle: String
    var initials: String
    var splitTitle: String
    var isRestDay: Bool = false
    var completedCount: Int = 0
    var totalCount: Int = 0
    var hasBumped: Bool = false
}

// MARK: - Master Exercise Model (Dynamically Aggregated by Name)
struct MasterExercise: Identifiable, Hashable {
    var id: String { name.trimmingCharacters(in: .whitespaces).lowercased() }
    var name: String
    var weight: String = ""
    var sets: String = ""
    var reps: String = ""
    var notes: String = ""
    var customVariables: [ExerciseCustomVariable] = []
    var usedInDays: [Weekday] = []
    var usedInRoutines: [String] = []

    var usedInLabel: String {
        let sortedDays = usedInDays.sorted()
        if sortedDays.isEmpty {
            return "Not currently assigned"
        }
        return "Used in: " + sortedDays.map { $0.fullName }.joined(separator: ", ")
    }

    func summaryLine(unit: WeightUnit) -> String {
        let item = ExerciseItem(
            name: name,
            weight: weight,
            sets: sets,
            reps: reps,
            notes: notes,
            customVariables: customVariables
        )
        return item.summaryLine(unit: unit)
    }

    func formattedWorkingWeight(unit: WeightUnit) -> String {
        let trimmed = weight.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return "" }
        if trimmed.hasSuffix("lbs") || trimmed.hasSuffix("kg") {
            return trimmed
        }
        return "\(trimmed) \(unit.rawValue)"
    }
}

// MARK: - Reusable Compact Exercise Card View
struct CompactExerciseCardView: View {
    let name: String
    let workingWeight: String
    let summaryLine: String
    let notes: String
    var isCompleted: Bool = false
    var showCheckbox: Bool = false
    var onToggleCompleted: (() -> Void)? = nil
    var onEdit: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 0) {
            // Top Header Row
            HStack(alignment: .center, spacing: 8) {
                if showCheckbox {
                    Button {
                        onToggleCompleted?()
                    } label: {
                        Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(isCompleted ? SpottrTheme.accent : SpottrTheme.textMuted)
                    }
                    .buttonStyle(.plain)
                }

                Text(name.isEmpty ? "Exercise Name" : name)
                    .font(.headline)
                    .foregroundStyle(isCompleted ? SpottrTheme.textMuted : SpottrTheme.textPrimary)
                    .strikethrough(isCompleted, color: SpottrTheme.textMuted)
                    .lineLimit(1)

                Spacer()

                if !workingWeight.isEmpty {
                    Text(workingWeight)
                        .font(.callout.weight(.bold))
                        .foregroundStyle(isCompleted ? SpottrTheme.textMuted : SpottrTheme.accent)
                }
            }

            // Subtle Divider
            Rectangle()
                .fill(SpottrTheme.border)
                .frame(height: 1)
                .padding(.vertical, 4)

            // Compact Centered Summary Line
            if !summaryLine.isEmpty {
                Text(summaryLine)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(isCompleted ? SpottrTheme.textMuted : SpottrTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                Text("—")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(SpottrTheme.textMuted)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
            }

            // Optional Notes
            let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedNotes.isEmpty {
                Text(trimmedNotes)
                    .font(.caption)
                    .foregroundStyle(SpottrTheme.textMuted)
                    .lineLimit(1)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 2)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(SpottrTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isCompleted ? SpottrTheme.accent.opacity(0.35) : SpottrTheme.border, lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onTapGesture {
            onEdit?()
        }
    }
}
