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
    case monday = "Mon – Sun"
    case sunday = "Sun – Sat"

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

// MARK: - Exercise Item
struct ExerciseItem: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var weight: String = "" // e.g. "185"
    var reps: String = ""   // e.g. "8–10"
    var isCompleted: Bool = false

    func formattedDetail(unit: WeightUnit) -> String {
        var parts: [String] = []
        let trimmedWeight = weight.trimmingCharacters(in: .whitespaces)
        if !trimmedWeight.isEmpty {
            if trimmedWeight.hasSuffix("lbs") || trimmedWeight.hasSuffix("kg") {
                parts.append(trimmedWeight)
            } else {
                parts.append("\(trimmedWeight) \(unit.rawValue)")
            }
        }
        let trimmedReps = reps.trimmingCharacters(in: .whitespaces)
        if !trimmedReps.isEmpty {
            parts.append("\(trimmedReps) reps")
        }
        return parts.joined(separator: " • ")
    }
}

// MARK: - Day Routine
struct DayRoutine: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var weekday: Weekday
    var title: String
    var isRestDay: Bool = false
    var exercises: [ExerciseItem] = []

    var completedCount: Int {
        exercises.filter { $0.isCompleted }.count
    }

    var totalCount: Int {
        exercises.count
    }
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
