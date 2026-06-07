import UIKit
import AuthenticationServices

/// Wraps `ASWebAuthenticationSession` so we can present the bKash sandbox
/// checkout and capture the `kajhobe://escrow-callback` redirect (no Info.plist
/// URL-scheme registration needed — the session matches on `callbackURLScheme`).
///
/// Reusable from anywhere a checkout must be shown (the "Accept & Pay" button in
/// chat, or any fallback). Retain the instance until `completion` fires.
final class BkashCheckoutSession: NSObject, ASWebAuthenticationPresentationContextProviding {
    private var session: ASWebAuthenticationSession?

    func start(url: URL, scheme: String, completion: @escaping (Result<URL, Error>) -> Void) {
        let session = ASWebAuthenticationSession(url: url, callbackURLScheme: scheme) { callbackURL, error in
            if let callbackURL {
                completion(.success(callbackURL))
            } else {
                completion(.failure(error ?? PaymentError.message("Checkout cancelled.")))
            }
        }
        session.presentationContextProvider = self
        session.prefersEphemeralWebBrowserSession = false
        self.session = session
        session.start()
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first ?? ASPresentationAnchor()
    }

    /// Convenience: parse the `status` query item from the callback URL.
    static func status(from callback: URL) -> String? {
        URLComponents(url: callback, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "status" })?.value
    }
}
