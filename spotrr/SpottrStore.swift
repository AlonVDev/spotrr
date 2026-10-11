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
            syncCurrentToActiveProfile()
        }
    }

    @Published var routineLinks: [UUID: RoutineLink] = [:] {
        didSet {
            saveRoutineLinks()
            syncCurrentToActiveProfile()
        }
    }

    @Published var splitProfiles: [SplitProfile] = [] {
        didSet { saveSplitProfiles() }
    }

    @Published var activeProfileId: UUID? = nil {
        didSet {
            if let id = activeProfileId {
                UserDefaults.standard.set(id.uuidString, forKey: activeProfileIdKey)
            }
        }
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
    private let splitProfilesStorageKey = "Spottr_SplitProfiles_v1"
    private let activeProfileIdKey = "Spottr_ActiveProfileId_v1"
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
        loadSplitProfiles()
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

    // MARK: - Split Profiles System

    var activeProfile: SplitProfile? {
        if let id = activeProfileId {
            return splitProfiles.first { $0.id == id }
        }
        return splitProfiles.first { $0.isActive }
    }

    private func syncCurrentToActiveProfile() {
        guard let activeId = activeProfileId ?? splitProfiles.first(where: { $0.isActive })?.id,
              let index = splitProfiles.firstIndex(where: { $0.id == activeId }) else { return }

        splitProfiles[index].routines = routines
        splitProfiles[index].routineLinks = routineLinks

        var slots: [Weekday: RoutineLink] = [:]
        for weekday in Weekday.allCases {
            if let linkId = routines[weekday]?.routineLinkId, let link = routineLinks[linkId] {
                slots[weekday] = link
            }
        }
        splitProfiles[index].scheduleSlots = slots
    }

    func activateProfile(id: UUID) {
        guard let targetIndex = splitProfiles.firstIndex(where: { $0.id == id }) else { return }

        // Sync old active profile before switching
        syncCurrentToActiveProfile()

        for i in splitProfiles.indices {
            splitProfiles[i].isActive = (splitProfiles[i].id == id)
        }
        activeProfileId = id

        let target = splitProfiles[targetIndex]
        self.routines = target.routines
        self.routineLinks = target.routineLinks

        triggerHaptic(.medium)
    }

    func createProfile(name: String, duplicateCurrent: Bool) {
        let cleanName = name.trimmingCharacters(in: .whitespaces)
        let profileName = cleanName.isEmpty ? "New Split" : cleanName

        let newRoutines = duplicateCurrent ? self.routines : [:]
        let newLinks = duplicateCurrent ? self.routineLinks : [:]

        var slots: [Weekday: RoutineLink] = [:]
        for weekday in Weekday.allCases {
            if let linkId = newRoutines[weekday]?.routineLinkId, let link = newLinks[linkId] {
                slots[weekday] = link
            }
        }

        let newProfile = SplitProfile(
            name: profileName,
            isActive: false,
            scheduleSlots: slots,
            routines: newRoutines,
            routineLinks: newLinks
        )

        splitProfiles.append(newProfile)
        triggerHaptic(.light)
    }

    func duplicateProfile(id: UUID) {
        guard let source = splitProfiles.first(where: { $0.id == id }) else { return }
        let copy = SplitProfile(
            name: "\(source.name) (Copy)",
            isActive: false,
            scheduleSlots: source.scheduleSlots,
            routines: source.routines,
            routineLinks: source.routineLinks
        )
        splitProfiles.append(copy)
        triggerHaptic(.light)
    }

    func renameProfile(id: UUID, name: String) {
        guard let index = splitProfiles.firstIndex(where: { $0.id == id }) else { return }
        let clean = name.trimmingCharacters(in: .whitespaces)
        guard !clean.isEmpty else { return }
        splitProfiles[index].name = clean
        triggerHaptic(.light)
    }

    func deleteProfile(id: UUID) {
        guard splitProfiles.count > 1 else { return }
        guard let index = splitProfiles.firstIndex(where: { $0.id == id }) else { return }

        let wasActive = splitProfiles[index].isActive || (activeProfileId == id)
        splitProfiles.remove(at: index)

        if wasActive, let first = splitProfiles.first {
            activateProfile(id: first.id)
        }
        triggerHaptic(.medium)
    }

    private func loadSplitProfiles() {
        if let data = UserDefaults.standard.data(forKey: splitProfilesStorageKey),
           let decoded = try? JSONDecoder().decode([SplitProfile].self, from: data),
           !decoded.isEmpty {
            self.splitProfiles = decoded
            if let savedActiveString = UserDefaults.standard.string(forKey: activeProfileIdKey),
               let savedActiveId = UUID(uuidString: savedActiveString),
               decoded.contains(where: { $0.id == savedActiveId }) {
                self.activeProfileId = savedActiveId
            } else if let active = decoded.first(where: { $0.isActive }) {
                self.activeProfileId = active.id
            } else {
                self.activeProfileId = decoded.first?.id
            }
        } else {
            // First run migration: seed current split as "Default Split"
            var slots: [Weekday: RoutineLink] = [:]
            for weekday in Weekday.allCases {
                if let linkId = routines[weekday]?.routineLinkId, let link = routineLinks[linkId] {
                    slots[weekday] = link
                }
            }

            let defaultProfile = SplitProfile(
                name: "Default Split",
                isActive: true,
                scheduleSlots: slots,
                routines: routines,
                routineLinks: routineLinks
            )
            self.splitProfiles = [defaultProfile]
            self.activeProfileId = defaultProfile.id
            saveSplitProfiles()
        }
    }

    private func saveSplitProfiles() {
        if let encoded = try? JSONEncoder().encode(splitProfiles) {
            UserDefaults.standard.set(encoded, forKey: splitProfilesStorageKey)
        }
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
                if result[existingIndex].sets.isEmpty && !item.sets.isEmpty {
                    result[existingIndex].sets = item.sets
                }
                if result[existingIndex].reps.isEmpty && !item.reps.isEmpty {
                    result[existingIndex].reps = item.reps
                }
                if result[existingIndex].notes.isEmpty && !item.notes.isEmpty {
                    result[existingIndex].notes = item.notes
                }
                if result[existingIndex].customVariables.isEmpty && !item.customVariables.isEmpty {
                    result[existingIndex].customVariables = item.customVariables
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
    func updateMasterExercise(
        originalName: String,
        newName: String,
        weight: String,
        sets: String = "",
        reps: String,
        notes: String,
        customVariables: [ExerciseCustomVariable] = []
    ) {
        let cleanOriginal = originalName.trimmingCharacters(in: .whitespaces).lowercased()
        let cleanNew = newName.trimmingCharacters(in: .whitespaces)
        guard !cleanOriginal.isEmpty, !cleanNew.isEmpty else { return }

        let cleanWeight = weight.trimmingCharacters(in: .whitespaces)
        let cleanSets = sets.trimmingCharacters(in: .whitespaces)
        let cleanReps = reps.trimmingCharacters(in: .whitespaces)
        let cleanNotes = notes.trimmingCharacters(in: .whitespaces)

        // 1. Update in all routineLinks
        for (linkId, var link) in routineLinks {
            var changed = false
            for i in link.exercises.indices {
                if link.exercises[i].name.trimmingCharacters(in: .whitespaces).lowercased() == cleanOriginal {
                    link.exercises[i].name = cleanNew
                    link.exercises[i].weight = cleanWeight
                    link.exercises[i].sets = cleanSets
                    link.exercises[i].reps = cleanReps
                    link.exercises[i].notes = cleanNotes
                    link.exercises[i].customVariables = customVariables
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
                    r.exercises[i].sets = cleanSets
                    r.exercises[i].reps = cleanReps
                    r.exercises[i].notes = cleanNotes
                    r.exercises[i].customVariables = customVariables
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

    func addExercise(
        to weekday: Weekday,
        name: String,
        weight: String = "",
        sets: String = "",
        reps: String = "",
        notes: String = "",
        customVariables: [ExerciseCustomVariable] = []
    ) {
        let cleanName = name.trimmingCharacters(in: .whitespaces)
        guard !cleanName.isEmpty else { return }

        let newExercise = ExerciseItem(
            name: cleanName,
            weight: weight.trimmingCharacters(in: .whitespaces),
            sets: sets.trimmingCharacters(in: .whitespaces),
            reps: reps.trimmingCharacters(in: .whitespaces),
            notes: notes.trimmingCharacters(in: .whitespaces),
            customVariables: customVariables,
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
                        let summary = ex.summaryLine(unit: weightUnit)
                        let detailText = summary.isEmpty ? "" : " (\(summary))"
                        output += "   • \(ex.name)\(weightText)\(detailText)\n"
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

    // MARK: - Import Split Engine

    func applyImportedSplit(
        name: String,
        routines: [Weekday: DayRoutine],
        routineLinks: [UUID: RoutineLink] = [:],
        asNewProfile: Bool = false
    ) {
        if asNewProfile {
            var slots: [Weekday: RoutineLink] = [:]
            for weekday in Weekday.allCases {
                if let linkId = routines[weekday]?.routineLinkId, let link = routineLinks[linkId] {
                    slots[weekday] = link
                }
            }
            let profile = SplitProfile(
                name: name,
                isActive: false,
                scheduleSlots: slots,
                routines: routines,
                routineLinks: routineLinks
            )
            splitProfiles.append(profile)
            activateProfile(id: profile.id)
        } else {
            self.routines = routines
            self.routineLinks = routineLinks
            syncCurrentToActiveProfile()
            triggerHaptic(.medium)
        }
    }

    /// Parses text schedule (e.g. from Notes or message) into structured Spottr days.
    func parseScheduleFromText(_ text: String) -> (name: String, routines: [Weekday: DayRoutine]) {
        var result: [Weekday: DayRoutine] = [:]
        for weekday in Weekday.allCases {
            result[weekday] = DayRoutine(weekday: weekday, title: "", isRestDay: true, exercises: [])
        }

        let lines = text.components(separatedBy: .newlines)
        var currentWeekday: Weekday? = nil

        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }

            // Check if this line is a day header
            if let matchedWeekday = detectWeekday(in: line) {
                currentWeekday = matchedWeekday
                var routine = result[matchedWeekday] ?? DayRoutine(weekday: matchedWeekday, title: "", isRestDay: false, exercises: [])

                // Check title after weekday colon or dash
                let titleCandidate = extractTitleAfterDay(line: line)
                if titleCandidate.localizedCaseInsensitiveContains("rest") {
                    routine.isRestDay = true
                    routine.title = "Rest Day"
                } else {
                    routine.isRestDay = false
                    routine.title = titleCandidate.isEmpty ? "Workout" : titleCandidate
                }
                result[matchedWeekday] = routine
                continue
            }

            // Otherwise, if we have a current weekday, parse as exercise item
            if let weekday = currentWeekday {
                var routine = result[weekday] ?? DayRoutine(weekday: weekday, title: "Workout", isRestDay: false, exercises: [])
                if let exercise = parseExerciseLine(line) {
                    routine.isRestDay = false
                    routine.exercises.append(exercise)
                    result[weekday] = routine
                }
            }
        }

        return ("Imported Split", result)
    }

    private func detectWeekday(in line: String) -> Weekday? {
        let lower = line.lowercased()
        let prefixes: [(Weekday, [String])] = [
            (.monday, ["monday", "mon: ", "mon -", "mon."]),
            (.tuesday, ["tuesday", "tue: ", "tue -", "tues: ", "tue."]),
            (.wednesday, ["wednesday", "wed: ", "wed -", "wed."]),
            (.thursday, ["thursday", "thu: ", "thu -", "thur: ", "thurs: ", "thu."]),
            (.friday, ["friday", "fri: ", "fri -", "fri."]),
            (.saturday, ["saturday", "sat: ", "sat -", "sat."]),
            (.sunday, ["sunday", "sun: ", "sun -", "sun."])
        ]

        for (day, keys) in prefixes {
            for key in keys {
                if lower.hasPrefix(key) || lower.starts(with: key) {
                    return day
                }
            }
        }

        // Exact match check for "Mon", "Monday", etc.
        let firstWord = lower.components(separatedBy: CharacterSet.alphanumerics.inverted).first ?? ""
        for day in Weekday.allCases {
            if day.fullName.lowercased() == firstWord || day.shortName.lowercased() == firstWord {
                return day
            }
        }

        return nil
    }

    private func extractTitleAfterDay(line: String) -> String {
        let separators = [":", "-", "—"]
        for sep in separators {
            if let range = line.range(of: sep) {
                let rest = line[range.upperBound...].trimmingCharacters(in: .whitespaces)
                if !rest.isEmpty {
                    return rest
                }
            }
        }
        return ""
    }

    private func parseExerciseLine(_ rawLine: String) -> ExerciseItem? {
        var line = rawLine
        // Strip bullet prefixes
        let bullets = ["-", "•", "*", "1.", "2.", "3.", "4.", "5.", "6.", "7.", "8.", "9."]
        for b in bullets {
            if line.hasPrefix(b) {
                line = String(line.dropFirst(b.count)).trimmingCharacters(in: .whitespaces)
                break
            }
        }

        guard !line.isEmpty else { return nil }

        // Detect weight patterns e.g. "185 lbs", "185lbs", "@ 80kg", "80 kg"
        var weight = ""
        var sets = ""
        var reps = ""
        var notes = ""

        // Check for parenthesized notes e.g. "(Drop set)"
        if let start = line.firstIndex(of: "("), let end = line.firstIndex(of: ")"), start < end {
            let noteContent = line[line.index(after: start)..<end]
            notes = String(noteContent).trimmingCharacters(in: .whitespaces)
            line.removeSubrange(start...end)
            line = line.trimmingCharacters(in: .whitespaces)
        }

        // Parse sets x reps e.g. "3x10", "3 x 8-10", "4x8"
        let pattern = #"(\d+)\s*[xX×]\s*(\d+[-–]?\d*)"#
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) {
            if let setsRange = Range(match.range(at: 1), in: line),
               let repsRange = Range(match.range(at: 2), in: line) {
                sets = String(line[setsRange])
                reps = String(line[repsRange])
            }
            if let matchRange = Range(match.range, in: line) {
                line.removeSubrange(matchRange)
                line = line.trimmingCharacters(in: .whitespaces)
            }
        }

        // Parse weight e.g. "185 lbs", "80kg", "135#"
        let weightPattern = #"(@?\s*)(\d+(\.\d+)?)\s*(lbs|kg|#)?"#
        if let regex = try? NSRegularExpression(pattern: weightPattern),
           let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) {
            if let valRange = Range(match.range(at: 2), in: line) {
                weight = String(line[valRange])
            }
            if let matchRange = Range(match.range, in: line) {
                line.removeSubrange(matchRange)
                line = line.trimmingCharacters(in: .whitespaces)
            }
        }

        // Clean leftover separators from name
        var name = line
        let cleanSeparators = [":", "-", "@", "—"]
        for s in cleanSeparators {
            if name.hasSuffix(s) { name = String(name.dropLast(s.count)).trimmingCharacters(in: .whitespaces) }
            if name.hasPrefix(s) { name = String(name.dropFirst(s.count)).trimmingCharacters(in: .whitespaces) }
        }

        if name.isEmpty { return nil }

        return ExerciseItem(
            name: name,
            weight: weight,
            sets: sets.isEmpty ? "3" : sets,
            reps: reps.isEmpty ? "8–10" : reps,
            notes: notes,
            customVariables: [],
            isCompleted: false
        )
    }

    /// Generates structured schedule for any buddy/friend from their profile.
    func generateBuddySplit(for buddyName: String, splitTitle: String) -> (name: String, routines: [Weekday: DayRoutine]) {
        var days: [Weekday: DayRoutine] = [:]

        let titleLower = splitTitle.lowercased()

        if titleLower.contains("push") {
            days[.monday] = DayRoutine(
                weekday: .monday,
                title: "Push Day (Chest & Shoulders)",
                isRestDay: false,
                exercises: [
                    ExerciseItem(name: "Barbell Bench Press", weight: "185", sets: "3", reps: "8–10", notes: "Control the eccentric"),
                    ExerciseItem(name: "Incline DB Press", weight: "70", sets: "3", reps: "10–12", notes: "30-degree incline"),
                    ExerciseItem(name: "Overhead Shoulder Press", weight: "115", sets: "3", reps: "8–10"),
                    ExerciseItem(name: "Cable Lateral Raise", weight: "25", sets: "4", reps: "12–15"),
                    ExerciseItem(name: "Tricep Rope Pushdown", weight: "50", sets: "3", reps: "12–15")
                ]
            )
            days[.tuesday] = DayRoutine(
                weekday: .tuesday,
                title: "Pull Day (Back & Biceps)",
                isRestDay: false,
                exercises: [
                    ExerciseItem(name: "Barbell Row", weight: "155", sets: "4", reps: "8–10"),
                    ExerciseItem(name: "Lat Pulldown", weight: "140", sets: "3", reps: "10–12"),
                    ExerciseItem(name: "Chest Supported Row", weight: "60", sets: "3", reps: "10–12"),
                    ExerciseItem(name: "Incline Dumbbell Curl", weight: "30", sets: "3", reps: "10–12")
                ]
            )
            days[.wednesday] = DayRoutine(
                weekday: .wednesday,
                title: "Leg Day (Quads & Calves)",
                isRestDay: false,
                exercises: [
                    ExerciseItem(name: "Barbell Squat", weight: "225", sets: "4", reps: "6–8"),
                    ExerciseItem(name: "Leg Press", weight: "360", sets: "3", reps: "10–12"),
                    ExerciseItem(name: "Leg Extension", weight: "110", sets: "3", reps: "12–15"),
                    ExerciseItem(name: "Standing Calf Raise", weight: "140", sets: "4", reps: "15")
                ]
            )
            days[.thursday] = DayRoutine(
                weekday: .thursday,
                title: "Push Day (Hypertrophy)",
                isRestDay: false,
                exercises: [
                    ExerciseItem(name: "Dumbbell Bench Press", weight: "80", sets: "3", reps: "10–12"),
                    ExerciseItem(name: "Dips", weight: "BW", sets: "3", reps: "10–12"),
                    ExerciseItem(name: "DB Lateral Raise", weight: "25", sets: "4", reps: "15")
                ]
            )
            days[.friday] = DayRoutine(
                weekday: .friday,
                title: "Pull Day (Hypertrophy)",
                isRestDay: false,
                exercises: [
                    ExerciseItem(name: "Neutral Grip Pull-Up", weight: "BW", sets: "3", reps: "8–10"),
                    ExerciseItem(name: "Seated Cable Row", weight: "130", sets: "3", reps: "10–12"),
                    ExerciseItem(name: "Hammer Curl", weight: "35", sets: "3", reps: "10–12")
                ]
            )
            days[.saturday] = DayRoutine(
                weekday: .saturday,
                title: "Legs & Core",
                isRestDay: false,
                exercises: [
                    ExerciseItem(name: "Romanian Deadlift", weight: "185", sets: "3", reps: "8–10"),
                    ExerciseItem(name: "Lying Leg Curl", weight: "90", sets: "3", reps: "10–12")
                ]
            )
            days[.sunday] = DayRoutine(weekday: .sunday, title: "Rest Day", isRestDay: true, exercises: [])
        } else if titleLower.contains("leg") || titleLower.contains("glute") {
            days[.monday] = DayRoutine(
                weekday: .monday,
                title: "Glutes & Hamstrings",
                isRestDay: false,
                exercises: [
                    ExerciseItem(name: "Barbell Hip Thrust", weight: "225", sets: "4", reps: "10–12", notes: "Pause 2s at top"),
                    ExerciseItem(name: "Romanian Deadlift", weight: "135", sets: "3", reps: "10–12"),
                    ExerciseItem(name: "Bulgarian Split Squats", weight: "40", sets: "3", reps: "8–10"),
                    ExerciseItem(name: "Cable Glute Kickbacks", weight: "25", sets: "3", reps: "15")
                ]
            )
            days[.tuesday] = DayRoutine(
                weekday: .tuesday,
                title: "Upper Body & Arms",
                isRestDay: false,
                exercises: [
                    ExerciseItem(name: "Dumbbell Shoulder Press", weight: "35", sets: "3", reps: "10"),
                    ExerciseItem(name: "Lat Pulldown", weight: "95", sets: "3", reps: "10–12"),
                    ExerciseItem(name: "Push-ups", weight: "BW", sets: "3", reps: "12")
                ]
            )
            days[.wednesday] = DayRoutine(weekday: .wednesday, title: "Rest Day", isRestDay: true, exercises: [])
            days[.thursday] = DayRoutine(
                weekday: .thursday,
                title: "Quads & Glutes",
                isRestDay: false,
                exercises: [
                    ExerciseItem(name: "Barbell Squat", weight: "155", sets: "4", reps: "8–10"),
                    ExerciseItem(name: "Leg Press", weight: "270", sets: "3", reps: "10–12"),
                    ExerciseItem(name: "Walking Lunges", weight: "30", sets: "3", reps: "12/leg")
                ]
            )
            days[.friday] = DayRoutine(
                weekday: .friday,
                title: "Back & Shoulders",
                isRestDay: false,
                exercises: [
                    ExerciseItem(name: "Seated Cable Row", weight: "85", sets: "3", reps: "10–12"),
                    ExerciseItem(name: "Lateral Raises", weight: "15", sets: "4", reps: "15")
                ]
            )
            days[.saturday] = DayRoutine(weekday: .saturday, title: "Full Body Mobility", isRestDay: true, exercises: [])
            days[.sunday] = DayRoutine(weekday: .sunday, title: "Rest Day", isRestDay: true, exercises: [])
        } else {
            // General balanced split
            days[.monday] = DayRoutine(
                weekday: .monday,
                title: splitTitle.isEmpty ? "Upper Power" : splitTitle,
                isRestDay: false,
                exercises: [
                    ExerciseItem(name: "Bench Press", weight: "175", sets: "4", reps: "6–8"),
                    ExerciseItem(name: "Barbell Row", weight: "145", sets: "4", reps: "6–8"),
                    ExerciseItem(name: "Overhead Press", weight: "105", sets: "3", reps: "8–10")
                ]
            )
            days[.tuesday] = DayRoutine(
                weekday: .tuesday,
                title: "Lower Power",
                isRestDay: false,
                exercises: [
                    ExerciseItem(name: "Squats", weight: "225", sets: "4", reps: "6–8"),
                    ExerciseItem(name: "Romanian Deadlift", weight: "185", sets: "3", reps: "8–10")
                ]
            )
            days[.wednesday] = DayRoutine(weekday: .wednesday, title: "Rest Day", isRestDay: true, exercises: [])
            days[.thursday] = DayRoutine(
                weekday: .thursday,
                title: "Upper Hypertrophy",
                isRestDay: false,
                exercises: [
                    ExerciseItem(name: "Incline DB Press", weight: "65", sets: "3", reps: "10–12"),
                    ExerciseItem(name: "Lat Pulldown", weight: "135", sets: "3", reps: "10–12")
                ]
            )
            days[.friday] = DayRoutine(
                weekday: .friday,
                title: "Lower Hypertrophy",
                isRestDay: false,
                exercises: [
                    ExerciseItem(name: "Leg Press", weight: "320", sets: "3", reps: "12–15"),
                    ExerciseItem(name: "Hamstring Curl", weight: "90", sets: "3", reps: "12–15")
                ]
            )
            days[.saturday] = DayRoutine(weekday: .saturday, title: "Rest Day", isRestDay: true, exercises: [])
            days[.sunday] = DayRoutine(weekday: .sunday, title: "Rest Day", isRestDay: true, exercises: [])
        }

        return ("\(buddyName)'s Routine", days)
    }

    func exportCurrentSplitAsJSON() -> String {
        let exportData: [String: Any] = [
            "version": 1,
            "profileName": activeProfile?.name ?? "My Split",
            "routines": Array(routines.values).map { r in
                [
                    "weekday": r.weekday.rawValue,
                    "title": r.title,
                    "isRestDay": r.isRestDay,
                    "exercises": r.exercises.map { ex in
                        [
                            "name": ex.name,
                            "weight": ex.weight,
                            "sets": ex.sets,
                            "reps": ex.reps,
                            "notes": ex.notes
                        ]
                    }
                ]
            }
        ]

        if let data = try? JSONSerialization.data(withJSONObject: exportData, options: .prettyPrinted),
           let string = String(data: data, encoding: .utf8) {
            return string
        }
        return "{}"
    }

    func parseSplitFromJSON(_ jsonString: String) -> (name: String, routines: [Weekday: DayRoutine])? {
        guard let data = jsonString.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let routinesArray = obj["routines"] as? [[String: Any]] else {
            return nil
        }

        let name = (obj["profileName"] as? String) ?? "Imported Split"
        var map: [Weekday: DayRoutine] = [:]

        for rDict in routinesArray {
            guard let rawW = rDict["weekday"] as? Int, let weekday = Weekday(rawValue: rawW) else { continue }
            let title = (rDict["title"] as? String) ?? ""
            let isRest = (rDict["isRestDay"] as? Bool) ?? false
            var exercises: [ExerciseItem] = []

            if let exArray = rDict["exercises"] as? [[String: Any]] {
                for exDict in exArray {
                    let exName = (exDict["name"] as? String) ?? ""
                    guard !exName.isEmpty else { continue }
                    let weight = (exDict["weight"] as? String) ?? ""
                    let sets = (exDict["sets"] as? String) ?? ""
                    let reps = (exDict["reps"] as? String) ?? ""
                    let notes = (exDict["notes"] as? String) ?? ""

                    exercises.append(ExerciseItem(
                        name: exName,
                        weight: weight,
                        sets: sets,
                        reps: reps,
                        notes: notes,
                        customVariables: [],
                        isCompleted: false
                    ))
                }
            }

            map[weekday] = DayRoutine(weekday: weekday, title: title, isRestDay: isRest, exercises: exercises)
        }

        for weekday in Weekday.allCases {
            if map[weekday] == nil {
                map[weekday] = DayRoutine(weekday: weekday, title: "", isRestDay: true, exercises: [])
            }
        }

        return (name, map)
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
