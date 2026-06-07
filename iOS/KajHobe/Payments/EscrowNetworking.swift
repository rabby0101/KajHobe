import Foundation
import Supabase

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
