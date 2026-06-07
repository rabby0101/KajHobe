import Foundation
import Supabase

// ---------------------------------------------------------------------------
// Payment-provider seam.
//
// Isolates the actual money-movement rail from the rest of the app so the bKash
// implementation can evolve (sandbox -> production -> B2C payout) without the UI
// or networking layer changing.
//
//   * Collection (buyer -> merchant) is REAL against the bKash Tokenized
//     Checkout sandbox, via the `bkash-collect` Edge Function.
//   * Payout (merchant -> provider) and refunds are MANUAL admin actions today
//     (SECURITY DEFINER RPCs), because bKash B2C disbursement has no open
//     sandbox and needs merchant onboarding. The seam is ready to swap in a
//     real `bkash-payout` Edge Function call once that exists.
// ---------------------------------------------------------------------------

/// Decoded response from the `bkash-collect` Edge Function.
struct CollectionStart: Decodable, Sendable {
    let bkash_url: String
    let payment_id: String
}

enum PaymentError: LocalizedError {
    case notConfigured(String)
    case message(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured(let m): return m
        case .message(let m):       return m
        }
    }
}

protocol PaymentProvider: Sendable {
    /// Begin collecting the client's payment for a deal OFFER (at acceptance);
    /// returns a checkout URL to present. The deal is created only after capture.
    func startCollection(dealOfferId: String) async throws -> URL
    /// Release funds to the provider for a `released` escrow.
    func payout(escrowId: String, note: String?) async throws
    /// Refund a held/released escrow back to the buyer.
    func refund(escrowId: String, note: String?) async throws
}

// MARK: - bKash sandbox collection

/// Collection via the `bkash-collect` Edge Function (server holds the secrets).
/// Payout/refund are not this provider's job — see `ManualPayoutProvider`.
struct BkashSandboxProvider: PaymentProvider {
    func startCollection(dealOfferId: String) async throws -> URL {
        let resp: CollectionStart = try await supabase.functions.invoke(
            "bkash-collect",
            options: FunctionInvokeOptions(body: AnyEncodable(["deal_offer_id": dealOfferId]))
        )
        guard let url = URL(string: resp.bkash_url) else {
            throw PaymentError.message("bKash returned an invalid checkout URL.")
        }
        return url
    }

    func payout(escrowId: String, note: String?) async throws {
        throw PaymentError.notConfigured(
            "bKash B2C disbursement isn't enabled yet — provider payout is a manual admin step.")
    }

    func refund(escrowId: String, note: String?) async throws {
        throw PaymentError.notConfigured("Automatic refunds aren't enabled yet.")
    }
}

// MARK: - Manual admin payout/refund

/// Manual reconciliation leg: an admin records that they paid the provider (or
/// refunded the buyer) by hand. Backed by the `escrow_mark_paid_out` /
/// `escrow_mark_refunded` SECURITY DEFINER RPCs, which enforce `is_admin`.
struct ManualPayoutProvider: PaymentProvider {
    func startCollection(dealOfferId: String) async throws -> URL {
        throw PaymentError.notConfigured("Manual provider does not collect payments.")
    }

    func payout(escrowId: String, note: String?) async throws {
        var params: [String: Any] = ["p_escrow_id": escrowId]
        if let note { params["p_notes"] = note }
        _ = try await supabase.rpc("escrow_mark_paid_out", params: AnyEncodable(params)).execute()
    }

    func refund(escrowId: String, note: String?) async throws {
        var params: [String: Any] = ["p_escrow_id": escrowId]
        if let note { params["p_notes"] = note }
        _ = try await supabase.rpc("escrow_mark_refunded", params: AnyEncodable(params)).execute()
    }
}
