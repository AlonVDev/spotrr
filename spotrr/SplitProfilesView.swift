//
//  SplitProfilesView.swift
//  spotrr
//
//  Created by Spottr on 11/10/2026.
//

import SwiftUI

struct SplitProfilesView: View {
    @EnvironmentObject var store: SpottrStore

    @State private var showCreateSheet = false
    @State private var profileToRename: SplitProfile? = nil
    @State private var newProfileName = ""
    @State private var duplicateCurrent = true

    var body: some View {
        ZStack {
            SpottrTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 14) {
                    ForEach(store.splitProfiles) { profile in
                        profileCard(profile)
                    }

                    Spacer().frame(height: 40)
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
            }
        }
        .navigationTitle("Split Profiles")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    newProfileName = ""
                    duplicateCurrent = true
                    showCreateSheet = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(SpottrTheme.accent)
                }
            }
        }
        .sheet(isPresented: $showCreateSheet) {
            createProfileSheet
        }
        .alert("Rename Split Profile", isPresented: Binding(
            get: { profileToRename != nil },
            set: { if !$0 { profileToRename = nil } }
        )) {
            TextField("Profile Name", text: $newProfileName)
            Button("Cancel", role: .cancel) { profileToRename = nil }
            Button("Save") {
                if let p = profileToRename {
                    store.renameProfile(id: p.id, name: newProfileName)
                    profileToRename = nil
                }
            }
        } message: {
            Text("Enter a new name for this routine profile.")
        }
    }

    private func profileCard(_ profile: SplitProfile) -> some View {
        Button {
            if !profile.isActive {
                store.activateProfile(id: profile.id)
            }
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 10) {
                    Image(systemName: profile.isActive ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(profile.isActive ? SpottrTheme.accent : SpottrTheme.textMuted)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(profile.name)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(SpottrTheme.textPrimary)

                        if profile.isActive {
                            Text("ACTIVE PROFILE")
                                .font(.system(size: 10, weight: .heavy, design: .rounded))
                                .foregroundStyle(SpottrTheme.accent)
                                .tracking(1.0)
                        }
                    }

                    Spacer()

                    Menu {
                        Button {
                            newProfileName = profile.name
                            profileToRename = profile
                        } label: {
                            Label("Rename", systemImage: "pencil")
                        }

                        Button {
                            store.duplicateProfile(id: profile.id)
                        } label: {
                            Label("Duplicate", systemImage: "doc.on.doc")
                        }

                        if store.splitProfiles.count > 1 {
                            Button(role: .destructive) {
                                store.deleteProfile(id: profile.id)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(SpottrTheme.textMuted)
                            .frame(width: 32, height: 32)
                            .background(SpottrTheme.cardSubtle)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }

                Divider().overlay(SpottrTheme.border)

                // Quick overview of days in this profile
                let daysSummary = summaryOfDays(profile)
                Text(daysSummary)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(SpottrTheme.textSecondary)
                    .lineLimit(2)
            }
            .padding(14)
            .background(SpottrTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(profile.isActive ? SpottrTheme.accent.opacity(0.4) : SpottrTheme.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func summaryOfDays(_ profile: SplitProfile) -> String {
        var parts: [String] = []
        for weekday in store.orderedWeekdays {
            if let routine = profile.routines[weekday] {
                if !routine.isRestDay && !routine.title.isEmpty {
                    parts.append("\(weekday.shortName): \(routine.title)")
                }
            }
        }
        if parts.isEmpty {
            return "Empty Schedule (No workout days configured yet)"
        }
        return parts.joined(separator: " • ")
    }

    private var createProfileSheet: some View {
        NavigationStack {
            ZStack {
                SpottrTheme.background.ignoresSafeArea()

                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("PROFILE NAME")
                            .font(.system(size: 11, weight: .heavy, design: .rounded))
                            .foregroundStyle(SpottrTheme.textMuted)
                            .tracking(1.2)
                            .padding(.horizontal, 4)

                        TextField("e.g. Hypertrophy PPL, Strength Upper/Lower", text: $newProfileName)
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(SpottrTheme.textPrimary)
                            .spottrCard()
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("STARTING TEMPLATE")
                            .font(.system(size: 11, weight: .heavy, design: .rounded))
                            .foregroundStyle(SpottrTheme.textMuted)
                            .tracking(1.2)
                            .padding(.horizontal, 4)

                        VStack(spacing: 0) {
                            Button {
                                duplicateCurrent = true
                                store.triggerHaptic(.light)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Duplicate Current Split")
                                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                                            .foregroundStyle(SpottrTheme.textPrimary)
                                        Text("Clone current days and exercises into this new profile")
                                            .font(.system(size: 12, design: .rounded))
                                            .foregroundStyle(SpottrTheme.textMuted)
                                    }
                                    Spacer()
                                    Image(systemName: duplicateCurrent ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(duplicateCurrent ? SpottrTheme.accent : SpottrTheme.textMuted)
                                }
                                .padding(16)
                            }
                            .buttonStyle(.plain)

                            Divider().overlay(SpottrTheme.border)

                            Button {
                                duplicateCurrent = false
                                store.triggerHaptic(.light)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Empty Split")
                                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                                            .foregroundStyle(SpottrTheme.textPrimary)
                                        Text("Start fresh with no assigned days")
                                            .font(.system(size: 12, design: .rounded))
                                            .foregroundStyle(SpottrTheme.textMuted)
                                    }
                                    Spacer()
                                    Image(systemName: !duplicateCurrent ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(!duplicateCurrent ? SpottrTheme.accent : SpottrTheme.textMuted)
                                }
                                .padding(16)
                            }
                            .buttonStyle(.plain)
                        }
                        .background(SpottrTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(SpottrTheme.border, lineWidth: 1)
                        )
                    }

                    Spacer()
                }
                .padding(20)
            }
            .navigationTitle("New Split Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showCreateSheet = false }
                        .foregroundStyle(SpottrTheme.textMuted)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        store.createProfile(name: newProfileName, duplicateCurrent: duplicateCurrent)
                        showCreateSheet = false
                    }
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(newProfileName.trimmingCharacters(in: .whitespaces).isEmpty ? SpottrTheme.textMuted : SpottrTheme.accent)
                    .disabled(newProfileName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        SplitProfilesView()
            .environmentObject(SpottrStore())
    }
}
