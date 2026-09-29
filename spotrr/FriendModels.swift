//
//  FriendModels.swift
//  spotrr
//
//  Created by Spottr on 22/09/2026.
//

import Foundation

// MARK: - Friendship Status

enum FriendshipStatus: String, Codable, Hashable {
    case none
    case pendingSent      // User sent a request to this person ("Requested")
    case pendingReceived  // This person sent a request to user ("Accept" / "Decline")
    case accepted         // Active friends ("Friends")
    case blocked          // Blocked relationship
}

// MARK: - User Profile

struct UserProfile: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var username: String      // e.g. "marcus_c" (without @ in model, formatted in UI)
    var displayName: String   // e.g. "Marcus Chen"
    var avatarURL: String? = nil

    // Social & Split Activity Attributes
    var splitTitle: String = "Rest Day"
    var isRestDay: Bool = true
    var completedCount: Int = 0
    var totalCount: Int = 0

    var formattedHandle: String {
        username.hasPrefix("@") ? username : "@\(username)"
    }

    var initials: String {
        let parts = displayName.split(separator: " ")
        if parts.count >= 2, let first = parts.first?.first, let last = parts.last?.first {
            return "\(first)\(last)".uppercased()
        } else if let first = displayName.first {
            return String(first).uppercased()
        }
        return "SP"
    }
}

// MARK: - Friendship Record

struct Friendship: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var requesterId: UUID
    var receiverId: UUID
    var status: FriendshipStatus
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
}

