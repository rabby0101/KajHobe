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

// MARK: - Signup / OTP helpers
//
// Signup supports either an email or a Bangladeshi phone number as the identity.
// Email goes through Supabase's email-confirmation link; phone goes through an
// SMS OTP delivered by our `send-sms-otp` edge function (BD gateway relay).

/// Which identity the user is signing up / in with.
enum AuthIdentifier: Equatable {
    case email(String)
    case phone(String)   // raw BD local form, 01XXXXXXXXX
}

/// 01XXXXXXXXX -> 8801XXXXXXXXX. Supabase stores phone without a leading "+";
/// our SMS hook normalises further when handing off to the gateway.
nonisolated func bdPhoneToSupabase(_ phone: String) -> String {
    let digits = phone.filter(\.isNumber)
    if digits.hasPrefix("880") { return digits }
    if digits.hasPrefix("0") { return "88" + digits }
    return digits
}

extension AuthClient {
    /// Create an account. Returns `true` when a phone OTP step is still required
    /// (no session yet); `false` for the email path (confirmation link sent).
    @discardableResult
    nonisolated func signUpKaj(
        identifier: AuthIdentifier,
        password: String,
        fullName: String
    ) async throws -> Bool {
        let meta: [String: AnyJSON] = ["full_name": .string(fullName)]
        switch identifier {
        case .email(let email):
            _ = try await signUp(email: email, password: password, data: meta)
            return false
        case .phone(let phone):
            let response = try await signUp(
                phone: bdPhoneToSupabase(phone),
                password: password,
                data: meta
            )
            return response.session == nil
        }
    }

    /// Sign in with email+password or phone+password.
    nonisolated func signInKaj(identifier: AuthIdentifier, password: String) async throws {
        switch identifier {
        case .email(let email):
            _ = try await signIn(email: email, password: password)
        case .phone(let phone):
            _ = try await signIn(phone: bdPhoneToSupabase(phone), password: password)
        }
    }

    /// Confirm a phone signup/login with the 6-digit SMS OTP.
    nonisolated func verifyPhoneOTPKaj(phone: String, token: String) async throws {
        _ = try await verifyOTP(phone: bdPhoneToSupabase(phone), token: token, type: .sms)
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
