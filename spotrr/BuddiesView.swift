//
//  BuddiesView.swift
//  spotrr
//
//  Created by Spottr on 28/08/2026.
//

import SwiftUI

struct BuddiesView: View {
    @EnvironmentObject var store: SpottrStore

    var body: some View {
        NavigationStack {
            ZStack {
                SpottrTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(store.buddies) { buddy in
                            buddyCard(buddy: buddy)
                        }

                        Spacer().frame(height: 30)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
            .navigationTitle("Buddies")
        }
    }

    private func buddyCard(buddy: FriendStatus) -> some View {
        HStack(spacing: 12) {
            // Initials Avatar
            Circle()
                .fill(SpottrTheme.cardSubtle)
                .frame(width: 44, height: 44)
                .overlay(
                    Text(buddy.initials)
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundStyle(SpottrTheme.accent)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(buddy.name)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(SpottrTheme.textPrimary)

                HStack(spacing: 6) {
                    Text(buddy.splitTitle)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(buddy.isRestDay ? SpottrTheme.green : SpottrTheme.textSecondary)

                    if !buddy.isRestDay && buddy.totalCount > 0 {
                        Text("•")
                            .foregroundStyle(SpottrTheme.textMuted)
                        Text("\(buddy.completedCount)/\(buddy.totalCount) done")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(buddy.completedCount == buddy.totalCount ? SpottrTheme.accent : SpottrTheme.textMuted)
                    }
                }
            }

            Spacer()

            // Fist-bump button
            Button {
                withAnimation(.spring(response: 0.25)) {
                    store.toggleFistBump(for: buddy.id)
                }
            } label: {
                Text("👊")
                    .font(.system(size: 18))
                    .padding(10)
                    .background(buddy.hasBumped ? SpottrTheme.accentMuted : SpottrTheme.cardSubtle)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(buddy.hasBumped ? SpottrTheme.accent.opacity(0.5) : Color.clear, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        }
        .spottrCard(padding: 14)
    }
}

#Preview {
    BuddiesView()
        .environmentObject(SpottrStore())
}

