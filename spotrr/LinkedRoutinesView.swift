//
//  LinkedRoutinesView.swift
//  spotrr
//
//  Created by Spottr on 28/08/2026.
//

import SwiftUI

struct LinkedRoutinesView: View {
    @EnvironmentObject var store: SpottrStore

    @State private var showCreateSheet = false
    @State private var editingLinkId: UUID? = nil

    private var sortedLinks: [RoutineLink] {
        store.routineLinks.values.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        ZStack {
            SpottrTheme.background.ignoresSafeArea()

            if sortedLinks.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: 14) {
                        ForEach(sortedLinks) { link in
                            linkedRoutineCard(link)
                        }
                        Spacer().frame(height: 40)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                }
            }
        }
        .navigationTitle("Linked Routines")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showCreateSheet = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(SpottrTheme.accent)
                }
            }
        }
        .sheet(isPresented: $showCreateSheet) {
            CreateRoutineLinkSheet()
        }
        .sheet(item: Binding<RoutineLinkIdentifier?>(
            get: { editingLinkId.map { RoutineLinkIdentifier(id: $0) } },
            set: { editingLinkId = $0?.id }
        )) { item in
            EditRoutineLinkSheet(linkId: item.id)
        }
    }

    private func linkedRoutineCard(_ link: RoutineLink) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "link")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(SpottrTheme.accent)

                    Text(link.name)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(SpottrTheme.textPrimary)
                }

                Spacer()

                Button {
                    editingLinkId = link.id
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Manage")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(SpottrTheme.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(SpottrTheme.cardSubtle)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            // Symmetric day pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(link.assignedDays.sorted()) { weekday in
                        HStack(spacing: 6) {
                            Text(weekday.fullName)
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(SpottrTheme.accent)

                            Button {
                                withAnimation(.spring(response: 0.3)) {
                                    store.unlinkDay(weekday)
                                }
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 9, weight: .black))
                                    .foregroundStyle(SpottrTheme.accent.opacity(0.7))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(SpottrTheme.accent.opacity(0.12))
                        .clipShape(Capsule())
                    }
                }
            }

            // // Exercise count info
            // if !link.exercises.isEmpty {
            //     Text("\(link.exercises.count) exercise\(link.exercises.count == 1 ? "" : "s") shared symmetrically")
            //         .font(.system(size: 12, weight: .medium, design: .rounded))
            //         .foregroundStyle(SpottrTheme.textMuted)
            // }
        }
        .spottrCard()
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "link.badge.plus")
                .font(.system(size: 48))
                .foregroundStyle(SpottrTheme.accent.opacity(0.5))

            Text("No Linked Routines")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(SpottrTheme.textPrimary)

            Text("Link two or more days to share a single routine. Changes on any linked day instantly sync across all of them.")
                .font(.system(size: 14))
                .foregroundStyle(SpottrTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button {
                showCreateSheet = true
            } label: {
                Label("Create Link", systemImage: "plus")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(SpottrTheme.accent)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct RoutineLinkIdentifier: Identifiable {
    let id: UUID
}

// MARK: - Create Routine Link Sheet

struct CreateRoutineLinkSheet: View {
    @EnvironmentObject var store: SpottrStore
    @Environment(\.dismiss) private var dismiss

    @State private var routineName = ""
    @State private var selectedDays: Set<Weekday> = []

    private var canCreate: Bool {
        selectedDays.count >= 2
    }

    var body: some View {
        NavigationStack {
            ZStack {
                SpottrTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Name field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("ROUTINE NAME")
                                .font(.system(size: 11, weight: .heavy, design: .rounded))
                                .foregroundStyle(SpottrTheme.textMuted)
                                .tracking(1.2)
                                .padding(.horizontal, 4)

                            TextField("e.g. Push A, Pull Day, Upper Body...", text: $routineName)
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundStyle(SpottrTheme.textPrimary)
                                .spottrCard()
                        }

                        // Day picker
                        VStack(alignment: .leading, spacing: 8) {
                            Text("SELECT DAYS TO LINK (minimum 2)")
                                .font(.system(size: 11, weight: .heavy, design: .rounded))
                                .foregroundStyle(SpottrTheme.textMuted)
                                .tracking(1.2)
                                .padding(.horizontal, 4)

                            VStack(spacing: 0) {
                                ForEach(store.orderedWeekdays) { weekday in
                                    let isSelected = selectedDays.contains(weekday)
                                    let currentRoutine = store.routine(for: weekday)

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
                                                if !currentRoutine.title.isEmpty {
                                                    Text(currentRoutine.title)
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
                                        .padding(.vertical, 14)
                                    }
                                    .buttonStyle(.plain)

                                    if weekday != store.orderedWeekdays.last {
                                        Divider()
                                            .overlay(SpottrTheme.border)
                                            .padding(.horizontal, 16)
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

                        Button {
                            let name = routineName.trimmingCharacters(in: .whitespaces)
                            store.createRoutineLink(name: name, days: Array(selectedDays))
                            dismiss()
                        } label: {
                            Text("Create Linked Routine")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(canCreate ? SpottrTheme.accent : SpottrTheme.cardSubtle)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .disabled(!canCreate)

                        Spacer().frame(height: 20)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("New Linked Routine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(SpottrTheme.textMuted)
                }
            }
        }
    }
}

// MARK: - Edit Routine Link Sheet

struct EditRoutineLinkSheet: View {
    @EnvironmentObject var store: SpottrStore
    @Environment(\.dismiss) private var dismiss

    let linkId: UUID
    @State private var routineName: String = ""

    private var currentLink: RoutineLink? {
        store.routineLinks[linkId]
    }

    var body: some View {
        NavigationStack {
            ZStack {
                SpottrTheme.background.ignoresSafeArea()

                if let link = currentLink {
                    ScrollView {
                        VStack(spacing: 20) {
                            // Routine Name
                            VStack(alignment: .leading, spacing: 8) {
                                Text("ROUTINE NAME")
                                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                                    .foregroundStyle(SpottrTheme.textMuted)
                                    .tracking(1.2)
                                    .padding(.horizontal, 4)

                                TextField("Routine name", text: $routineName)
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    .foregroundStyle(SpottrTheme.textPrimary)
                                    .spottrCard()
                            }

                            // Manage Bound Days
                            VStack(alignment: .leading, spacing: 8) {
                                Text("BOUND DAYS (Tap to bind or unbind)")
                                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                                    .foregroundStyle(SpottrTheme.textMuted)
                                    .tracking(1.2)
                                    .padding(.horizontal, 4)

                                VStack(spacing: 0) {
                                    ForEach(store.orderedWeekdays) { weekday in
                                        let isBound = link.assignedDays.contains(weekday)
                                        let dayRoutine = store.routine(for: weekday)

                                        Button {
                                            withAnimation(.spring(response: 0.3)) {
                                                if isBound {
                                                    store.unbindDayFromRoutineLink(weekday, linkId: link.id)
                                                    if (store.routineLinks[link.id]?.assignedDays.count ?? 0) < 2 {
                                                        dismiss()
                                                    }
                                                } else {
                                                    store.bindDayToRoutineLink(weekday, linkId: link.id)
                                                }
                                            }
                                        } label: {
                                            HStack {
                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text(weekday.fullName)
                                                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                                                        .foregroundStyle(SpottrTheme.textPrimary)

                                                    if !isBound && !dayRoutine.title.isEmpty {
                                                        Text("Currently: \(dayRoutine.title)")
                                                            .font(.system(size: 12, design: .rounded))
                                                            .foregroundStyle(SpottrTheme.textMuted)
                                                    }
                                                }

                                                Spacer()

                                                Image(systemName: isBound ? "checkmark.circle.fill" : "circle")
                                                    .font(.system(size: 20))
                                                    .foregroundStyle(isBound ? SpottrTheme.accent : SpottrTheme.textMuted)
                                            }
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 14)
                                        }
                                        .buttonStyle(.plain)

                                        if weekday != store.orderedWeekdays.last {
                                            Divider()
                                                .overlay(SpottrTheme.border)
                                                .padding(.horizontal, 16)
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

                            // Delete Link Button
                            Button(role: .destructive) {
                                store.deleteRoutineLink(id: link.id)
                                dismiss()
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "trash")
                                    Text("Dissolve Routine Link")
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

                            Spacer().frame(height: 20)
                        }
                        .padding(20)
                    }
                }
            }
            .navigationTitle("Manage Linked Routine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(SpottrTheme.textMuted)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let name = routineName.trimmingCharacters(in: .whitespaces)
                        if !name.isEmpty {
                            store.renameRoutineLink(id: linkId, name: name)
                        }
                        dismiss()
                    }
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(SpottrTheme.accent)
                }
            }
            .onAppear {
                if let link = currentLink {
                    routineName = link.name
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        LinkedRoutinesView()
            .environmentObject(SpottrStore())
    }
}
