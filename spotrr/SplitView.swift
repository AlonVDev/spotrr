//
//  SplitView.swift
//  spotrr
//
//  Created by Spottr on 28/08/2026.
//

import SwiftUI
import UniformTypeIdentifiers

struct SplitView: View {
    @EnvironmentObject var store: SpottrStore

    @State private var isAddingExercise = false
    @State private var editingExerciseID: UUID?
    @State private var exerciseName = ""
    @State private var exerciseWeight = ""
    @State private var isReordering = false
    @State private var draggedExerciseID: UUID?
    @State private var autoLinkCandidate: AutoLinkCandidate? = nil
    @FocusState private var focusedField: Field?

    private struct AutoLinkCandidate: Identifiable {
        var id: String { title }
        let title: String
        let matchingDays: [Weekday]
    }

    private enum Field: Hashable {
        case title, exerciseName, exerciseWeight
    }

    private var currentRoutine: DayRoutine {
        store.routine(for: store.selectedWeekday)
    }

    private var isToday: Bool {
        store.selectedWeekday == Weekday.today()
    }

    private var titleBinding: Binding<String> {
        Binding(
            get: { currentRoutine.title },
            set: { title in
                var routine = currentRoutine
                routine.title = title
                store.updateRoutine(routine)
            }
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                SpottrTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        weekdaySelectorStrip
                        headerCard

                        if currentRoutine.isRestDay {
                            restDayCard
                        } else {
                            exercisesSection
                        }

                        Spacer().frame(height: 50)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                }
                .onChange(of: focusedField) { oldValue, newValue in
                    if oldValue == .title && newValue != .title {
                        checkMatchingTitle()
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .alert("Link to '\(autoLinkCandidate?.title ?? "")'?", isPresented: Binding(
                get: { autoLinkCandidate != nil },
                set: { if !$0 { autoLinkCandidate = nil } }
            ), presenting: autoLinkCandidate) { candidate in
                Button("Keep Standalone", role: .cancel) { autoLinkCandidate = nil }
                Button("Link Days") {
                    store.mergeAndLinkDays([store.selectedWeekday] + candidate.matchingDays, routineName: candidate.title)
                    autoLinkCandidate = nil
                }
            } message: { candidate in
                let daysStr = candidate.matchingDays.sorted().map { $0.fullName }.joined(separator: ", ")
                Text("\(daysStr) already uses the routine name '\(candidate.title)'. Linking will merge exercises so both days stay in sync.")
            }
        }
    }

    private var weekdaySelectorStrip: some View {
        HStack(spacing: 6) {
            ForEach(store.orderedWeekdays) { weekday in
                let isSelected = store.selectedWeekday == weekday
                let isCurrentDay = Weekday.today() == weekday
                let dayRoutine = store.routine(for: weekday)

                Button {
                    select(weekday: weekday)
                } label: {
                    VStack(spacing: 6) {
                        Text(weekday.singleLetter)
                            .font(.system(size: 18, weight: .black, design: .rounded))
                            .foregroundStyle(isSelected ? .black : (isCurrentDay ? SpottrTheme.accent : SpottrTheme.textSecondary))

                        Circle()
                            .fill(isSelected ? .black : (dayRoutine.isRestDay ? SpottrTheme.textMuted.opacity(0.3) : SpottrTheme.accent))
                            .frame(width: 6, height: 6)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(isSelected ? SpottrTheme.accent : SpottrTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(isSelected ? Color.clear : (isCurrentDay ? SpottrTheme.accent.opacity(0.4) : SpottrTheme.border), lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                Text(isToday ? "\(store.selectedWeekday.fullName.uppercased()) • TODAY" : store.selectedWeekday.fullName.uppercased())
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundStyle(SpottrTheme.textMuted)
                    .tracking(1.2)

                Spacer()

                if !currentRoutine.isRestDay && currentRoutine.totalCount > 0 {
                    Text("\(currentRoutine.completedCount) of \(currentRoutine.totalCount) done")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(currentRoutine.completedCount == currentRoutine.totalCount ? SpottrTheme.accent : SpottrTheme.textSecondary)
                }
            }

            HStack(alignment: .center, spacing: 12) {
                ZStack(alignment: .leading) {
                    TextField(currentRoutine.isRestDay ? "Rest Day" : "Workout Day", text: titleBinding)
                        .font(.system(size: 26, weight: .black, design: .rounded))
                        .foregroundStyle(currentRoutine.isRestDay ? SpottrTheme.restColor : SpottrTheme.textPrimary)
                        .focused($focusedField, equals: .title)
                        .submitLabel(.done)
                        .onSubmit {
                            checkMatchingTitle()
                        }

                    if !currentRoutine.isRestDay && currentRoutine.title.trimmingCharacters(in: .whitespaces).isEmpty {
                        HStack(spacing: 6) {
                            Text("Workout Day")
                                .font(.system(size: 26, weight: .black, design: .rounded))
                                .opacity(0)
                                .allowsHitTesting(false)

                            Menu {
                                copyWorkoutDaysMenu
                            } label: {
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 14, weight: .black, design: .rounded))
                                    .foregroundStyle(SpottrTheme.textMuted)
                                    .padding(.vertical, 8)
                                    .contentShape(Rectangle())
                            }
                        }
                    }
                }

                Button {
                    withAnimation(.spring(response: 0.3)) {
                        store.toggleRestDay(for: store.selectedWeekday)
                    }
                } label: {
                    Image(systemName: currentRoutine.isRestDay ? "dumbbell.fill" : "bed.double.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(currentRoutine.isRestDay ? SpottrTheme.accent : SpottrTheme.restColor)
                        .frame(width: 38, height: 38)
                        .background(SpottrTheme.cardSubtle)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }

            // Symmetric linked routine badge (read-only; unlinking and management is in Settings)
            if let link = store.routineLink(for: store.selectedWeekday), !currentRoutine.isRestDay {
                HStack(spacing: 6) {
                    Image(systemName: "link")
                        .font(.system(size: 11, weight: .bold))
                    let otherDays = link.assignedDays.filter { $0 != store.selectedWeekday }.sorted().map { $0.shortName }.joined(separator: ", ")
                    Text("Linked: \(link.name)\(otherDays.isEmpty ? "" : " (\(otherDays))")")
                        .font(.system(size: 11, weight: .bold, design: .rounded))

                    Spacer()
                }
                .foregroundStyle(SpottrTheme.accent.opacity(0.85))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(SpottrTheme.accent.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            if !currentRoutine.isRestDay && currentRoutine.totalCount > 0 {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(SpottrTheme.cardSubtle).frame(height: 4)
                        Capsule()
                            .fill(SpottrTheme.accent)
                            .frame(width: geo.size.width * CGFloat(Double(currentRoutine.completedCount) / Double(currentRoutine.totalCount)), height: 4)
                    }
                }
                .frame(height: 4)
            }
        }
        .spottrCard()
    }


    private var exercisesSection: some View {
        VStack(spacing: 10) {
            if !currentRoutine.exercises.isEmpty {
                HStack {
                    Text("EXERCISES (\(currentRoutine.exercises.count))")
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .foregroundStyle(SpottrTheme.textMuted)
                        .tracking(1.2)

                    Spacer()

                    if currentRoutine.exercises.count > 1 {
                        Button {
                            withAnimation(.spring(response: 0.3)) {
                                isReordering.toggle()
                                if isReordering {
                                    cancelExerciseEditing()
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: isReordering ? "checkmark" : "arrow.up.arrow.down")
                                    .font(.system(size: 11, weight: .bold))
                                Text(isReordering ? "Done" : "Reorder")
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                            }
                            .foregroundStyle(isReordering ? SpottrTheme.accent : SpottrTheme.textSecondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(isReordering ? SpottrTheme.accent.opacity(0.15) : SpottrTheme.cardSubtle)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 4)
                .padding(.top, 2)
            }

            if isReordering {
                ForEach(Array(currentRoutine.exercises.enumerated()), id: \.element.id) { index, exercise in
                    reorderExerciseRow(exercise, index: index)
                }
            } else {
                ForEach(currentRoutine.exercises) { exercise in
                    if editingExerciseID == exercise.id {
                        inlineExerciseEditor
                    } else {
                        exerciseRow(exercise)
                    }
                }

                if isAddingExercise {
                    inlineExerciseEditor
                } else {
                    Button {
                        beginAddingExercise()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 16, weight: .bold))
                            Text("Add Exercise")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                        }
                        .foregroundStyle(SpottrTheme.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(SpottrTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(SpottrTheme.accent.opacity(0.3), lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func exerciseRow(_ exercise: ExerciseItem) -> some View {
        HStack(spacing: 12) {
            Button {
                withAnimation(.spring(response: 0.25)) {
                    store.toggleExercise(weekday: store.selectedWeekday, exerciseId: exercise.id)
                }
            } label: {
                Image(systemName: exercise.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(exercise.isCompleted ? SpottrTheme.accent : SpottrTheme.textMuted)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.name)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(exercise.isCompleted ? SpottrTheme.textMuted : SpottrTheme.textPrimary)
                    .strikethrough(exercise.isCompleted, color: SpottrTheme.textMuted)

                let detail = exercise.formattedDetail(unit: store.weightUnit)
                if !detail.isEmpty {
                    Text(detail)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(SpottrTheme.textMuted)
                }
            }

            Spacer()

            Image(systemName: "pencil")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(SpottrTheme.textMuted)
        }
        .padding(14)
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .onTapGesture {
            beginEditing(exercise)
        }
        .background(SpottrTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(exercise.isCompleted ? SpottrTheme.accent.opacity(0.3) : SpottrTheme.border, lineWidth: 1)
        }
        .onDrag {
            draggedExerciseID = exercise.id
            return NSItemProvider(object: exercise.id.uuidString as NSString)
        }
        .onDrop(of: [UTType.text], delegate: ExerciseDropDelegate(
            item: exercise,
            currentRoutine: currentRoutine,
            draggedExerciseID: $draggedExerciseID,
            moveAction: { fromIdx, toIdx in
                withAnimation(.spring(response: 0.3)) {
                    store.moveExercise(in: store.selectedWeekday, fromIndex: fromIdx, toIndex: toIdx)
                }
            }
        ))
        .contextMenu {
            if let currentIndex = currentRoutine.exercises.firstIndex(where: { $0.id == exercise.id }) {
                if currentIndex > 0 {
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            store.moveExercise(in: store.selectedWeekday, exerciseId: exercise.id, direction: -1)
                        }
                    } label: {
                        Label("Move Up", systemImage: "arrow.up")
                    }
                }

                if currentIndex < currentRoutine.exercises.count - 1 {
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            store.moveExercise(in: store.selectedWeekday, exerciseId: exercise.id, direction: 1)
                        }
                    } label: {
                        Label("Move Down", systemImage: "arrow.down")
                    }
                }
            }

            Button {
                beginEditing(exercise)
            } label: {
                Label("Edit", systemImage: "pencil")
            }

            Button(role: .destructive) {
                store.deleteExercise(from: store.selectedWeekday, exerciseId: exercise.id)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func reorderExerciseRow(_ exercise: ExerciseItem, index: Int) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(SpottrTheme.textMuted)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.name)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(SpottrTheme.textPrimary)

                let detail = exercise.formattedDetail(unit: store.weightUnit)
                if !detail.isEmpty {
                    Text(detail)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(SpottrTheme.textMuted)
                }
            }

            Spacer()

            HStack(spacing: 6) {
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        store.moveExercise(in: store.selectedWeekday, exerciseId: exercise.id, direction: -1)
                    }
                } label: {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 12, weight: .bold))
                        .frame(width: 32, height: 32)
                        .background(SpottrTheme.cardSubtle)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(index == 0)
                .foregroundStyle(index == 0 ? SpottrTheme.textMuted.opacity(0.25) : SpottrTheme.accent)

                Button {
                    withAnimation(.spring(response: 0.3)) {
                        store.moveExercise(in: store.selectedWeekday, exerciseId: exercise.id, direction: 1)
                    }
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .frame(width: 32, height: 32)
                        .background(SpottrTheme.cardSubtle)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(index == currentRoutine.exercises.count - 1)
                .foregroundStyle(index == currentRoutine.exercises.count - 1 ? SpottrTheme.textMuted.opacity(0.25) : SpottrTheme.accent)
            }
        }
        .padding(14)
        .background(SpottrTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(draggedExerciseID == exercise.id ? SpottrTheme.accent : SpottrTheme.border, lineWidth: 1)
        }
        .onDrag {
            draggedExerciseID = exercise.id
            return NSItemProvider(object: exercise.id.uuidString as NSString)
        }
        .onDrop(of: [UTType.text], delegate: ExerciseDropDelegate(
            item: exercise,
            currentRoutine: currentRoutine,
            draggedExerciseID: $draggedExerciseID,
            moveAction: { fromIdx, toIdx in
                withAnimation(.spring(response: 0.3)) {
                    store.moveExercise(in: store.selectedWeekday, fromIndex: fromIdx, toIndex: toIdx)
                }
            }
        ))
    }

    private var inlineExerciseEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Exercise Name (e.g. Incline Bench)", text: $exerciseName)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(SpottrTheme.textPrimary)
                .focused($focusedField, equals: .exerciseName)

            HStack(spacing: 10) {
                TextField("Weight (\(store.weightUnit.rawValue))", text: $exerciseWeight)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .keyboardType(.numbersAndPunctuation)
                    .focused($focusedField, equals: .exerciseWeight)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(SpottrTheme.cardSubtle)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                Spacer()

                Button("Cancel") {
                    cancelExerciseEditing()
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(SpottrTheme.textMuted)

                Button(editingExerciseID == nil ? "Add" : "Save") {
                    saveExercise()
                }
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.black)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(exerciseName.trimmingCharacters(in: .whitespaces).isEmpty ? SpottrTheme.cardSubtle : SpottrTheme.accent)
                .clipShape(Capsule())
                .disabled(exerciseName.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            if let exerciseID = editingExerciseID,
               let currentIndex = currentRoutine.exercises.firstIndex(where: { $0.id == exerciseID }) {
                HStack {
                    Button(role: .destructive) {
                        store.deleteExercise(from: store.selectedWeekday, exerciseId: exerciseID)
                        cancelExerciseEditing()
                    } label: {
                        Label("Delete", systemImage: "trash")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(.red)

                    Spacer()

                    if currentRoutine.exercises.count > 1 {
                        HStack(spacing: 8) {
                            Text("Position:")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(SpottrTheme.textMuted)

                            Button {
                                withAnimation(.spring(response: 0.3)) {
                                    store.moveExercise(in: store.selectedWeekday, exerciseId: exerciseID, direction: -1)
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "chevron.up")
                                    Text("Up")
                                }
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(SpottrTheme.cardSubtle)
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                            .disabled(currentIndex == 0)
                            .foregroundStyle(currentIndex == 0 ? SpottrTheme.textMuted.opacity(0.3) : SpottrTheme.accent)

                            Button {
                                withAnimation(.spring(response: 0.3)) {
                                    store.moveExercise(in: store.selectedWeekday, exerciseId: exerciseID, direction: 1)
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "chevron.down")
                                    Text("Down")
                                }
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(SpottrTheme.cardSubtle)
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                            .disabled(currentIndex == currentRoutine.exercises.count - 1)
                            .foregroundStyle(currentIndex == currentRoutine.exercises.count - 1 ? SpottrTheme.textMuted.opacity(0.3) : SpottrTheme.accent)
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
        .spottrCard(padding: 14)
    }

    private var restDayCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "bed.double.fill")
                .font(.system(size: 36))
                .foregroundStyle(SpottrTheme.restColor)
                .padding(.top, 8)

            Text("Rest & Recovery")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(SpottrTheme.textPrimary)

            Text("Tap the dumbbell icon above to switch to a workout day.")
                .font(.system(size: 13))
                .foregroundStyle(SpottrTheme.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
        }
        .frame(maxWidth: .infinity)
        .spottrCard(padding: 24)
    }

    private func select(weekday: Weekday) {
        withAnimation(.spring(response: 0.3)) {
            store.selectedWeekday = weekday
            isReordering = false
            cancelExerciseEditing()
            focusedField = nil
        }
    }

    private func beginAddingExercise() {
        withAnimation(.spring(response: 0.3)) {
            isReordering = false
            editingExerciseID = nil
            isAddingExercise = true
            exerciseName = ""
            exerciseWeight = ""
            focusedField = .exerciseName
        }
    }

    private func beginEditing(_ exercise: ExerciseItem) {
        withAnimation(.spring(response: 0.3)) {
            isReordering = false
            isAddingExercise = false
            editingExerciseID = exercise.id
            exerciseName = exercise.name
            exerciseWeight = exercise.weight
            focusedField = .exerciseName
        }
    }

    private func saveExercise() {
        let trimmedName = exerciseName.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        if let exerciseID = editingExerciseID,
           var exercise = currentRoutine.exercises.first(where: { $0.id == exerciseID }) {
            exercise.name = trimmedName
            exercise.weight = exerciseWeight.trimmingCharacters(in: .whitespaces)
            store.updateExercise(weekday: store.selectedWeekday, exercise: exercise)
        } else {
            store.addExercise(to: store.selectedWeekday, name: trimmedName, weight: exerciseWeight)
        }
        cancelExerciseEditing()
    }

    private func cancelExerciseEditing() {
        withAnimation(.spring(response: 0.25)) {
            isAddingExercise = false
            editingExerciseID = nil
            exerciseName = ""
            exerciseWeight = ""
            if focusedField == .exerciseName || focusedField == .exerciseWeight {
                focusedField = nil
            }
        }
    }

    private var availableWorkoutDays: [Weekday] {
        store.orderedWeekdays.filter { weekday in
            guard weekday != store.selectedWeekday else { return false }
            let r = store.routine(for: weekday)
            return !r.isRestDay && (!r.title.trimmingCharacters(in: .whitespaces).isEmpty || !r.exercises.isEmpty)
        }
    }

    @ViewBuilder
    private var copyWorkoutDaysMenu: some View {
        if availableWorkoutDays.isEmpty {
            Button {} label: {
                Label("No other workout days to copy", systemImage: "info.circle")
            }
            .disabled(true)
        } else {
            ForEach(availableWorkoutDays) { weekday in
                let r = store.routine(for: weekday)
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        focusedField = nil
                        store.copyAndLinkDay(from: weekday, to: store.selectedWeekday)
                    }
                } label: {
                    let workoutTitle = r.title.isEmpty ? weekday.fullName : r.title
                    let countStr = r.exercises.count == 1 ? "1 exercise" : "\(r.exercises.count) exercises"
                    let linked = r.routineLinkId != nil ? " 🔗" : ""
                    Label("\(weekday.fullName): \(workoutTitle)\(linked) (\(countStr))", systemImage: "link")
                }
            }
        }
    }

    private func checkMatchingTitle() {
        let title = currentRoutine.title.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty, !currentRoutine.isRestDay else { return }

        if let match = store.findMatchingDaysOrLink(for: store.selectedWeekday, title: title) {
            autoLinkCandidate = AutoLinkCandidate(title: match.linkName, matchingDays: match.matchingDays)
        }
    }
}

// MARK: - Exercise Drop Delegate for Drag & Drop Reordering
struct ExerciseDropDelegate: DropDelegate {
    let item: ExerciseItem
    let currentRoutine: DayRoutine
    @Binding var draggedExerciseID: UUID?
    let moveAction: (Int, Int) -> Void

    func dropEntered(info: DropInfo) {
        guard let draggedID = draggedExerciseID,
              draggedID != item.id,
              let from = currentRoutine.exercises.firstIndex(where: { $0.id == draggedID }),
              let to = currentRoutine.exercises.firstIndex(where: { $0.id == item.id }) else { return }

        moveAction(from, to)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedExerciseID = nil
        return true
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
}

#Preview {
    SplitView()
        .environmentObject(SpottrStore())
}
