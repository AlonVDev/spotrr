//
//  SpottrStore.swift
//  spotrr
//
//  Created by Spottr on 28/08/2026.
//

import SwiftUI
import Combine
import UIKit

@MainActor
final class SpottrStore: ObservableObject {

    // MARK: - Published State
    @Published var routines: [Weekday: DayRoutine] = [:] {
        didSet {
            saveToStorage()
        }
    }

    @Published var selectedWeekday: Weekday = Weekday.today()

    @Published var weightUnit: WeightUnit = .lbs {
        didSet {
            UserDefaults.standard.set(weightUnit.rawValue, forKey: unitStorageKey)
        }
    }

    @Published var weekStart: WeekStart = .monday {
        didSet {
            UserDefaults.standard.set(weekStart.rawValue, forKey: weekStartStorageKey)
        }
    }

    @Published var autoResetDaily: Bool = true {
        didSet {
            UserDefaults.standard.set(autoResetDaily, forKey: autoResetStorageKey)
        }
    }

    @Published var friends: [FriendStatus] = [
        FriendStatus(
            name: "Marcus Chen",
            handle: "@marcus_c",
            initials: "MC",
            splitTitle: "Push Day (Chest & Shoulders)",
            isRestDay: false,
            completedCount: 4,
            totalCount: 5,
            hasBumped: true
        ),
        FriendStatus(
            name: "Sarah Jenkins",
            handle: "@sarah_j",
            initials: "SJ",
            splitTitle: "Legs (Glutes & Hamstrings)",
            isRestDay: false,
            completedCount: 2,
            totalCount: 4,
            hasBumped: false
        ),
        FriendStatus(
            name: "Liam Vance",
            handle: "@liam_v",
            initials: "LV",
            splitTitle: "Rest Day",
            isRestDay: true,
            completedCount: 0,
            totalCount: 0,
            hasBumped: false
        ),
        FriendStatus(
            name: "Elena Rostova",
            handle: "@elena_r",
            initials: "ER",
            splitTitle: "Back & Biceps Power",
            isRestDay: false,
            completedCount: 5,
            totalCount: 5,
            hasBumped: false
        )
    ]

    var orderedWeekdays: [Weekday] {
        weekStart.orderedWeekdays
    }

    private let storageKey = "Spottr_WeeklyRoutines_v3"
    private let unitStorageKey = "Spottr_WeightUnit"
    private let weekStartStorageKey = "Spottr_WeekStart"
    private let autoResetStorageKey = "Spottr_AutoResetDaily"
    private let lastDateKey = "Spottr_LastOpenedDate"

    // MARK: - Initialization
    init() {
        if let savedUnit = UserDefaults.standard.string(forKey: unitStorageKey),
           let unit = WeightUnit(rawValue: savedUnit) {
            self.weightUnit = unit
        }

        if let savedWeekStart = UserDefaults.standard.string(forKey: weekStartStorageKey),
           let start = WeekStart(rawValue: savedWeekStart) {
            self.weekStart = start
        }

        if UserDefaults.standard.object(forKey: autoResetStorageKey) != nil {
            self.autoResetDaily = UserDefaults.standard.bool(forKey: autoResetStorageKey)
        }

        if !loadFromStorage() {
            setupDefaultRoutines()
        }

        checkAndPerformDailyReset()
    }

    // MARK: - Daily Reset Check
    func checkAndPerformDailyReset() {
        guard autoResetDaily else { return }

        let calendar = Calendar.current
        let todayStr = calendar.startOfDay(for: Date()).timeIntervalSince1970

        if let lastOpened = UserDefaults.standard.object(forKey: lastDateKey) as? Double {
            let lastDayStart = Date(timeIntervalSince1970: lastOpened)
            if !calendar.isDateInToday(lastDayStart) {
                // It's a new day! Reset checkmarks for today's routine
                resetDayChecks(for: Weekday.today())
            }
        }
        UserDefaults.standard.set(todayStr, forKey: lastDateKey)
    }

    // MARK: - Default Starter Setup
    private func setupDefaultRoutines() {
        routines = [
            .monday: DayRoutine(
                weekday: .monday,
                title: "Chest & Triceps",
                isRestDay: false,
                exercises: [
                    ExerciseItem(name: "Barbell Bench Press", weight: "185", reps: "6–8"),
                    ExerciseItem(name: "Incline Dumbbell Press", weight: "70", reps: "8–10"),
                    ExerciseItem(name: "Cable Chest Flyes", weight: "35", reps: "12"),
                    ExerciseItem(name: "Triceps Rope Pushdown", weight: "55", reps: "12–15"),
                    ExerciseItem(name: "Overhead Dumbbell Extension", weight: "60", reps: "10")
                ]
            ),
            .tuesday: DayRoutine(
                weekday: .tuesday,
                title: "Back & Biceps",
                isRestDay: false,
                exercises: [
                    ExerciseItem(name: "Conventional Deadlift", weight: "315", reps: "5"),
                    ExerciseItem(name: "Barbell Bent-Over Row", weight: "165", reps: "8"),
                    ExerciseItem(name: "Lat Pulldown (Wide Grip)", weight: "140", reps: "10"),
                    ExerciseItem(name: "Incline Dumbbell Curls", weight: "35", reps: "10–12"),
                    ExerciseItem(name: "Hammer Curls", weight: "40", reps: "12")
                ]
            ),
            .wednesday: DayRoutine(
                weekday: .wednesday,
                title: "Legs & Abs",
                isRestDay: false,
                exercises: [
                    ExerciseItem(name: "Barbell Back Squat", weight: "245", reps: "6–8"),
                    ExerciseItem(name: "Romanian Deadlift (RDL)", weight: "205", reps: "10"),
                    ExerciseItem(name: "Leg Press", weight: "450", reps: "12"),
                    ExerciseItem(name: "Lying Leg Curls", weight: "90", reps: "12"),
                    ExerciseItem(name: "Hanging Leg Raises", weight: "", reps: "15")
                ]
            ),
            .thursday: DayRoutine(
                weekday: .thursday,
                title: "Rest & Recovery",
                isRestDay: true,
                exercises: []
            ),
            .friday: DayRoutine(
                weekday: .friday,
                title: "Shoulders & Arms",
                isRestDay: false,
                exercises: [
                    ExerciseItem(name: "Overhead Barbell Press", weight: "115", reps: "8"),
                    ExerciseItem(name: "Dumbbell Lateral Raises", weight: "25", reps: "15"),
                    ExerciseItem(name: "Rear Delt Reverse Flyes", weight: "20", reps: "15"),
                    ExerciseItem(name: "EZ-Bar Preacher Curls", weight: "65", reps: "10"),
                    ExerciseItem(name: "Skull Crushers", weight: "75", reps: "10")
                ]
            ),
            .saturday: DayRoutine(
                weekday: .saturday,
                title: "Full Body",
                isRestDay: false,
                exercises: [
                    ExerciseItem(name: "Weighted Pull-Ups", weight: "25", reps: "8"),
                    ExerciseItem(name: "Dumbbell Incline Bench", weight: "75", reps: "10"),
                    ExerciseItem(name: "Bulgarian Split Squats", weight: "45", reps: "10"),
                    ExerciseItem(name: "Cable Face Pulls", weight: "50", reps: "15")
                ]
            ),
            .sunday: DayRoutine(
                weekday: .sunday,
                title: "Rest Day",
                isRestDay: true,
                exercises: []
            )
        ]
    }

    // MARK: - Routine Queries & Actions

    func routine(for weekday: Weekday) -> DayRoutine {
        routines[weekday] ?? DayRoutine(weekday: weekday, title: "Workout Day", isRestDay: false, exercises: [])
    }

    func updateRoutine(_ updated: DayRoutine) {
        routines[updated.weekday] = updated
    }

    func addExercise(to weekday: Weekday, name: String, weight: String = "", reps: String = "") {
        let cleanName = name.trimmingCharacters(in: .whitespaces)
        guard !cleanName.isEmpty else { return }

        var current = routine(for: weekday)
        current.isRestDay = false
        current.exercises.append(ExerciseItem(
            name: cleanName,
            weight: weight.trimmingCharacters(in: .whitespaces),
            reps: reps.trimmingCharacters(in: .whitespaces),
            isCompleted: false
        ))
        routines[weekday] = current
        triggerHaptic(.light)
    }

    func updateExercise(weekday: Weekday, exercise: ExerciseItem) {
        guard var r = routines[weekday],
              let index = r.exercises.firstIndex(where: { $0.id == exercise.id }) else { return }
        r.exercises[index] = exercise
        routines[weekday] = r
    }

    func deleteExercise(from weekday: Weekday, exerciseId: UUID) {
        guard var r = routines[weekday] else { return }
        r.exercises.removeAll(where: { $0.id == exerciseId })
        routines[weekday] = r
        triggerHaptic(.light)
    }

    func toggleExercise(weekday: Weekday, exerciseId: UUID) {
        guard var r = routines[weekday],
              let index = r.exercises.firstIndex(where: { $0.id == exerciseId }) else { return }

        r.exercises[index].isCompleted.toggle()
        routines[weekday] = r
        triggerHaptic(.medium)
    }

    func resetDayChecks(for weekday: Weekday) {
        guard var r = routines[weekday] else { return }
        for index in r.exercises.indices {
            r.exercises[index].isCompleted = false
        }
        routines[weekday] = r
        triggerHaptic(.light)
    }

    func toggleRestDay(for weekday: Weekday) {
        var r = routine(for: weekday)
        r.isRestDay.toggle()
        routines[weekday] = r
        triggerHaptic(.medium)
    }

    func toggleFistBump(for friendId: UUID) {
        guard let index = friends.firstIndex(where: { $0.id == friendId }) else { return }
        friends[index].hasBumped.toggle()
        triggerHaptic(.medium)
    }

    func triggerHaptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }

    // MARK: - Export Split (Notes Style)
    func exportSplitAsText() -> String {
        var output = "📋 MY WORKOUT SPLIT (via Spottr)\n\n"
        for weekday in orderedWeekdays {
            let r = routine(for: weekday)
            output += "▶ \(weekday.fullName.uppercased()): \(r.title.isEmpty ? (r.isRestDay ? "Rest Day" : "Workout Day") : r.title)\n"
            if r.isRestDay || r.exercises.isEmpty {
                output += "   (Rest & Recovery)\n\n"
            } else {
                for ex in r.exercises {
                    let weightText = ex.weight.isEmpty ? "" : " @ \(ex.weight) \(weightUnit.rawValue)"
                    output += "   • \(ex.name)\(weightText)\n"
                }
                output += "\n"
            }
        }
        return output
    }

    func resetToDefaultSplit() {
        setupDefaultRoutines()
        triggerHaptic(.medium)
    }

    // MARK: - Persistence (UserDefaults)

    private func saveToStorage() {
        let encoder = JSONEncoder()
        let array = Array(routines.values)
        if let encoded = try? encoder.encode(array) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }

    private func loadFromStorage() -> Bool {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([DayRoutine].self, from: data),
              !decoded.isEmpty else {
            return false
        }

        var map: [Weekday: DayRoutine] = [:]
        for item in decoded {
            map[item.weekday] = item
        }
        self.routines = map
        return true
    }
}
