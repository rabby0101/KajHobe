import Foundation
import Supabase
import Auth

// MARK: - Jobs Networking
@preconcurrency
class JobsNetworking: BaseNetworking {
    static let shared = JobsNetworking()
    private override init() { super.init() }
    
    // MARK: - Jobs
    func fetchJobs(forceRefresh: Bool = false) async throws -> [Job] {
        // Cache has been removed - always fetch fresh data
        
        do {
            print("🌐 Fetching jobs from network...")

            // These two queries are independent — run them concurrently so the home load
            // pays one round-trip's worth of latency instead of two serialized ones.
            async let jobsResponse = supabase
                .from("jobs")
                .select()
                .eq("status", value: "open")
                .order("created_at", ascending: false)
                .execute()

            async let dealsResponse = supabase
                .from("deals")
                .select("job_id")
                .in("status", values: ["accepted", "in_progress", "active", "completed"])
                .execute()

            let (jobsResult, dealsResult) = try await (jobsResponse, dealsResponse)

            let decoder = JSONDecoder()
            let allJobs = try decoder.decode([Job].self, from: jobsResult.data)

            // Extract job IDs with deals into a Set for O(1) lookups (the deals query returns one
            // row per deal, so a job with multiple deals appears multiple times — the Set dedupes).
            let jobIdsWithDeals = Set(
                try decoder.decode([[String: String]].self, from: dealsResult.data)
                    .compactMap { $0["job_id"] }
            )

            // Filter out jobs that have any deals (active or completed)
            let availableJobs = allJobs.filter { job in
                !jobIdsWithDeals.contains(job.id)
            }
            
            print("✅ Jobs filtering results:")
            print("   Total jobs from DB: \(allJobs.count)")
            print("   Jobs with deals: \(jobIdsWithDeals.count)")
            print("   Available jobs: \(availableJobs.count)")
            if !jobIdsWithDeals.isEmpty {
                print("   Jobs with deals IDs: \(jobIdsWithDeals.joined(separator: ", "))")
            }
            
            // Cache has been removed
            
            return availableJobs
        } catch let decodingError as DecodingError {
            print("❌ Decoding error for jobs: \(decodingError)")
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
            print("Error fetching jobs: \(error)")
            throw error
        }
    }
    
    func fetchMyJobs() async throws -> [Job] {
        do {
            let user = try supabase.auth.requireCurrentUser()
            let response = try await supabase
                .from("jobs")
                .select()
                .eq("client_id", value: user.id.uuidString)
                .order("created_at", ascending: false)
                .execute()
            
            let decoder = JSONDecoder()
            let jobs = try decoder.decode([Job].self, from: response.data)
            return jobs
        } catch {
            throw error
        }
    }
    
    // MARK: - Delete Job
    func deleteJob(jobId: String) async throws {
        do {
            let user = try supabase.auth.requireCurrentUser()
            
            // First verify that the current user owns this job
            let jobResponse = try await supabase
                .from("jobs")
                .select("client_id")
                .eq("id", value: jobId)
                .single()
                .execute()
            
            let jobData = try JSONSerialization.jsonObject(with: jobResponse.data) as? [String: Any]
            let jobClientId = jobData?["client_id"] as? String ?? ""
            
            // Security check: Only the job owner can delete the job
            if jobClientId.lowercased() != user.id.uuidString.lowercased() {
                throw NSError(domain: "AuthorizationError", code: 403, userInfo: [
                    NSLocalizedDescriptionKey: "You can only delete your own job postings"
                ])
            }
            
            // Delete the job - related records will be handled by cascade delete in the database
            let _ = try await supabase
                .from("jobs")
                .delete()
                .eq("id", value: jobId)
                .execute()
            
            print("✅ Successfully deleted job: \(jobId)")
            
        } catch {
            print("❌ Error deleting job: \(error)")
            throw error
        }
    }
    
    // MARK: - Bids
    func fetchBids(for jobId: String) async throws -> [Bid] {
        do {
            print("Fetching bids for job: \(jobId)")
            
            let response = try await supabase
                .from("bids")
                .select("*, provider_profile:profiles!bids_provider_id_fkey(*)")
                .eq("job_id", value: jobId)
                .order("created_at", ascending: false)
                .execute()
            
            let decoder = JSONDecoder()
            let bids = try decoder.decode([Bid].self, from: response.data)
            print("Successfully decoded \(bids.count) bids")
            return bids
        } catch {
            print("Error fetching bids: \(error)")
            throw error
        }
    }

    func createBid(_ request: CreateBidRequest) async throws -> Bid {
        do {
            let user = try supabase.auth.requireCurrentUser()
            
            var bidData: [String: AnyJSON] = [
                "job_id": AnyJSON.string(request.job_id),
                "provider_id": AnyJSON.string(user.id.uuidString),
                "amount": AnyJSON.integer(request.amount),
                "proposal": AnyJSON.string(request.proposal),
                "timeline": AnyJSON.string(request.timeline)
            ]
            
            if let comments = request.comments {
                bidData["comments"] = AnyJSON.string(comments)
            }
            
            let response = try await supabase
                .from("bids")
                .insert(bidData)
                .select()
                .single()
                .execute()
            
            let decoder = JSONDecoder()
            let bid = try decoder.decode(Bid.self, from: response.data)
            return bid
        } catch {
            print("Error creating bid: \(error)")
            throw error
        }
    }

    func fetchProposalStatus(for jobId: String, providerId: String) async throws -> String? {
        do {
            let response = try await supabase
                .from("bids")
                .select("status")
                .eq("job_id", value: jobId)
                .eq("provider_id", value: providerId)
                .single()
                .execute()
            
            let data = try JSONSerialization.jsonObject(with: response.data) as? [String: Any]
            return data?["status"] as? String
        } catch {
            print("Error fetching proposal status: \(error)")
            return nil
        }
    }

    func checkApplicationStatus(jobId: String, userId: String) async throws -> String? {
        do {
            let response = try await supabase
                .from("bids")
                .select("status")
                .eq("job_id", value: jobId)
                .eq("provider_id", value: userId)
                .single()
                .execute()
            
            let bidData = try JSONSerialization.jsonObject(with: response.data) as? [String: Any]
            return bidData?["status"] as? String
        } catch {
            return nil
        }
    }
    
    func getJobCountForCategory(_ categoryName: String, from jobs: [Job]) -> Int {
        return jobs.filter { $0.category == categoryName }.count
    }
}
