//
//  BuddiesView.swift
//  spotrr
//
//  Created by Spottr on 28/08/2026.
//

import SwiftUI

struct BuddiesView: View {
    @State private var viewModel = BuddiesViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                SpottrTheme.background.ignoresSafeArea()

                VStack(spacing: 12) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 40, weight: .semibold))
                        .foregroundStyle(SpottrTheme.accent)

                    Text("Coming Soon")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(SpottrTheme.textPrimary)
                }
            }
            .navigationTitle("Buddies")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(SpottrTheme.textMuted)

            TextField("Search @username or name...", text: $viewModel.searchText)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(SpottrTheme.textPrimary)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

            if !viewModel.searchText.isEmpty {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.searchText = ""
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(SpottrTheme.textMuted)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(SpottrTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(viewModel.isSearching ? SpottrTheme.accent.opacity(0.4) : SpottrTheme.border, lineWidth: 1)
        )
    }

    // MARK: - Search Results Section

    private var searchResultsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("SEARCH RESULTS (\(viewModel.searchResults.count))")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundStyle(SpottrTheme.textMuted)
                    .tracking(1.2)

                Spacer()

                Button("Clear") {
                    withAnimation {
                        viewModel.searchText = ""
                    }
                }
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(SpottrTheme.accent)
            }
            .padding(.horizontal, 4)

            if viewModel.searchResults.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "person.crop.circle.badge.questionmark")
                        .font(.system(size: 32))
                        .foregroundStyle(SpottrTheme.textMuted)
                        .padding(.top, 12)

                    Text("No users found")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(SpottrTheme.textPrimary)

                    Text("No one matches \"\(viewModel.searchText)\". Try searching by exact @username.")
                        .font(.system(size: 13))
                        .foregroundStyle(SpottrTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                }
                .frame(maxWidth: .infinity)
                .spottrCard(padding: 20)
            } else {
                ForEach(viewModel.searchResults, id: \.user.id) { item in
                    searchResultCard(user: item.user, status: item.status)
                }
            }
        }
    }

    private func searchResultCard(user: UserProfile, status: FriendshipStatus) -> some View {
        HStack(spacing: 12) {
            // Avatar
            Circle()
                .fill(SpottrTheme.cardSubtle)
                .frame(width: 44, height: 44)
                .overlay(
                    Text(user.initials)
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundStyle(SpottrTheme.accent)
                )

            // Name & Handle
            VStack(alignment: .leading, spacing: 2) {
                Text(user.displayName)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(SpottrTheme.textPrimary)

                Text(user.formattedHandle)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(SpottrTheme.textMuted)
            }

            Spacer()

            // Dynamic Trailing Button based on Friendship Status
            searchActionButton(user: user, status: status)
        }
        .spottrCard(padding: 14)
    }

    @ViewBuilder
    private func searchActionButton(user: UserProfile, status: FriendshipStatus) -> some View {
        switch status {
        case .none, .blocked:
            Button {
                withAnimation(.spring(response: 0.3)) {
                    viewModel.sendFriendRequest(to: user)
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 12, weight: .bold))
                    Text("Add Friend")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                }
                .foregroundStyle(.black)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(SpottrTheme.accent)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)

        case .pendingSent:
            Button {
                withAnimation(.spring(response: 0.3)) {
                    viewModel.cancelFriendRequest(to: user)
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 11))
                    Text("Requested")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                }
                .foregroundStyle(SpottrTheme.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(SpottrTheme.cardSubtle)
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(SpottrTheme.border, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

        case .accepted:
            HStack(spacing: 4) {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .black))
                Text("Friends")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
            }
            .foregroundStyle(SpottrTheme.accent)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(SpottrTheme.accentMuted)
            .clipShape(Capsule())

        case .pendingReceived:
            Button {
                withAnimation(.spring(response: 0.3)) {
                    viewModel.acceptFriendRequest(from: user)
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "person.badge.shield.checkmark.fill")
                        .font(.system(size: 12))
                    Text("Accept")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                }
                .foregroundStyle(.black)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(SpottrTheme.accent)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Pending Requests Section

    private var pendingRequestsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("PENDING REQUESTS (\(viewModel.pendingReceivedRequests.count))")
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .foregroundStyle(SpottrTheme.textMuted)
                .tracking(1.2)
                .padding(.horizontal, 4)

            ForEach(viewModel.pendingReceivedRequests) { requester in
                pendingRequestCard(user: requester)
            }
        }
    }

    private func pendingRequestCard(user: UserProfile) -> some View {
        HStack(spacing: 12) {
            // Avatar
            Circle()
                .fill(SpottrTheme.cardSubtle)
                .frame(width: 44, height: 44)
                .overlay(
                    Text(user.initials)
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundStyle(SpottrTheme.accent)
                )

            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(user.displayName)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(SpottrTheme.textPrimary)

                Text(user.formattedHandle)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(SpottrTheme.textMuted)
            }

            Spacer()

            // Actions: Decline & Accept
            HStack(spacing: 8) {
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        viewModel.declineFriendRequest(from: user)
                    }
                } label: {
                    Text("Decline")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(SpottrTheme.textMuted)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(SpottrTheme.cardSubtle)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Button {
                    withAnimation(.spring(response: 0.3)) {
                        viewModel.acceptFriendRequest(from: user)
                    }
                } label: {
                    Text("Accept")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(SpottrTheme.accent)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .spottrCard(padding: 14)
    }

    // MARK: - My Buddies Section

    private var myBuddiesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("MY BUDDIES (\(viewModel.activeFriends.count))")
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .foregroundStyle(SpottrTheme.textMuted)
                .tracking(1.2)
                .padding(.horizontal, 4)

            ForEach(viewModel.activeFriends) { buddy in
                buddyCard(buddy: buddy)
            }
        }
    }

    private func buddyCard(buddy: UserProfile) -> some View {
        let isBumped = viewModel.isFistBumped(userId: buddy.id)

        return HStack(spacing: 12) {
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
                HStack(spacing: 6) {
                    Text(buddy.displayName)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(SpottrTheme.textPrimary)

                    Text(buddy.formattedHandle)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(SpottrTheme.textMuted)
                }

                HStack(spacing: 6) {
                    Text(buddy.splitTitle)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(buddy.isRestDay ? SpottrTheme.restColor : SpottrTheme.textSecondary)

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
                    viewModel.toggleFistBump(for: buddy.id)
                }
            } label: {
                Text("👊")
                    .font(.system(size: 18))
                    .padding(10)
                    .background(isBumped ? SpottrTheme.accentMuted : SpottrTheme.cardSubtle)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(isBumped ? SpottrTheme.accent.opacity(0.5) : Color.clear, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        }
        .spottrCard(padding: 14)
        .contextMenu {
            Button(role: .destructive) {
                withAnimation {
                    viewModel.removeBuddy(user: buddy)
                }
            } label: {
                Label("Remove Buddy", systemImage: "person.fill.xmark")
            }
        }
    }

    // MARK: - Empty State Card

    private var emptyStateCard: some View {
        VStack(spacing: 14) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 40))
                .foregroundStyle(SpottrTheme.textMuted)
                .padding(.top, 10)

            Text("No Buddies Yet")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(SpottrTheme.textPrimary)

            Text("Search by @username above to find gym partners, or invite your workout crew to Spottr.")
                .font(.system(size: 13))
                .foregroundStyle(SpottrTheme.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.horizontal, 16)

            ShareLink(
                item: "Join me on Spottr to track workout splits and trade fist bumps! https://spottr.app",
                subject: Text("Workout with me on Spottr"),
                message: Text("Track your weekly split on Spottr and let's hold each other accountable!")
            ) {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up.fill")
                        .font(.system(size: 14, weight: .bold))
                    Text("Invite Friends")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                }
                .foregroundStyle(.black)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(SpottrTheme.accent)
                .clipShape(Capsule())
            }
            .padding(.top, 4)
            .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity)
        .spottrCard(padding: 24)
    }
}

#Preview {
    BuddiesView()
        .environmentObject(SpottrStore())
}
