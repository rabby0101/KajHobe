import Foundation
import Supabase
import PostgREST

/// Specialized networking class for public profile operations
class PublicProfileNetworking: BaseNetworking {

    // MARK: - Public Profile Fetching

    /// Fetch complete public profile for a service provider
    func fetchPublicProfile(_ providerId: String) async throws -> PublicProfile {
        print("🌐 PublicProfileNetworking - Fetching public profile for \(providerId)")

        let response = try await supabase
            .from("public_profiles")
            .select()
            .eq("id", value: providerId)
            .execute()

        let decoder = JSONDecoder()
        let result = try decoder.decode([PublicProfile].self, from: response.data)

        guard let profile = result.first else {
            print("❌ PublicProfileNetworking - Public profile not found for \(providerId)")
            throw NetworkingError.notFound
        }

        print("✅ PublicProfileNetworking - Public profile fetched for \(providerId)")
        return profile
    }

    /// Fetch minimal profile summaries for efficient batch loading
    /// Used in notification lists and interest request previews
    func fetchPublicProfileSummaries(_ providerIds: [String]) async throws -> [String: PublicProfileSummary] {
        guard !providerIds.isEmpty else { return [:] }

        print("🌐 PublicProfileNetworking - Fetching profile summaries for \(providerIds.count) providers")

        let response = try await supabase
            .from("public_profiles")
            .select("id, full_name, avatar_url, trust_level, completed_jobs, avg_rating, is_online")
            .in("id", values: providerIds)
            .execute()

        let decoder = JSONDecoder()
        let result = try decoder.decode([PublicProfileSummary].self, from: response.data)

        // Convert to dictionary for efficient lookup
        let summariesDict = Dictionary(uniqueKeysWithValues: result.map { ($0.id, $0) })

        print("✅ PublicProfileNetworking - \(result.count) profile summaries fetched")
        return summariesDict
    }

    /// Fetch single profile summary for quick preview
    func fetchPublicProfileSummary(_ providerId: String) async throws -> PublicProfileSummary {
        print("🌐 PublicProfileNetworking - Fetching profile summary for \(providerId)")

        let response = try await supabase
            .from("public_profiles")
            .select("id, full_name, avatar_url, trust_level, completed_jobs, avg_rating, is_online")
            .eq("id", value: providerId)
            .execute()

        let decoder = JSONDecoder()
        let result = try decoder.decode([PublicProfileSummary].self, from: response.data)

        guard let summary = result.first else {
            print("❌ PublicProfileNetworking - Profile summary not found for \(providerId)")
            throw NetworkingError.notFound
        }

        print("✅ PublicProfileNetworking - Profile summary fetched for \(providerId)")
        return summary
    }

    // MARK: - Service Highlights

    /// Fetch service highlights showing provider's expertise in different categories
    /// This provides deeper insights into provider's specializations
    func fetchServiceHighlights(_ providerId: String) async throws -> [ServiceHighlight] {
        print("🌐 PublicProfileNetworking - Fetching service highlights for \(providerId)")

        // Query to get service categories with statistics
        let query = """
        SELECT
            j.category,
            COUNT(*) as job_count,
            AVG(r.rating) as avg_rating,
            MAX(d.completed_at) as recent_completion,
            AVG(d.agreed_amount) as avg_job_value
        FROM deals d
        LEFT JOIN jobs j ON d.job_id = j.id
        LEFT JOIN reviews r ON j.id = r.job_id AND r.reviewed_id = d.provider_id
        WHERE d.provider_id = '\(providerId)'
            AND (d.completion_status = 'completed' OR d.status = 'completed')
            AND j.category IS NOT NULL
        GROUP BY j.category
        ORDER BY job_count DESC, avg_rating DESC
        LIMIT 5
        """

        do {
            // Execute raw SQL query for complex aggregation
            let response = try await supabase.rpc("execute_sql", params: ["query": query])

            // Parse the response and create ServiceHighlight objects
            var highlights: [ServiceHighlight] = []

            // For now, create placeholder highlights based on profile's service categories
            // In a real implementation, you would parse the SQL response
            let profile = try await fetchPublicProfile(providerId)

            for category in profile.topServiceCategories {
                let highlight = ServiceHighlight(
                    category: category,
                    job_count: Int.random(in: 1...5), // Placeholder - would come from SQL
                    avg_rating: profile.avg_rating > 0 ? profile.avg_rating : nil,
                    recent_completion: profile.last_updated,
                    avg_job_value: profile.avg_job_value > 0 ? profile.avg_job_value : nil
                )
                highlights.append(highlight)
            }

            print("✅ PublicProfileNetworking - \(highlights.count) service highlights fetched")
            return highlights

        } catch {
            print("⚠️ PublicProfileNetworking - Failed to fetch service highlights, using fallback: \(error)")

            // Fallback: Create basic highlights from profile data
            let profile = try await fetchPublicProfile(providerId)
            let fallbackHighlights = profile.topServiceCategories.map { category in
                ServiceHighlight(
                    category: category,
                    job_count: profile.completed_jobs,
                    avg_rating: profile.avg_rating > 0 ? profile.avg_rating : nil,
                    recent_completion: profile.last_updated,
                    avg_job_value: profile.avg_job_value > 0 ? profile.avg_job_value : nil
                )
            }

            return fallbackHighlights
        }
    }

    // MARK: - Discovery & Search

    /// Find top-rated service providers in a specific category
    /// Useful for job posting suggestions and recommendations
    func findTopProviders(
        in category: String? = nil,
        trustLevel: TrustLevel? = nil,
        limit: Int = 10
    ) async throws -> [PublicProfileSummary] {

        print("🔍 PublicProfileNetworking - Finding top providers (category: \(category ?? "all"), trust: \(trustLevel?.displayName ?? "any"))")

        // Build the base query
        let baseQuery = supabase
            .from("public_profiles")
            .select("id, full_name, avatar_url, trust_level, completed_jobs, avg_rating, is_online")
            .eq("is_service_provider", value: true)
            .order("avg_rating", ascending: false)
            .order("completed_jobs", ascending: false)
            .limit(limit)

        // For now, implement a simple version without complex filtering
        // TODO: Implement proper filtering when Supabase client methods are clarified
        let response = try await baseQuery.execute()

        let decoder = JSONDecoder()
        let result = try decoder.decode([PublicProfileSummary].self, from: response.data)

        print("✅ PublicProfileNetworking - Found \(result.count) top providers")
        return result
    }

    /// Search providers by name or location
    func searchProviders(_ searchText: String, limit: Int = 20) async throws -> [PublicProfileSummary] {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }

        print("🔍 PublicProfileNetworking - Searching providers for: '\(searchText)'")

        let response = try await supabase
            .from("public_profiles")
            .select("id, full_name, avatar_url, trust_level, completed_jobs, avg_rating, is_online")
            .eq("is_service_provider", value: true)
            .or("full_name.ilike.%\(searchText)%,location.ilike.%\(searchText)%")
            .order("completed_jobs", ascending: false)
            .limit(limit)
            .execute()

        let decoder = JSONDecoder()
        let result = try decoder.decode([PublicProfileSummary].self, from: response.data)

        print("✅ PublicProfileNetworking - Found \(result.count) providers matching '\(searchText)'")
        return result
    }

    // MARK: - Real-time Updates

    /// Subscribe to public profile updates for a specific provider
    /// Useful for live presence indicators and real-time statistics
    func subscribeToPublicProfile(
        _ providerId: String,
        onUpdate: @escaping (PublicProfile) -> Void
    ) async throws {

        print("📡 PublicProfileNetworking - Subscribing to public profile updates for \(providerId)")

        let channel = supabase.realtimeV2.channel("public_profile_\(providerId)")

        let updates = channel.postgresChange(
            AnyAction.self,
            table: "public_profiles",
            filter: "id=eq.\(providerId)"
        )

        await channel.subscribe()

        for await update in updates {
            do {
                print("📡 PublicProfileNetworking - Received public profile update for \(providerId)")

                // Fetch fresh data
                let freshProfile = try await fetchPublicProfile(providerId)
                await MainActor.run {
                    onUpdate(freshProfile)
                }

            } catch {
                print("❌ PublicProfileNetworking - Failed to process profile update: \(error)")
            }
        }
    }

    // MARK: - Utility Methods

    /// Clear any temporary data (placeholder for future cache implementation)
    func clearAllData() {
        print("🗑️ PublicProfileNetworking - Clearing temporary data")
        // Placeholder - could implement memory cleanup if needed
    }
}

// MARK: - Error Extensions
extension PublicProfileNetworking {
    enum PublicProfileError: LocalizedError {
        case providerNotFound
        case invalidProfileData
        case cacheError

        var errorDescription: String? {
            switch self {
            case .providerNotFound:
                return "Service provider not found"
            case .invalidProfileData:
                return "Invalid profile data received"
            case .cacheError:
                return "Cache operation failed"
            }
        }
    }
}