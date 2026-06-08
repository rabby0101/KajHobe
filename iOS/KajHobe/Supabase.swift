import Foundation
import Supabase
import Auth

/// Thrown by `requireCurrentUser()` when there is no active session.
struct NoActiveSessionError: LocalizedError {
    var errorDescription: String? { "No active session." }
}

extension AuthClient {
    /// Returns the current user from the locally-stored session **without a network round-trip**
    /// (unlike `user()`, which performs a `GET /user`). Throws when there is no session, matching
    /// the throwing shape of `user()` so call sites only drop `await` and rename. Use this for the
    /// common "I just need the signed-in user's id" case; keep `user()` only when genuinely fresh
    /// server-side user fields are required.
    nonisolated func requireCurrentUser() throws -> User {
        guard let user = currentSession?.user else { throw NoActiveSessionError() }
        return user
    }
}

nonisolated let supabase = SupabaseClient(
    supabaseURL: URL(string: "https://xatlqnbrvgukuqewsxux.supabase.co")!,
    supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhhdGxxbmJydmd1a3VxZXdzeHV4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDk3MzgxMjgsImV4cCI6MjA2NTMxNDEyOH0.rBsGaNV-AcfqypS32p1BlL2B3cwGmWqC3bGabWuw1bo"
)

// Add this function to force schema refresh
func refreshSupabaseSchema() {
    // Clear any cached schema information
    Task {
        await supabase.realtimeV2.removeAllChannels()
        
        // Force a new connection
        do {
            // Make a simple query to force schema reload
            _ = try await supabase
                .from("deals")
                .select("id")
                .limit(1)
                .execute()
            
            // print("✅ Schema refresh completed")
        } catch {
            // print("❌ Schema refresh error: \(error)")
        }
    }
}
