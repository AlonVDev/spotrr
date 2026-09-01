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

    @Published var buddies: [FriendStatus] = [
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
            setupEmptyRoutines()
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

    // MARK: - Empty Starter Setup
    private func setupEmptyRoutines() {
        routines = [:]
    }

    // MARK: - Routine Queries & Actions

    func routine(for weekday: Weekday) -> DayRoutine {
        routines[weekday] ?? DayRoutine(weekday: weekday, title: "", isRestDay: false, exercises: [])
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

    func toggleFistBump(for buddyId: UUID) {
        guard let index = buddies.firstIndex(where: { $0.id == buddyId }) else { return }
        buddies[index].hasBumped.toggle()
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

    func clearSplit() {
        setupEmptyRoutines()
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
