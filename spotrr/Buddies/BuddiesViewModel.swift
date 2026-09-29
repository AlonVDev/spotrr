//
//  BuddiesViewModel.swift
//  spotrr
//
//  Created by Spottr on 22/09/2026.
//

import SwiftUI
import Observation

@Observable
@MainActor
final class BuddiesViewModel {

    // MARK: - State Properties

    var searchText: String = "" {
        didSet {
            performSearch(query: searchText)
        }
    }

    var searchResults: [(user: UserProfile, status: FriendshipStatus)] = []
    var pendingReceivedRequests: [UserProfile] = []
    var activeFriends: [UserProfile] = []
    var fistBumpedUserIds: Set<UUID> = []
    var isLoading: Bool = false
    var errorMessage: String? = nil

    private let service: FriendDatabaseServiceProtocol
    private let fistBumpsStorageKey = "Spottr_FistBumps_v1"

    init(service: FriendDatabaseServiceProtocol = LocalFriendDatabaseService.shared) {
        self.service = service
        loadFistBumps()
    }

    var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var hasNoBuddiesOrRequests: Bool {
        activeFriends.isEmpty && pendingReceivedRequests.isEmpty
    }

    // MARK: - Data Loading

    func loadData() {
        Task {
            isLoading = true
            defer { isLoading = false }

            do {
                async let friendsTask = service.fetchFriends()
                async let pendingTask = service.fetchPendingReceivedRequests()

                self.activeFriends = try await friendsTask
                self.pendingReceivedRequests = try await pendingTask

                // If currently searching, refresh search results as well
                if isSearching {
                    performSearch(query: searchText)
                }
            } catch {
                self.errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Search

    func performSearch(query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            searchResults = []
            return
        }

        Task {
            do {
                self.searchResults = try await service.searchUsers(query: trimmed)
            } catch {
                self.errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Friend Actions

    func sendFriendRequest(to user: UserProfile) {
        triggerHaptic(.medium)
        Task {
            do {
                try await service.sendFriendRequest(to: user.id)
                loadData()
            } catch {
                self.errorMessage = error.localizedDescription
            }
        }
    }

    func acceptFriendRequest(from user: UserProfile) {
        triggerHaptic(.medium)
        Task {
            do {
                try await service.acceptFriendRequest(from: user.id)
                loadData()
            } catch {
                self.errorMessage = error.localizedDescription
            }
        }
    }

    func declineFriendRequest(from user: UserProfile) {
        triggerHaptic(.light)
        Task {
            do {
                try await service.declineFriendRequest(from: user.id)
                loadData()
            } catch {
                self.errorMessage = error.localizedDescription
            }
        }
    }

    func cancelFriendRequest(to user: UserProfile) {
        triggerHaptic(.light)
        Task {
            do {
                try await service.cancelFriendRequest(to: user.id)
                loadData()
            } catch {
                self.errorMessage = error.localizedDescription
            }
        }
    }

    func removeBuddy(user: UserProfile) {
        triggerHaptic(.light)
        Task {
            do {
                try await service.removeFriend(userId: user.id)
                loadData()
            } catch {
                self.errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Fist Bump

    func isFistBumped(userId: UUID) -> Bool {
        fistBumpedUserIds.contains(userId)
    }

    func toggleFistBump(for userId: UUID) {
        triggerHaptic(.medium)
        if fistBumpedUserIds.contains(userId) {
            fistBumpedUserIds.remove(userId)
        } else {
            fistBumpedUserIds.insert(userId)
        }
        saveFistBumps()
    }

    private func triggerHaptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }

    private func loadFistBumps() {
        if let data = UserDefaults.standard.data(forKey: fistBumpsStorageKey),
           let array = try? JSONDecoder().decode([String].self, from: data) {
            self.fistBumpedUserIds = Set(array.compactMap { UUID(uuidString: $0) })
        }
    }

    private func saveFistBumps() {
        let stringArray = fistBumpedUserIds.map { $0.uuidString }
        if let encoded = try? JSONEncoder().encode(stringArray) {
            UserDefaults.standard.set(encoded, forKey: fistBumpsStorageKey)
        }
    }
}

