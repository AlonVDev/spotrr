//
//  FriendsView.swift
//  spotrr
//
//  Created by Spottr on 28/08/2026.
//

import SwiftUI

struct FriendsView: View {
    @EnvironmentObject var store: SpottrStore

    var body: some View {
        NavigationStack {
            ZStack {
                SpottrTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(store.friends) { friend in
                            friendCard(friend: friend)
                        }

                        Spacer().frame(height: 30)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
            .navigationTitle("Friends")
        }
    }

    private func friendCard(friend: FriendStatus) -> some View {
        HStack(spacing: 12) {
            // Initials Avatar
            Circle()
                .fill(SpottrTheme.cardSubtle)
                .frame(width: 44, height: 44)
                .overlay(
                    Text(friend.initials)
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundStyle(SpottrTheme.accent)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(friend.name)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(SpottrTheme.textPrimary)

                HStack(spacing: 6) {
                    Text(friend.splitTitle)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(friend.isRestDay ? SpottrTheme.green : SpottrTheme.textSecondary)

                    if !friend.isRestDay && friend.totalCount > 0 {
                        Text("•")
                            .foregroundStyle(SpottrTheme.textMuted)
                        Text("\(friend.completedCount)/\(friend.totalCount) done")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(friend.completedCount == friend.totalCount ? SpottrTheme.accent : SpottrTheme.textMuted)
                    }
                }
            }

            Spacer()

            // Fist-bump button
            Button {
                withAnimation(.spring(response: 0.25)) {
                    store.toggleFistBump(for: friend.id)
                }
            } label: {
                Text("👊")
                    .font(.system(size: 18))
                    .padding(10)
                    .background(friend.hasBumped ? SpottrTheme.accentMuted : SpottrTheme.cardSubtle)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(friend.hasBumped ? SpottrTheme.accent.opacity(0.5) : Color.clear, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        }
        .spottrCard(padding: 14)
    }
}

#Preview {
    FriendsView()
        .environmentObject(SpottrStore())
}

