// Add this test function to your iOS app temporarily to debug schema issues

func testDatabaseSchema() async {
    do {
        // Test 1: Check if we can query deal_offers table
        print("🔍 Testing deal_offers table...")
        let dealOffersTest = try await supabase
            .from("deal_offers")
            .select("id")
            .limit(1)
            .execute()
        print("✅ deal_offers table accessible")
        
        // Test 2: Check if we can query deals with new columns
        print("🔍 Testing deals table columns...")
        let dealsTest = try await supabase
            .from("deals")
            .select("id, conversation_id, deal_offer_id")
            .limit(1)
            .execute()
        print("✅ deals table with new columns accessible")
        
        // Test 3: Check if we can query notifications with deal_offer_id
        print("🔍 Testing notifications table columns...")
        let notificationsTest = try await supabase
            .from("notifications")
            .select("id, deal_offer_id")
            .limit(1)
            .execute()
        print("✅ notifications table with deal_offer_id accessible")
        
        print("✅ All schema tests passed!")
        
    } catch {
        print("❌ Schema test error: \(error)")
        print("Error details: \(error.localizedDescription)")
    }
}

// Call this function when your app starts or from a test button
// Task { await testDatabaseSchema() } 