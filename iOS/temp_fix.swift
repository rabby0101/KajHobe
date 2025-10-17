    func fetchUserConversations() async throws -> [ConversationWithJob] {
        do {
            let user = try await supabase.auth.user()
            print("🔄 Fetching conversations for user: \(user.id.uuidString)")
            
            // First, try a simple query without foreign key relationships
            print("🔄 Step 1: Testing simple conversations query...")
            let simpleResponse = try await supabase
                .from("conversations")
                .select("*")
                .or("client_id.eq.\(user.id.uuidString),provider_id.eq.\(user.id.uuidString)")
                .execute()
            
            print("✅ Simple query response: \(String(data: simpleResponse.data, encoding: .utf8) ?? "No data")")
            
            // Now try with job data but without profile relationships
            print("🔄 Step 2: Testing with job data...")
            let jobResponse = try await supabase
                .from("conversations")
                .select("*, jobs(*)")
                .or("client_id.eq.\(user.id.uuidString),provider_id.eq.\(user.id.uuidString)")
                .order("updated_at", ascending: false)
                .execute()
            
            print("✅ Job query response: \(String(data: jobResponse.data, encoding: .utf8) ?? "No data")")
            
            // Try to decode the simpler version first
            let decoder = JSONDecoder()
            var conversations = try decoder.decode([ConversationWithJob].self, from: jobResponse.data)
            print("✅ Successfully decoded \(conversations.count) conversations")
            
            // Now manually fetch profile data for each conversation
            print("🔄 Step 3: Fetching profile data...")
            for i in 0..<conversations.count {
                // Fetch client profile
                do {
                    let clientResponse = try await supabase
                        .from("profiles")
                        .select("full_name")
                        .eq("id", value: conversations[i].client_id)
                        .single()
                        .execute()
                    
                    let clientProfile = try decoder.decode(SimpleProfile.self, from: clientResponse.data)
                    conversations[i].client_profile = clientProfile
                } catch {
                    print("⚠️ Failed to fetch client profile for conversation \(conversations[i].id): \(error)")
                }
                
                // Fetch provider profile
                do {
                    let providerResponse = try await supabase
                        .from("profiles")
                        .select("full_name")
                        .eq("id", value: conversations[i].provider_id)
                        .single()
                        .execute()
                    
                    let providerProfile = try decoder.decode(SimpleProfile.self, from: providerResponse.data)
                    conversations[i].provider_profile = providerProfile
                } catch {
                    print("⚠️ Failed to fetch provider profile for conversation \(conversations[i].id): \(error)")
                }
            }
            
            print("✅ Final conversations with profiles: \(conversations.count)")
            return conversations
            
        } catch let decodingError as DecodingError {
            print("❌ Decoding error for conversations: \(decodingError)")
            switch decodingError {
            case .keyNotFound(let key, let context):
                print("Key '\(key)' not found: \(context.debugDescription)")
                print("Coding path: \(context.codingPath)")
            case .typeMismatch(let type, let context):
                print("Type '\(type)' mismatch: \(context.debugDescription)")
                print("Coding path: \(context.codingPath)")
            case .valueNotFound(let value, let context):
                print("Value '\(value)' not found: \(context.debugDescription)")
                print("Coding path: \(context.codingPath)")
            case .dataCorrupted(let context):
                print("Data corrupted: \(context.debugDescription)")
                print("Coding path: \(context.codingPath)")
            @unknown default:
                print("Unknown decoding error")
            }
            throw decodingError
        } catch {
            print("❌ Error fetching user conversations: \(error)")
            throw error
        }
    }
