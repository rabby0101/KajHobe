    private func checkIfJobViewed(jobId: String, userId: String) async -> Bool {
        do {
            // Check if there's a record in job_views table
            let response = try await supabase
                .from("job_views")
                .select("id")
                .eq("job_id", value: Int(jobId) ?? 0)
                .eq("user_id", value: userId)
                .execute()
            
            let data = String(data: response.data, encoding: .utf8) ?? "[]"
            return !data.contains("[]")
        } catch {
            print("Error checking job viewed status: \(error)")
            return false
        }
    }
    
    private func checkIfJobInterested(jobId: String, userId: String) async -> Bool {
        do {
            // Check if there's a record in job_interests table
            let response = try await supabase
                .from("job_interests")
                .select("id")
                .eq("job_id", value: Int(jobId) ?? 0)
                .eq("provider_id", value: userId)
                .execute()
            
            let data = String(data: response.data, encoding: .utf8) ?? "[]"
            return !data.contains("[]")
        } catch {
            print("Error checking job interest status: \(error)")
            return false
        }
    }
    
    private func markJobAsViewed() async {
        guard !isOwnJob, let userId = currentUserId else { return }
        
        do {
            // Call the track_job_view function with correct data types
            let _ = try await supabase.rpc(
                "track_job_view",
                params: [
                    "p_job_id": Int(job.id) ?? 0,
                    "p_user_id": userId
                ]
            ).execute()
            
            // Update local status
            await MainActor.run {
                if self.jobStatus == .new {
                    self.jobStatus = .viewed
                }
            }
        } catch {
            print("Error marking job as viewed: \(error)")
        }
    }
