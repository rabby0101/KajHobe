import SwiftUI
import Supabase

/// Phone OTP confirmation step. Shown right after a phone-based signup (or when a
/// phone login needs confirmation). On success, `authStateChanges` fires `.signedIn`
/// and `AppEntryView` swaps to the main app — we just dismiss.
struct OtpVerifyView: View {
    let phone: String          // raw BD local form, 01XXXXXXXXX
    let fullName: String       // used to seed the profile after verification

    @Environment(\.dismiss) private var dismiss
    @State private var code = ""
    @State private var isLoading = false
    @State private var errorMessage = ""

    var body: some View {
        VStack(spacing: 0) {
            Image("AppLogoOnDark")
                .resizable()
                .scaledToFit()
                .frame(height: 64)
                .padding(.top, 48)
                .padding(.bottom, 16)

            Form {
                Section {
                    Text(String(format: "otp_sent_to".localized, phone))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    TextField("otp_code".localized, text: $code)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                }

                Section {
                    Button("verify".localized) { verifyTapped() }
                        .disabled(code.count < 4 || isLoading)
                    if isLoading { ProgressView() }
                }

                if !errorMessage.isEmpty {
                    Section { Text(errorMessage).foregroundStyle(.red) }
                }
            }
        }
    }

    private func verifyTapped() {
        isLoading = true
        errorMessage = ""
        Task {
            do {
                try await supabase.auth.verifyPhoneOTPKaj(phone: phone, token: code)
                // Profile may not exist yet — create it with the chosen name.
                _ = try? await ProfileNetworking.shared.ensureUserProfile()
                await MainActor.run {
                    isLoading = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = String(format: "otp_failed".localized, error.localizedDescription)
                }
            }
        }
    }
}
