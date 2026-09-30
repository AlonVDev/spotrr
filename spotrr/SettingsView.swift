//
//  SettingsView.swift
//  spotrr
//
//  Created by Spottr on 28/08/2026.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: SpottrStore
    @State private var showClearConfirmation: Bool = false
    @State private var showExportSheet: Bool = false

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
                            Label("First Day of Week", systemImage: "calendar")
                                .foregroundStyle(SpottrTheme.textPrimary)
                            Spacer()
                            Picker("", selection: $store.weekStart) {
                                ForEach(WeekStart.allCases) { start in
                                    Text(start.rawValue).tag(start)
                                }
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 140)
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

                    // Library Section
                    Section {
                        NavigationLink(destination: ExerciseLibraryView()) {
                            Label("Exercise Library", systemImage: "dumbbell.fill")
                                .foregroundStyle(SpottrTheme.textPrimary)
                        }

                        NavigationLink(destination: LinkedRoutinesView()) {
                            Label("Linked Routines", systemImage: "link")
                                .foregroundStyle(SpottrTheme.textPrimary)
                        }
                    } header: {
                        Text("LIBRARY")
                            .font(.system(size: 11, weight: .heavy, design: .rounded))
                            .foregroundStyle(SpottrTheme.textMuted)
                    }
                    .listRowBackground(SpottrTheme.card)

                    // Data Section
                    Section {
                        Button {
                            showExportSheet = true
                        } label: {
                            HStack {
                                Label("Export & Share Split", systemImage: "square.and.arrow.up.fill")
                                    .foregroundStyle(SpottrTheme.textPrimary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(SpottrTheme.textMuted)
                            }
                        }

                        Button(role: .destructive) {
                            showClearConfirmation = true
                        } label: {
                            Label("Clear Split", systemImage: "trash")
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
                            Label("Version", systemImage: "info.circle.fill")
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
            .alert("Clear Split?", isPresented: $showClearConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Clear", role: .destructive) {
                    store.clearSplit()
                }
            } message: {
                Text("This will remove every workout, rest day, and exercise from your split.")
            }
            .sheet(isPresented: $showExportSheet) {
                ExportSplitSheet()
            }
        }
    }
}

// MARK: - Export Split Customization Sheet

struct ExportSplitSheet: View {
    @EnvironmentObject var store: SpottrStore
    @Environment(\.dismiss) private var dismiss

    @State private var includeRestDays: Bool = true
    @State private var includeExercises: Bool = true
    @State private var includeWeights: Bool = true
    @State private var showCopiedToast: Bool = false

    private var formattedExportText: String {
        store.exportSplitAsText(
            includeRestDays: includeRestDays,
            includeExercises: includeExercises,
            includeWeights: includeWeights
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                SpottrTheme.background.ignoresSafeArea()

                VStack(spacing: 20) {
                    // Customization Toggles Card
                    VStack(spacing: 12) {
                        Toggle("Include Rest Days", isOn: $includeRestDays)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(SpottrTheme.textPrimary)
                            .tint(SpottrTheme.accent)

                        Divider()
                            .overlay(SpottrTheme.border)

                        Toggle("Include Exercises", isOn: $includeExercises)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(SpottrTheme.textPrimary)
                            .tint(SpottrTheme.accent)
                            .onChange(of: includeExercises) { newValue in
                                if !newValue {
                                    includeWeights = false
                                }
                            }

                        Divider()
                            .overlay(SpottrTheme.border)

                        Toggle("Include Weight Numbers", isOn: $includeWeights)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(includeExercises ? SpottrTheme.textPrimary : SpottrTheme.textMuted)
                            .tint(SpottrTheme.accent)
                            .disabled(!includeExercises)
                    }
                    .spottrCard(padding: 16)

                    // Preview Section Header
                    HStack {
                        Text("LIVE PREVIEW")
                            .font(.system(size: 11, weight: .heavy, design: .rounded))
                            .foregroundStyle(SpottrTheme.textMuted)
                            .tracking(1.2)
                        Spacer()
                    }
                    .padding(.horizontal, 4)

                    // Live Preview Scroll Box
                    ScrollView {
                        Text(formattedExportText)
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundStyle(SpottrTheme.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                    }
                    .background(SpottrTheme.cardSubtle)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(SpottrTheme.border, lineWidth: 1)
                    )

                    Spacer()

                    // Bottom Action Bar (Copy & Share)
                    HStack(spacing: 12) {
                        Button {
                            UIPasteboard.general.string = formattedExportText
                            store.triggerHaptic(.medium)
                            withAnimation(.spring(response: 0.3)) {
                                showCopiedToast = true
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                withAnimation {
                                    showCopiedToast = false
                                }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: showCopiedToast ? "checkmark.circle.fill" : "doc.on.doc.fill")
                                Text(showCopiedToast ? "Copied!" : "Copy")
                            }
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(showCopiedToast ? SpottrTheme.accent : SpottrTheme.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(SpottrTheme.card)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(showCopiedToast ? SpottrTheme.accent.opacity(0.5) : SpottrTheme.border, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)

                        ShareLink(
                            item: formattedExportText,
                            subject: Text("My Gym Split"),
                            message: Text("\n Join my workout on Spottr!")
                        ) {
                            HStack(spacing: 6) {
                                Image(systemName: "square.and.arrow.up.fill")
                                Text("Share Split")
                            }
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(SpottrTheme.accent)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(20)
            }
            .navigationTitle("Export Split Options")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(SpottrTheme.accent)
                }
            }
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(SpottrStore())
}
