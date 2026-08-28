//
//  SpottrStore.swift
//  spotrr
//
//  Created by Spottr on 28/08/2026.
//

import SwiftUI
import Combine

@MainActor
final class SpottrStore: ObservableObject {

    // MARK: - Published State
    @Published var routines: [Weekday: DayRoutine] = [:] {
        didSet {
            saveToStorage()
        }
    }

    @Published var selectedWeekday: Weekday = Weekday.today()

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

    private let storageKey = "Spottr_WeeklyRoutines_v2"

    // MARK: - Initialization
    init() {
        if !loadFromStorage() {
            setupDefaultRoutines()
        }
    }

    // MARK: - Default Starter Setup (Clean Notes Template)
    private func setupDefaultRoutines() {
        routines = [
            .monday: DayRoutine(
                weekday: .monday,
                title: "Chest & Triceps",
                isRestDay: false,
                exercises: [
                    ExerciseItem(name: "Barbell Bench Press", sets: 4, reps: "6–8", weight: "185", isCompleted: false),
                    ExerciseItem(name: "Incline Dumbbell Press", sets: 3, reps: "8–10", weight: "70", isCompleted: false),
                    ExerciseItem(name: "Cable Chest Flyes", sets: 3, reps: "12", weight: "35", isCompleted: false),
                    ExerciseItem(name: "Triceps Rope Pushdown", sets: 3, reps: "12–15", weight: "55", isCompleted: false),
                    ExerciseItem(name: "Overhead Dumbbell Extension", sets: 3, reps: "10", weight: "60", isCompleted: false)
                ]
            ),
            .tuesday: DayRoutine(
                weekday: .tuesday,
                title: "Back & Biceps",
                isRestDay: false,
                exercises: [
                    ExerciseItem(name: "Conventional Deadlift", sets: 4, reps: "5", weight: "315", isCompleted: false),
                    ExerciseItem(name: "Barbell Bent-Over Row", sets: 3, reps: "8", weight: "165", isCompleted: false),
                    ExerciseItem(name: "Lat Pulldown (Wide Grip)", sets: 3, reps: "10", weight: "140", isCompleted: false),
                    ExerciseItem(name: "Incline Dumbbell Curls", sets: 3, reps: "10–12", weight: "35", isCompleted: false),
                    ExerciseItem(name: "Hammer Curls", sets: 3, reps: "12", weight: "40", isCompleted: false)
                ]
            ),
            .wednesday: DayRoutine(
                weekday: .wednesday,
                title: "Legs & Abs",
                isRestDay: false,
                exercises: [
                    ExerciseItem(name: "Barbell Back Squat", sets: 4, reps: "6–8", weight: "245", isCompleted: false),
                    ExerciseItem(name: "Romanian Deadlift (RDL)", sets: 3, reps: "10", weight: "205", isCompleted: false),
                    ExerciseItem(name: "Leg Press", sets: 3, reps: "12", weight: "450", isCompleted: false),
                    ExerciseItem(name: "Lying Leg Curls", sets: 3, reps: "12", weight: "90", isCompleted: false),
                    ExerciseItem(name: "Hanging Leg Raises", sets: 3, reps: "15", weight: "", isCompleted: false)
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
                    ExerciseItem(name: "Overhead Barbell Press", sets: 4, reps: "8", weight: "115", isCompleted: false),
                    ExerciseItem(name: "Dumbbell Lateral Raises", sets: 4, reps: "15", weight: "25", isCompleted: false),
                    ExerciseItem(name: "Rear Delt Reverse Flyes", sets: 3, reps: "15", weight: "20", isCompleted: false),
                    ExerciseItem(name: "EZ-Bar Preacher Curls", sets: 3, reps: "10", weight: "65", isCompleted: false),
                    ExerciseItem(name: "Skull Crushers", sets: 3, reps: "10", weight: "75", isCompleted: false)
                ]
            ),
            .saturday: DayRoutine(
                weekday: .saturday,
                title: "Full Body Pump",
                isRestDay: false,
                exercises: [
                    ExerciseItem(name: "Weighted Pull-Ups", sets: 3, reps: "8", weight: "25", isCompleted: false),
                    ExerciseItem(name: "Dumbbell Incline Bench", sets: 3, reps: "10", weight: "75", isCompleted: false),
                    ExerciseItem(name: "Bulgarian Split Squats", sets: 3, reps: "10", weight: "45", isCompleted: false),
                    ExerciseItem(name: "Cable Face Pulls", sets: 3, reps: "15", weight: "50", isCompleted: false)
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

    func toggleExercise(weekday: Weekday, exerciseId: UUID) {
        guard var routine = routines[weekday],
              let index = routine.exercises.firstIndex(where: { $0.id == exerciseId }) else { return }

        routine.exercises[index].isCompleted.toggle()
        routines[weekday] = routine
    }

    func resetDayChecks(for weekday: Weekday) {
        guard var routine = routines[weekday] else { return }
        for index in routine.exercises.indices {
            routine.exercises[index].isCompleted = false
        }
        routines[weekday] = routine
    }

    func toggleFistBump(for friendId: UUID) {
        guard let index = friends.firstIndex(where: { $0.id == friendId }) else { return }
        friends[index].hasBumped.toggle()
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
