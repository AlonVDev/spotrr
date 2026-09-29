//
//  FriendDatabaseService.swift
//  spotrr
//
//  Created by Spottr on 22/09/2026.
//

import Foundation

// MARK: - Friend Database Service Protocol

protocol FriendDatabaseServiceProtocol: Sendable {
    func currentUserId() -> UUID
    func fetchFriends() async throws -> [UserProfile]
    func fetchPendingReceivedRequests() async throws -> [UserProfile]
    func fetchPendingSentRequests() async throws -> [UserProfile]
    func searchUsers(query: String) async throws -> [(user: UserProfile, status: FriendshipStatus)]
    func sendFriendRequest(to userId: UUID) async throws
    func acceptFriendRequest(from userId: UUID) async throws
    func declineFriendRequest(from userId: UUID) async throws
    func cancelFriendRequest(to userId: UUID) async throws
    func removeFriend(userId: UUID) async throws
    func blockUser(userId: UUID) async throws
}

// MARK: - Local Persistent Database Service

final class LocalFriendDatabaseService: FriendDatabaseServiceProtocol, @unchecked Sendable {

    static let shared = LocalFriendDatabaseService()

    private let userDefaults = UserDefaults.standard
    private let friendshipsKey = "Spottr_Friendships_v1"
    private let directoryKey = "Spottr_UserDirectory_v1"
    private let currentUserIdKey = "Spottr_CurrentUserId_v1"

    private let lock = NSLock()

    // Current local user ID
    private let localUserId: UUID

    // In-memory caches persisted to storage
    private var allUsers: [UUID: UserProfile] = [:]
    private var friendships: [UUID: FriendshipStatus] = [:] // Target user ID -> Status relative to local user

    init() {
        // Load or create persistent local user ID
        if let savedIdString = UserDefaults.standard.string(forKey: currentUserIdKey),
           let savedId = UUID(uuidString: savedIdString) {
            self.localUserId = savedId
        } else {
            let newId = UUID()
            UserDefaults.standard.set(newId.uuidString, forKey: currentUserIdKey)
            self.localUserId = newId
        }

        loadData()
    }

    func currentUserId() -> UUID {
        localUserId
    }

    // MARK: - Queries

    func fetchFriends() async throws -> [UserProfile] {
        lock.lock()
        defer { lock.unlock() }

        return allUsers.values
            .filter { friendships[$0.id] == .accepted }
            .sorted { $0.displayName < $1.displayName }
    }

    func fetchPendingReceivedRequests() async throws -> [UserProfile] {
        lock.lock()
        defer { lock.unlock() }

        return allUsers.values
            .filter { friendships[$0.id] == .pendingReceived }
            .sorted { $0.displayName < $1.displayName }
    }

    func fetchPendingSentRequests() async throws -> [UserProfile] {
        lock.lock()
        defer { lock.unlock() }

        return allUsers.values
            .filter { friendships[$0.id] == .pendingSent }
            .sorted { $0.displayName < $1.displayName }
    }

    func searchUsers(query: String) async throws -> [(user: UserProfile, status: FriendshipStatus)] {
        lock.lock()
        defer { lock.unlock() }

        let cleanQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let strippedQuery = cleanQuery.hasPrefix("@") ? String(cleanQuery.dropFirst()) : cleanQuery

        guard !strippedQuery.isEmpty else {
            return []
        }

        return allUsers.values
            .filter { user in
                user.id != localUserId && (
                    user.username.lowercased().contains(strippedQuery) ||
                    user.displayName.lowercased().contains(cleanQuery)
                )
            }
            .map { user in
                (user: user, status: friendships[user.id] ?? .none)
            }
            .sorted { (item1, item2) in
                // Exact matches first, then alphabetical
                let exact1 = item1.user.username.lowercased() == strippedQuery
                let exact2 = item2.user.username.lowercased() == strippedQuery
                if exact1 != exact2 {
                    return exact1
                }
                return item1.user.displayName < item2.user.displayName
            }
    }

    // MARK: - Mutations

    func sendFriendRequest(to userId: UUID) async throws {
        lock.lock()
        defer { lock.unlock() }

        friendships[userId] = .pendingSent
        saveFriendships()
    }

    func acceptFriendRequest(from userId: UUID) async throws {
        lock.lock()
        defer { lock.unlock() }

        friendships[userId] = .accepted
        saveFriendships()
    }

    func declineFriendRequest(from userId: UUID) async throws {
        lock.lock()
        defer { lock.unlock() }

        friendships[userId] = .none
        saveFriendships()
    }

    func cancelFriendRequest(to userId: UUID) async throws {
        lock.lock()
        defer { lock.unlock() }

        friendships[userId] = .none
        saveFriendships()
    }

    func removeFriend(userId: UUID) async throws {
        lock.lock()
        defer { lock.unlock() }

        friendships[userId] = .none
        saveFriendships()
    }

    func blockUser(userId: UUID) async throws {
        lock.lock()
        defer { lock.unlock() }

        friendships[userId] = .blocked
        saveFriendships()
    }

    // MARK: - Persistence

    private func loadData() {
        lock.lock()
        defer { lock.unlock() }

        // 1. Load User Directory
        if let directoryData = userDefaults.data(forKey: directoryKey),
           let decodedDirectory = try? JSONDecoder().decode([UserProfile].self, from: directoryData),
           !decodedDirectory.isEmpty {
            self.allUsers = Dictionary(uniqueKeysWithValues: decodedDirectory.map { ($0.id, $0) })
        } else {
            setupDefaultDirectory()
        }

        // 2. Load Friendships
        if let friendshipData = userDefaults.data(forKey: friendshipsKey),
           let decodedFriendships = try? JSONDecoder().decode([String: String].self, from: friendshipData) {
            var map: [UUID: FriendshipStatus] = [:]
            for (idStr, statusStr) in decodedFriendships {
                if let uuid = UUID(uuidString: idStr), let status = FriendshipStatus(rawValue: statusStr) {
                    map[uuid] = status
                }
            }
            self.friendships = map
        } else {
            setupDefaultFriendships()
        }
    }

    private func saveFriendships() {
        let serializableMap = Dictionary(uniqueKeysWithValues: friendships.map { ($0.key.uuidString, $0.value.rawValue) })
        if let encoded = try? JSONEncoder().encode(serializableMap) {
            userDefaults.set(encoded, forKey: friendshipsKey)
        }
    }

    private func saveDirectory() {
        let array = Array(allUsers.values)
        if let encoded = try? JSONEncoder().encode(array) {
            userDefaults.set(encoded, forKey: directoryKey)
        }
    }

    // MARK: - Initial Seeding

    private func setupDefaultDirectory() {
        let sampleUsers: [UserProfile] = [
            UserProfile(
                id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
                username: "marcus_c",
                displayName: "Marcus Chen",
                splitTitle: "Push Day (Chest & Shoulders)",
                isRestDay: false,
                completedCount: 4,
                totalCount: 5
            ),
            UserProfile(
                id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
                username: "sarah_j",
                displayName: "Sarah Jenkins",
                splitTitle: "Legs (Glutes & Hamstrings)",
                isRestDay: false,
                completedCount: 2,
                totalCount: 4
            ),
            UserProfile(
                id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
                username: "liam_v",
                displayName: "Liam Vance",
                splitTitle: "Rest Day",
                isRestDay: true,
                completedCount: 0,
                totalCount: 0
            ),
            UserProfile(
                id: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!,
                username: "elena_r",
                displayName: "Elena Rostova",
                splitTitle: "Back & Biceps Power",
                isRestDay: false,
                completedCount: 5,
                totalCount: 5
            ),
            UserProfile(
                id: UUID(uuidString: "55555555-5555-5555-5555-555555555555")!,
                username: "alex_lifts",
                displayName: "Alex Rivera",
                splitTitle: "Upper Body Hypertrophy",
                isRestDay: false,
                completedCount: 3,
                totalCount: 5
            ),
            UserProfile(
                id: UUID(uuidString: "66666666-6666-6666-6666-666666666666")!,
                username: "jordan_k",
                displayName: "Jordan Kim",
                splitTitle: "Core & Functional",
                isRestDay: false,
                completedCount: 1,
                totalCount: 3
            ),
            UserProfile(
                id: UUID(uuidString: "77777777-7777-7777-7777-777777777777")!,
                username: "chrisfit",
                displayName: "Chris Miller",
                splitTitle: "Chest & Triceps",
                isRestDay: false,
                completedCount: 1,
                totalCount: 4
            ),
            UserProfile(
                id: UUID(uuidString: "88888888-8888-8888-8888-888888888888")!,
                username: "taylor_gains",
                displayName: "Taylor Ward",
                splitTitle: "Glutes & Hamstrings",
                isRestDay: false,
                completedCount: 4,
                totalCount: 6
            )
        ]

        self.allUsers = Dictionary(uniqueKeysWithValues: sampleUsers.map { ($0.id, $0) })
        saveDirectory()
    }

    private func setupDefaultFriendships() {
        // Initial setup:
        // Marcus, Sarah, Liam, Elena -> Accepted friends
        // Alex Rivera -> Pending incoming request (to test Accept & Decline)
        // Jordan Kim -> Pending sent request (to test "Requested" state)
        // Chris Miller & Taylor Ward -> none (to test "Add Friend")
        self.friendships = [
            UUID(uuidString: "11111111-1111-1111-1111-111111111111")!: .accepted,
            UUID(uuidString: "22222222-2222-2222-2222-222222222222")!: .accepted,
            UUID(uuidString: "33333333-3333-3333-3333-333333333333")!: .accepted,
            UUID(uuidString: "44444444-4444-4444-4444-444444444444")!: .accepted,
            UUID(uuidString: "55555555-5555-5555-5555-555555555555")!: .pendingReceived,
            UUID(uuidString: "66666666-6666-6666-6666-666666666666")!: .pendingSent
        ]
        saveFriendships()
    }
}

