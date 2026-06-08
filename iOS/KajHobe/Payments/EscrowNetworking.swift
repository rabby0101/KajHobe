import Foundation
import Supabase

// Encodable payload for the payout-account upsert. Declared `nonisolated` +
// `Sendable` so it satisfies the supabase SDK's Sendable requirement under the
// project's default-MainActor isolation (mirrors ProfileUpdate in ProfileView).
nonisolated struct PayoutAccountUpsert: Codable, Sendable {
    let user_id: String
    let bkash_number: String
}

// ---------------------------------------------------------------------------
// EscrowNetworking — read escrow rows + drive payment actions through the seam.
//
// Reads go straight to the `escrow_transactions` table (RLS limits rows to the
// deal's participants / admins). Writes never touch the table directly; they go
// through the payment provider (Edge Function for collection, SECURITY DEFINER
// RPCs for admin payout/refund).
// ---------------------------------------------------------------------------
final class EscrowNetworking: BaseNetworking {
    static let shared = EscrowNetworking()

    private let collectionProvider: PaymentProvider = BkashSandboxProvider()
    private let payoutProvider: PaymentProvider = ManualPayoutProvider()

    // MARK: - Reads

    /// The escrow row for a deal (nil if none exists yet).
    func fetchEscrow(forDealId dealId: String) async throws -> EscrowTransaction? {
        let resp = try await supabase
            .from("escrow_transactions")
            .select("*")
            .eq("deal_id", value: dealId)
            .limit(1)
            .execute()
        let rows = try JSONDecoder().decode([EscrowTransaction].self, from: resp.data)
        return rows.first
    }

    /// All escrow rows where the current user is buyer or provider, newest first.
    func fetchMyEscrows() async throws -> [EscrowTransaction] {
        let user = try supabase.auth.requireCurrentUser()
        let uid = user.id.uuidString.lowercased()
        let resp = try await supabase
            .from("escrow_transactions")
            .select("*")
            .or("client_id.eq.\(uid),provider_id.eq.\(uid)")
            .order("created_at", ascending: false)
            .execute()
        return try JSONDecoder().decode([EscrowTransaction].self, from: resp.data)
    }

    // MARK: - Collection (client pays at acceptance)

    /// Start a bKash sandbox checkout for a deal OFFER; returns the URL to present.
    /// On a confirmed capture the webhook creates the deal and holds the escrow.
    func startCollection(dealOfferId: String) async throws -> URL {
        try await collectionProvider.startCollection(dealOfferId: dealOfferId)
    }

    // MARK: - Admin actions (manual payout leg)

    func markPaidOut(escrowId: String, note: String? = nil) async throws {
        try await payoutProvider.payout(escrowId: escrowId, note: note)
    }

    func markRefunded(escrowId: String, note: String? = nil) async throws {
        try await payoutProvider.refund(escrowId: escrowId, note: note)
    }

    // MARK: - Provider payout account (private bKash number)

    /// The current user's payout (bKash) number, or nil if none set yet.
    /// RLS restricts this row to the owner (or an admin), so the number never
    /// leaks to other users — it is NOT part of `profiles` / `public_profiles`.
    func fetchMyPayoutNumber() async throws -> String? {
        let user = try supabase.auth.requireCurrentUser()
        let resp = try await supabase
            .from("provider_payout_accounts")
            .select("bkash_number")
            .eq("user_id", value: user.id.uuidString.lowercased())
            .limit(1)
            .execute()
        struct Row: Decodable { let bkash_number: String }
        let rows = try JSONDecoder().decode([Row].self, from: resp.data)
        return rows.first?.bkash_number
    }

    /// Create or update the current user's payout (bKash) number. The DB CHECK
    /// constraint also enforces the 01XXXXXXXXX format as a backstop.
    func upsertMyPayoutNumber(_ number: String) async throws {
        let user = try supabase.auth.requireCurrentUser()
        try await supabase
            .from("provider_payout_accounts")
            .upsert(PayoutAccountUpsert(user_id: user.id.uuidString.lowercased(), bkash_number: number),
                    onConflict: "user_id")
            .execute()
    }

    /// Whether the signed-in user is in the `app_admins` allowlist (drives the
    /// admin-only payout/refund affordances).
    func isCurrentUserAdmin() async -> Bool {
        guard let user = try? supabase.auth.requireCurrentUser() else { return false }
        do {
            let resp = try await supabase
                .rpc("is_admin", params: AnyEncodable(["p_uid": user.id.uuidString]))
                .execute()
            return (try? JSONDecoder().decode(Bool.self, from: resp.data)) ?? false
        } catch {
            return false
        }
    }
}
