import Foundation
import Supabase

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
