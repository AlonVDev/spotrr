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
        didSet { saveToStorage() }
    }

    @Published var routineLinks: [UUID: RoutineLink] = [:] {
        didSet { saveRoutineLinks() }
    }

    @Published var selectedWeekday: Weekday = Weekday.today()

    @Published var weightUnit: WeightUnit = .lbs {
        didSet { UserDefaults.standard.set(weightUnit.rawValue, forKey: unitStorageKey) }
    }

    @Published var weekStart: WeekStart = .monday {
        didSet { UserDefaults.standard.set(weekStart.rawValue, forKey: weekStartStorageKey) }
    }

    @Published var autoResetDaily: Bool = true {
        didSet { UserDefaults.standard.set(autoResetDaily, forKey: autoResetStorageKey) }
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

    var orderedWeekdays: [Weekday] { weekStart.orderedWeekdays }

    private let storageKey = "Spottr_WeeklyRoutines_v3"
    private let routineLinksStorageKey = "Spottr_RoutineLinks_v1"
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
        loadRoutineLinks()
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

    // MARK: - Symmetric Linked Routines

    /// Returns the RoutineLink for a given weekday if one is assigned.
    func routineLink(for weekday: Weekday) -> RoutineLink? {
        guard let linkId = routine(for: weekday).routineLinkId else { return nil }
        return routineLinks[linkId]
    }

    /// Helper to merge two exercise lists preserving existing items and appending new unique items by name.
    private func mergeExerciseLists(base: [ExerciseItem], additional: [ExerciseItem]) -> [ExerciseItem] {
        var result = base
        for item in additional {
            let cleanName = item.name.trimmingCharacters(in: .whitespaces).lowercased()
            guard !cleanName.isEmpty else { continue }
            if let existingIndex = result.firstIndex(where: { $0.name.trimmingCharacters(in: .whitespaces).lowercased() == cleanName }) {
                if result[existingIndex].weight.isEmpty && !item.weight.isEmpty {
                    result[existingIndex].weight = item.weight
                }
                if result[existingIndex].reps.isEmpty && !item.reps.isEmpty {
                    result[existingIndex].reps = item.reps
                }
                if result[existingIndex].notes.isEmpty && !item.notes.isEmpty {
                    result[existingIndex].notes = item.notes
                }
            } else {
                result.append(item)
            }
        }
        return result
    }

    /// Seamless action for the dropdown menu: copies routine and links target day to source day under a shared RoutineLink.
    func copyAndLinkDay(from sourceWeekday: Weekday, to targetWeekday: Weekday) {
        var sourceRoutine = routine(for: sourceWeekday)
        var targetRoutine = routine(for: targetWeekday)

        let linkName = sourceRoutine.title.isEmpty ? sourceWeekday.fullName : sourceRoutine.title

        let linkId: UUID
        var mergedExercises: [ExerciseItem] = []

        if let existingLinkId = sourceRoutine.routineLinkId, var existingLink = routineLinks[existingLinkId] {
            linkId = existingLinkId
            mergedExercises = mergeExerciseLists(base: existingLink.exercises, additional: targetRoutine.exercises)
            existingLink.exercises = mergedExercises
            if !existingLink.assignedDays.contains(targetWeekday) {
                existingLink.assignedDays.append(targetWeekday)
            }
            routineLinks[linkId] = existingLink
        } else {
            mergedExercises = mergeExerciseLists(base: sourceRoutine.exercises, additional: targetRoutine.exercises)
            var newLink = RoutineLink(
                name: linkName,
                assignedDays: [sourceWeekday, targetWeekday],
                exercises: mergedExercises
            )
            linkId = newLink.id
            routineLinks[linkId] = newLink

            sourceRoutine.routineLinkId = linkId
            sourceRoutine.title = linkName
            sourceRoutine.isRestDay = false
            sourceRoutine.exercises = mergedExercises
            routines[sourceWeekday] = sourceRoutine
        }

        targetRoutine.routineLinkId = linkId
        targetRoutine.title = linkName
        targetRoutine.isRestDay = false
        targetRoutine.exercises = mergedExercises
        routines[targetWeekday] = targetRoutine

        if let link = routineLinks[linkId] {
            propagateExercises(from: link)
        }

        triggerHaptic(.medium)
    }

    /// Links multiple days symmetrically under a shared RoutineLink, merging all their exercise stacks.
    func mergeAndLinkDays(_ days: [Weekday], routineName: String) {
        guard !days.isEmpty else { return }
        let cleanName = routineName.trimmingCharacters(in: .whitespaces).isEmpty ? "Routine" : routineName.trimmingCharacters(in: .whitespaces)

        var merged: [ExerciseItem] = []
        for day in days {
            let r = routine(for: day)
            merged = mergeExerciseLists(base: merged, additional: r.exercises)
        }

        var targetLinkId: UUID? = nil
        for day in days {
            if let linkId = routine(for: day).routineLinkId, let link = routineLinks[linkId] {
                if link.name.trimmingCharacters(in: .whitespaces).lowercased() == cleanName.lowercased() {
                    targetLinkId = linkId
                    break
                }
            }
        }

        if targetLinkId == nil {
            if let existing = routineLinks.values.first(where: { $0.name.trimmingCharacters(in: .whitespaces).lowercased() == cleanName.lowercased() }) {
                targetLinkId = existing.id
            }
        }

        let linkId: UUID
        if let existingId = targetLinkId, var existingLink = routineLinks[existingId] {
            linkId = existingId
            existingLink.name = cleanName
            existingLink.exercises = mergeExerciseLists(base: existingLink.exercises, additional: merged)
            for day in days {
                if !existingLink.assignedDays.contains(day) {
                    existingLink.assignedDays.append(day)
                }
            }
            routineLinks[linkId] = existingLink
        } else {
            var newLink = RoutineLink(name: cleanName, assignedDays: days, exercises: merged)
            linkId = newLink.id
            routineLinks[linkId] = newLink
        }

        for day in days {
            var r = routine(for: day)
            r.routineLinkId = linkId
            r.title = cleanName
            r.isRestDay = false
            r.exercises = routineLinks[linkId]?.exercises ?? merged
            routines[day] = r
        }

        if let link = routineLinks[linkId] {
            propagateExercises(from: link)
        }

        triggerHaptic(.medium)
    }

    /// Checks if a given day's new title matches an existing day's title or routine link for automatic linking detection.
    func findMatchingDaysOrLink(for weekday: Weekday, title: String) -> (matchingDays: [Weekday], linkName: String)? {
        let clean = title.trimmingCharacters(in: .whitespaces).lowercased()
        guard !clean.isEmpty else { return nil }

        // If current day is already in a link with this name, don't prompt
        if let currentLink = routineLink(for: weekday),
           currentLink.name.trimmingCharacters(in: .whitespaces).lowercased() == clean {
            return nil
        }

        // 1. Check if an existing RoutineLink has this exact name
        if let existingLink = routineLinks.values.first(where: { $0.name.trimmingCharacters(in: .whitespaces).lowercased() == clean }) {
            if !existingLink.assignedDays.contains(weekday) {
                return (existingLink.assignedDays, existingLink.name)
            }
        }

        // 2. Check if another day has this title
        let otherMatchingDays = orderedWeekdays.filter { otherDay in
            otherDay != weekday &&
            !routine(for: otherDay).isRestDay &&
            routine(for: otherDay).title.trimmingCharacters(in: .whitespaces).lowercased() == clean
        }

        if !otherMatchingDays.isEmpty {
            return (otherMatchingDays, title.trimmingCharacters(in: .whitespaces))
        }

        return nil
    }

    /// Unbinds `weekday` from its RoutineLink, converting it to a standalone day.
    func unlinkDay(_ weekday: Weekday) {
        guard var dayRoutine = routines[weekday],
              let linkId = dayRoutine.routineLinkId else { return }

        if var link = routineLinks[linkId] {
            link.assignedDays.removeAll(where: { $0 == weekday })
            if link.assignedDays.isEmpty {
                routineLinks.removeValue(forKey: linkId)
            } else if link.assignedDays.count == 1 {
                // If only 1 day is left, unlink that day as well and dissolve the link
                let lastDay = link.assignedDays[0]
                if var lastRoutine = routines[lastDay] {
                    lastRoutine.routineLinkId = nil
                    routines[lastDay] = lastRoutine
                }
                routineLinks.removeValue(forKey: linkId)
            } else {
                routineLinks[linkId] = link
            }
        }

        dayRoutine.routineLinkId = nil
        routines[weekday] = dayRoutine
        triggerHaptic(.medium)
    }

    /// Binds `weekday` to an existing RoutineLink, merging its exercises into the routine.
    func bindDayToRoutineLink(_ weekday: Weekday, linkId: UUID) {
        guard var link = routineLinks[linkId] else { return }

        if let oldLinkId = routine(for: weekday).routineLinkId, oldLinkId != linkId {
            unlinkDay(weekday)
        }

        let currentExercises = routine(for: weekday).exercises
        link.exercises = mergeExerciseLists(base: link.exercises, additional: currentExercises)
        if !link.assignedDays.contains(weekday) {
            link.assignedDays.append(weekday)
        }
        routineLinks[linkId] = link

        var r = routine(for: weekday)
        r.routineLinkId = linkId
        r.title = link.name
        r.isRestDay = false
        r.exercises = link.exercises
        routines[weekday] = r

        propagateExercises(from: link)
        triggerHaptic(.medium)
    }

    /// Unbinds a day from a specific routine link (alias to unlinkDay).
    func unbindDayFromRoutineLink(_ weekday: Weekday, linkId: UUID) {
        unlinkDay(weekday)
    }

    /// Deletes a RoutineLink completely and unbinds all its days into standalone days.
    func deleteRoutineLink(id: UUID) {
        guard let link = routineLinks[id] else { return }
        for day in link.assignedDays {
            if var r = routines[day] {
                r.routineLinkId = nil
                routines[day] = r
            }
        }
        routineLinks.removeValue(forKey: id)
        triggerHaptic(.medium)
    }

    /// Creates a new RoutineLink from a set of weekdays.
    func createRoutineLink(name: String, days: [Weekday]) {
        guard days.count >= 2 else { return }
        mergeAndLinkDays(days, routineName: name)
    }

    /// Renames a RoutineLink and updates all linked days' titles.
    func renameRoutineLink(id: UUID, name: String) {
        guard var link = routineLinks[id] else { return }
        let cleanName = name.trimmingCharacters(in: .whitespaces)
        guard !cleanName.isEmpty else { return }
        link.name = cleanName
        routineLinks[id] = link

        for weekday in link.assignedDays {
            if var r = routines[weekday] {
                r.title = cleanName
                routines[weekday] = r
            }
        }
        triggerHaptic(.light)
    }

    // MARK: - Global Dynamic Exercise Library

    /// Dynamically updates an exercise across every day and routine link in the schedule.
    func updateMasterExercise(originalName: String, newName: String, weight: String, reps: String, notes: String) {
        let cleanOriginal = originalName.trimmingCharacters(in: .whitespaces).lowercased()
        let cleanNew = newName.trimmingCharacters(in: .whitespaces)
        guard !cleanOriginal.isEmpty, !cleanNew.isEmpty else { return }

        let cleanWeight = weight.trimmingCharacters(in: .whitespaces)
        let cleanReps = reps.trimmingCharacters(in: .whitespaces)
        let cleanNotes = notes.trimmingCharacters(in: .whitespaces)

        // 1. Update in all routineLinks
        for (linkId, var link) in routineLinks {
            var changed = false
            for i in link.exercises.indices {
                if link.exercises[i].name.trimmingCharacters(in: .whitespaces).lowercased() == cleanOriginal {
                    link.exercises[i].name = cleanNew
                    link.exercises[i].weight = cleanWeight
                    link.exercises[i].reps = cleanReps
                    link.exercises[i].notes = cleanNotes
                    changed = true
                }
            }
            if changed {
                routineLinks[linkId] = link
                propagateExercises(from: link)
            }
        }

        // 2. Update in all routines
        for (weekday, var r) in routines {
            var changed = false
            for i in r.exercises.indices {
                if r.exercises[i].name.trimmingCharacters(in: .whitespaces).lowercased() == cleanOriginal {
                    r.exercises[i].name = cleanNew
                    r.exercises[i].weight = cleanWeight
                    r.exercises[i].reps = cleanReps
                    r.exercises[i].notes = cleanNotes
                    changed = true
                }
            }
            if changed {
                routines[weekday] = r
            }
        }

        triggerHaptic(.light)
    }

    /// Removes an exercise by name from every day and routine link in the split.
    func deleteMasterExercise(name: String) {
        let clean = name.trimmingCharacters(in: .whitespaces).lowercased()
        guard !clean.isEmpty else { return }

        // 1. Remove from all routineLinks
        for (linkId, var link) in routineLinks {
            link.exercises.removeAll { $0.name.trimmingCharacters(in: .whitespaces).lowercased() == clean }
            routineLinks[linkId] = link
            propagateExercises(from: link)
        }

        // 2. Remove from all routines
        for (weekday, var r) in routines {
            r.exercises.removeAll { $0.name.trimmingCharacters(in: .whitespaces).lowercased() == clean }
            routines[weekday] = r
        }

        triggerHaptic(.medium)
    }

    // MARK: - Exercise Mutations (Linked-Aware)

    func addExercise(to weekday: Weekday, name: String, weight: String = "", reps: String = "", notes: String = "") {
        let cleanName = name.trimmingCharacters(in: .whitespaces)
        guard !cleanName.isEmpty else { return }

        let newExercise = ExerciseItem(
            name: cleanName,
            weight: weight.trimmingCharacters(in: .whitespaces),
            reps: reps.trimmingCharacters(in: .whitespaces),
            notes: notes.trimmingCharacters(in: .whitespaces),
            isCompleted: false
        )

        if let linkId = routine(for: weekday).routineLinkId, var link = routineLinks[linkId] {
            link.exercises.append(newExercise)
            routineLinks[linkId] = link
            propagateExercises(from: link)
        } else {
            var r = routine(for: weekday)
            r.isRestDay = false
            r.exercises.append(newExercise)
            routines[weekday] = r
        }

        triggerHaptic(.light)
    }

    func updateExercise(weekday: Weekday, exercise: ExerciseItem) {
        if let linkId = routine(for: weekday).routineLinkId, var link = routineLinks[linkId] {
            if let index = link.exercises.firstIndex(where: { $0.id == exercise.id }) {
                link.exercises[index] = exercise
                routineLinks[linkId] = link
                propagateExercises(from: link)
            }
        } else {
            guard var r = routines[weekday],
                  let index = r.exercises.firstIndex(where: { $0.id == exercise.id }) else { return }
            r.exercises[index] = exercise
            routines[weekday] = r
        }
    }

    func deleteExercise(from weekday: Weekday, exerciseId: UUID) {
        if let linkId = routine(for: weekday).routineLinkId, var link = routineLinks[linkId] {
            link.exercises.removeAll(where: { $0.id == exerciseId })
            routineLinks[linkId] = link
            propagateExercises(from: link)
        } else {
            guard var r = routines[weekday] else { return }
            r.exercises.removeAll(where: { $0.id == exerciseId })
            routines[weekday] = r
        }

        triggerHaptic(.light)
    }

    func moveExercise(in weekday: Weekday, exerciseId: UUID, direction: Int) {
        if let linkId = routine(for: weekday).routineLinkId, var link = routineLinks[linkId] {
            guard let currentIndex = link.exercises.firstIndex(where: { $0.id == exerciseId }) else { return }
            let targetIndex = currentIndex + direction
            guard link.exercises.indices.contains(targetIndex) else { return }
            link.exercises.swapAt(currentIndex, targetIndex)
            routineLinks[linkId] = link
            propagateExercises(from: link)
        } else {
            guard var r = routines[weekday],
                  let currentIndex = r.exercises.firstIndex(where: { $0.id == exerciseId }) else { return }
            let targetIndex = currentIndex + direction
            guard r.exercises.indices.contains(targetIndex) else { return }
            r.exercises.swapAt(currentIndex, targetIndex)
            routines[weekday] = r
        }

        triggerHaptic(.light)
    }

    func moveExercise(in weekday: Weekday, fromIndex: Int, toIndex: Int) {
        guard fromIndex != toIndex else { return }

        if let linkId = routine(for: weekday).routineLinkId, var link = routineLinks[linkId] {
            guard link.exercises.indices.contains(fromIndex),
                  link.exercises.indices.contains(toIndex) else { return }
            let item = link.exercises.remove(at: fromIndex)
            link.exercises.insert(item, at: toIndex)
            routineLinks[linkId] = link
            propagateExercises(from: link)
        } else {
            guard var r = routines[weekday],
                  r.exercises.indices.contains(fromIndex),
                  r.exercises.indices.contains(toIndex) else { return }
            let item = r.exercises.remove(at: fromIndex)
            r.exercises.insert(item, at: toIndex)
            routines[weekday] = r
        }

        triggerHaptic(.light)
    }

    func reorderExercises(for weekday: Weekday, from source: IndexSet, to destination: Int) {
        if let linkId = routine(for: weekday).routineLinkId, var link = routineLinks[linkId] {
            link.exercises.move(fromOffsets: source, toOffset: destination)
            routineLinks[linkId] = link
            propagateExercises(from: link)
        } else {
            guard var r = routines[weekday] else { return }
            r.exercises.move(fromOffsets: source, toOffset: destination)
            routines[weekday] = r
        }

        triggerHaptic(.light)
    }

    /// Propagates the canonical exercise list from a link to all assigned days,
    /// preserving each day's per-exercise isCompleted state.
    private func propagateExercises(from link: RoutineLink) {
        for weekday in link.assignedDays {
            guard var r = routines[weekday] else {
                let newR = DayRoutine(weekday: weekday, title: link.name, isRestDay: false, exercises: link.exercises, routineLinkId: link.id)
                routines[weekday] = newR
                continue
            }

            let completedIDs = Set(r.exercises.filter { $0.isCompleted }.map { $0.id })
            var updated = link.exercises
            for i in updated.indices {
                if completedIDs.contains(updated[i].id) {
                    updated[i].isCompleted = true
                }
            }
            r.routineLinkId = link.id
            r.title = link.name
            r.exercises = updated
            routines[weekday] = r
        }
    }

    // MARK: - Remaining Exercise Actions

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

    // MARK: - Export Split (Customizable)
    func exportSplitAsText(
        includeRestDays: Bool = true,
        includeExercises: Bool = true,
        includeWeights: Bool = true
    ) -> String {
        var output = "My Weekly Split on Spottr 🏋️‍♂️\n\n"

        for weekday in orderedWeekdays {
            let r = routine(for: weekday)

            if r.isRestDay && !includeRestDays { continue }

            let dayName = weekday.fullName
            let splitTitle = r.isRestDay ? "Rest Day" : (r.title.isEmpty ? "Workout" : r.title)

            output += "\(dayName.uppercased()): \(splitTitle)\n"

            if includeExercises {
                if !r.isRestDay && !r.exercises.isEmpty {
                    for ex in r.exercises {
                        let weightText = (includeWeights && !ex.weight.isEmpty) ? " @ \(ex.weight) \(weightUnit.rawValue)" : ""
                        output += "   • \(ex.name)\(weightText)\n"
                    }
                    output += "\n"
                } else {
                    output += "\n"
                }
            }
        }

        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func clearSplit() {
        routineLinks = [:]
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
        for item in decoded { map[item.weekday] = item }
        self.routines = map
        return true
    }

    private func saveRoutineLinks() {
        let encoder = JSONEncoder()
        let array = Array(routineLinks.values)
        if let encoded = try? encoder.encode(array) {
            UserDefaults.standard.set(encoded, forKey: routineLinksStorageKey)
        }
    }

    private func loadRoutineLinks() {
        guard let data = UserDefaults.standard.data(forKey: routineLinksStorageKey),
              let decoded = try? JSONDecoder().decode([RoutineLink].self, from: data) else { return }

        var map: [UUID: RoutineLink] = [:]
        for link in decoded { map[link.id] = link }
        self.routineLinks = map
    }
}
