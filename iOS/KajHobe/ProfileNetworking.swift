import Foundation
import Supabase
import Auth

// MARK: - Profile Networking
@preconcurrency
class ProfileNetworking: BaseNetworking {
    static let shared = ProfileNetworking()
    private override init() { super.init() }
    
    // MARK: - Profile Management
    func ensureUserProfile() async throws -> Profile {
        do {
            let user = try supabase.auth.requireCurrentUser()
            
            // Try to fetch existing profile
            let response = try await supabase
                .from("profiles")
                .select()
                .eq("id", value: user.id.uuidString)
                .execute()
            
            let decoder = JSONDecoder()
            if let profiles = try? decoder.decode([Profile].self, from: response.data),
               let existingProfile = profiles.first {
                print("Found existing profile: \(existingProfile.full_name ?? "No name")")
                return existingProfile
            }
            
            // Create new profile
            print("Creating new profile for user: \(user.id.uuidString)")
            
            // Helper function to safely extract string from metadata
            func extractString(from metadata: [String: Any], key: String) -> String? {
                return metadata[key] as? String
            }
            
            var profileData: [String: String] = [
                "id": user.id.uuidString,
                "full_name": extractString(from: user.userMetadata, key: "full_name") ?? "Unknown",
                "email": user.email ?? "",
                "role": "user",
                "is_verified": "false",
                "average_rating": "0.0",
                "ratings_count": "0",
                "is_service_provider": "false"
            ]
            
            if let avatarUrl = extractString(from: user.userMetadata, key: "avatar_url") {
                profileData["avatar_url"] = avatarUrl
            }
            
            let createResponse = try await supabase
                .from("profiles")
                .insert(profileData)
                .select()
                .execute()
            
            guard let newProfile = try decoder.decode([Profile].self, from: createResponse.data).first else {
                throw NSError(domain: "ProfileError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create profile"])
            }
            
            print("New profile created: \(newProfile.full_name ?? "No name")")
            return newProfile
        } catch {
            print("Profile error: \(error)")
            throw error
        }
    }

    func getCurrentUserProfile() async throws -> Profile {
        let user = try supabase.auth.requireCurrentUser()
        
        let response = try await supabase
            .from("profiles")
            .select("*")
            .eq("id", value: user.id.uuidString)
            .execute()
        
        let decoder = JSONDecoder()
        guard let profile = try decoder.decode([Profile].self, from: response.data).first else {
            throw NSError(domain: "ProfileError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Profile not found"])
        }
        
        return profile
    }

    func fetchProfile(userId: String) async throws -> Profile {
        do {
            print("Fetching profile for user: \(userId)")
            
            let response = try await supabase
                .from("profiles")
                .select("*")
                .eq("id", value: userId)
                .single()
                .execute()
            
            let profile = try await MainActor.run {
                try JSONDecoder().decode(Profile.self, from: response.data)
            }
            
            print("✅ Successfully fetched profile")
            return profile
            
        } catch {
            print("❌ Error fetching profile: \(error)")
            throw error
        }
    }
    
    func updateProfile(_ profile: Profile) async throws -> Profile {
        do {
            let user = try supabase.auth.requireCurrentUser()
            
            // Ensure user can only update their own profile
            guard profile.id == user.id.uuidString else {
                throw NetworkingError.unauthorized("You can only update your own profile")
            }
            
            var updateFields: [String: AnyJSON] = [
                "full_name": AnyJSON.string(profile.full_name ?? ""),
                "bio": AnyJSON.string(profile.bio ?? ""),
                "website": AnyJSON.string(profile.website ?? ""),
                "is_service_provider": AnyJSON.bool(profile.is_service_provider ?? false)
            ]
            
            if let phone = profile.phone {
                updateFields["phone"] = AnyJSON.string(phone)
            }
            if let location = profile.location {
                updateFields["location"] = AnyJSON.string(location)
            }
            if let avatarUrl = profile.avatar_url {
                updateFields["avatar_url"] = AnyJSON.string(avatarUrl)
            }
            if let favoriteCategories = profile.favorite_categories {
                updateFields["favorite_categories"] = AnyJSON.array(favoriteCategories.map { AnyJSON.string($0) })
            }
            
            let response = try await supabase
                .from("profiles")
                .update(updateFields)
                .eq("id", value: user.id.uuidString)
                .select()
                .single()
                .execute()
            
            let updatedProfile = try JSONDecoder().decode(Profile.self, from: response.data)
            print("✅ Profile updated successfully")
            return updatedProfile
            
        } catch {
            print("❌ Error updating profile: \(error)")
            throw error
        }
    }
    
    // MARK: - Favorite Categories Management
    func updateFavoriteCategories(_ categories: [String]) async throws -> Profile {
        do {
            let user = try supabase.auth.requireCurrentUser()
            
            // Limit to maximum 4 categories
            let limitedCategories = Array(categories.prefix(4))
            print("🔧 ProfileNetworking - Updating categories to: \(limitedCategories)")

            let response = try await supabase
                .from("profiles")
                .update([
                    "favorite_categories": AnyJSON.array(limitedCategories.map { AnyJSON.string($0) })
                ] as [String: AnyJSON])
                .eq("id", value: user.id.uuidString)
                .select()
                .single()
                .execute()
            
            let updatedProfile = try JSONDecoder().decode(Profile.self, from: response.data)
            print("✅ Favorite categories updated successfully - New categories: \(updatedProfile.favorite_categories ?? [])")
            return updatedProfile
            
        } catch {
            print("❌ Error updating favorite categories: \(error)")
            throw error
        }
    }
    
    func updateUserPresence(isOnline: Bool) async throws {
        // Use the cached session user id (sync, no network) — presence fires often (foreground,
        // background, every 5 min), so avoid an extra networked auth.user() round-trip each time.
        guard let userId = supabase.auth.currentUser?.id.uuidString else { return }
        let now = ISO8601DateFormatter().string(from: Date())

        var updateData: [String: AnyJSON] = [
            "is_online": AnyJSON.bool(isOnline)
        ]

        if !isOnline {
            updateData["last_seen_at"] = AnyJSON.string(now)
        }

        try await supabase
            .from("profiles")
            .update(updateData)
            .eq("id", value: userId)
            .execute()
        
        print("✅ Updated user presence: \(isOnline ? "online" : "offline")")
    }
    
    // MARK: - Batch Profile Loading
    func batchLoadProfiles(profileIds: [String]) async throws -> [String: SimpleProfile] {
        guard !profileIds.isEmpty else { return [:] }
        
        let response = try await supabase
            .from("profiles")
            .select("id, full_name, avatar_url, is_online, last_seen_at, average_response_time_minutes")
            .in("id", values: profileIds)
            .execute()
        
        let profiles = try JSONDecoder().decode([SimpleProfile].self, from: response.data)
        
        var profileDict: [String: SimpleProfile] = [:]
        for profile in profiles {
            profileDict[profile.id] = profile
        }
        
        return profileDict
    }
    
    // MARK: - Response Time Calculation (Removed with messaging functionality)
    func calculateAverageResponseTime(userId: String) async throws -> Int? {
        // Response time calculation removed until messaging is reimplemented
        return nil
        /*
        // Get recent conversations where user has sent messages
        let response = try await supabase
            .from("messages")
            .select("id, sender_id, created_at, conversation_id")
            .eq("sender_id", value: userId)
            .order("created_at", ascending: false)
            .limit(50)
            .execute()
        
        let messages = try JSONDecoder().decode([ChatMessage].self, from: response.data)
        
        // Group messages by conversation
        let messagesByConversation = Dictionary(grouping: messages) { $0.conversation_id }
        
        var responseTimes: [TimeInterval] = []
        
        for (conversationId, _) in messagesByConversation {
            // Get all messages in these conversations for response time calculation
            let allMessagesResponse = try await supabase
                .from("messages")
                .select("id, sender_id, created_at")
                .eq("conversation_id", value: conversationId)
                .order("created_at", ascending: true)
                .execute()
            
            let allMessages = try JSONDecoder().decode([ChatMessage].self, from: allMessagesResponse.data)
            
            // Calculate response times
            for i in 1..<allMessages.count {
                let currentMessage = allMessages[i]
                let previousMessage = allMessages[i-1]
                
                // Check if this is a response (different sender)
                if currentMessage.sender_id == userId && 
                   previousMessage.sender_id != userId {
                    
                    let formatter = ISO8601DateFormatter()
                    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                    
                    if let currentTime = formatter.date(from: currentMessage.created_at),
                       let previousTime = formatter.date(from: previousMessage.created_at) {
                        
                        let responseTime = currentTime.timeIntervalSince(previousTime)
                        if responseTime > 0 && responseTime < 86400 { // Within 24 hours
                            responseTimes.append(responseTime)
                        }
                    }
                }
            }
        }
        
        guard !responseTimes.isEmpty else { return nil }
        
        let averageSeconds = responseTimes.reduce(0, +) / Double(responseTimes.count)
        let averageMinutes = Int(averageSeconds / 60)
        
        // Update user's average response time
        try await supabase
            .from("profiles")
            .update(["average_response_time_minutes": averageMinutes])
            .eq("id", value: userId)
            .execute()
        
        print("✅ Calculated average response time: \(averageMinutes) minutes for user: \(userId)")
        return averageMinutes
        */
    }
}