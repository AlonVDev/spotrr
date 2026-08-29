//
//  SettingsView.swift
//  spotrr
//
//  Created by Spottr on 28/08/2026.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: SpottrStore
    @State private var showResetConfirmation: Bool = false

    var body: some View {
        NavigationStack {
            ZStack {
                SpottrTheme.background.ignoresSafeArea()

                Form {
                    // Preferences Section
                    Section {
                        HStack {
                            Label("Weight Unit", systemImage: "scalemass.fill")
                                .foregroundStyle(SpottrTheme.textPrimary)
                            Spacer()
                            Picker("", selection: $store.weightUnit) {
                                ForEach(WeightUnit.allCases) { unit in
                                    Text(unit.uppercaseName).tag(unit)
                                }
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 140)
                        }

                        HStack {
                            Label("Week Format", systemImage: "calendar")
                                .foregroundStyle(SpottrTheme.textPrimary)
                            Spacer()
                            Picker("", selection: $store.weekStart) {
                                ForEach(WeekStart.allCases) { start in
                                    Text(start.rawValue).tag(start)
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(SpottrTheme.accent)
                        }

                        Toggle(isOn: $store.autoResetDaily) {
                            Label("Auto-Reset Checks Daily", systemImage: "arrow.counterclockwise.circle.fill")
                                .foregroundStyle(SpottrTheme.textPrimary)
                        }
                        .tint(SpottrTheme.accent)
                    } header: {
                        Text("PREFERENCES")
                            .font(.system(size: 11, weight: .heavy, design: .rounded))
                            .foregroundStyle(SpottrTheme.textMuted)
                    } footer: {
                        Text("When auto-reset is enabled, today's checkmarks will be refreshed each morning.")
                            .font(.system(size: 12))
                            .foregroundStyle(SpottrTheme.textMuted)
                    }
                    .listRowBackground(SpottrTheme.card)

                    // Data Section
                    Section {
                        ShareLink(
                            item: store.exportSplitAsText(),
                            subject: Text("My Gym Split"),
                            message: Text("Here is my weekly workout split organized in Spottr!")
                        ) {
                            Label("Share Split with Buddy", systemImage: "square.and.arrow.up.fill")
                                .foregroundStyle(SpottrTheme.textPrimary)
                        }

                        Button(role: .destructive) {
                            showResetConfirmation = true
                        } label: {
                            Label("Reset to Default Split", systemImage: "trash")
                                .foregroundStyle(.red)
                        }
                    } header: {
                        Text("DATA")
                            .font(.system(size: 11, weight: .heavy, design: .rounded))
                            .foregroundStyle(SpottrTheme.textMuted)
                    }
                    .listRowBackground(SpottrTheme.card)

                    // About Section
                    Section {
                        HStack {
                            Text("Version")
                                .foregroundStyle(SpottrTheme.textPrimary)
                            Spacer()
                            Text("1.0.0")
                                .foregroundStyle(SpottrTheme.textMuted)
                        }
                    } header: {
                        Text("ABOUT")
                            .font(.system(size: 11, weight: .heavy, design: .rounded))
                            .foregroundStyle(SpottrTheme.textMuted)
                    }
                    .listRowBackground(SpottrTheme.card)
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Settings")
            .alert("Reset to Default Split?", isPresented: $showResetConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) {
                    store.resetToDefaultSplit()
                }
            } message: {
                Text("This will replace your current weekly schedule with the starter template.")
            }
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(SpottrStore())
}
