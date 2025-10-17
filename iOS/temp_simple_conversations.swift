// Temporary simplified method to test basic conversation loading
// Add this to Networking.swift temporarily for debugging

func fetchUserConversationsSimple() async throws -> [ConversationWithJob] {
    do {
        let user = try await supabase.auth.user()
        print("🧪 SIMPLE TEST: Fetching conversations for user: \(user.id)")
        
        // Just get basic conversations without any enrichment
        let response = try await supabase
            .from("conversations")
            .select("*")
            .or("client_id.eq.\(user.id.uuidString),provider_id.eq.\(user.id.uuidString)")
            .order("updated_at", ascending: false)
            .execute()
        
        print("🧪 SIMPLE TEST: Raw response: \(String(data: response.data, encoding: .utf8) ?? "nil")")
        
        let decoder = JSONDecoder()
        let conversations = try decoder.decode([ConversationWithJob].self, from: response.data)
        print("🧪 SIMPLE TEST: Decoded \(conversations.count) conversations")
        
        // Just return the basic conversations without enrichment
        return conversations
        
    } catch {
        print("🧪 SIMPLE TEST ERROR: \(error)")
        throw error
    }
}

// Also add this to MessagesView.swift in loadConversations() to test:
// Replace this line:
// let fetchedConversations = try await Networking.shared.fetchUserConversations()
// 
// With this:
// let fetchedConversations = try await Networking.shared.fetchUserConversationsSimple()

// This will help us determine if the issue is:
// 1. The basic conversation query (if this also returns empty)
// 2. The enrichment process (if this works but the full method doesn't)
// 3. RLS policies (if this fails with permissions error) 