import SwiftUI
import Supabase
import Auth

struct AuthView: View {
    enum Mode: String, CaseIterable { case signIn, signUp }

    @State private var mode: Mode = .signIn

    // Sign-in state
    @State private var signInKind: SignUpView.IdentifierKind = .phone
    @State private var email = ""
    @State private var phone = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage = ""

    // OTP sheet (driven by a phone signup)
    @State private var otpPhone: String?
    @State private var otpName = ""

    var body: some View {
        VStack(spacing: 0) {
            Image("AppLogoOnDark")
                .resizable()
                .scaledToFit()
                .frame(height: 80)
                .padding(.top, 60)
                .padding(.bottom, 16)

            Picker("", selection: $mode) {
                Text("sign_in".localized).tag(Mode.signIn)
                Text("sign_up".localized).tag(Mode.signUp)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.bottom, 8)

            switch mode {
            case .signIn:
                signInForm
            case .signUp:
                SignUpView { phone, name in
                    otpName = name
                    otpPhone = phone
                }
            }
        }
        .onOpenURL { _ in handleSignIn() }
        .sheet(item: Binding(
            get: { otpPhone.map { OtpPhone(value: $0) } },
            set: { otpPhone = $0?.value }
        )) { wrapped in
            OtpVerifyView(phone: wrapped.value, fullName: otpName)
        }
    }

    private var signInForm: some View {
        Form {
            Section {
                Picker("signup_identity".localized, selection: $signInKind) {
                    Text("phone".localized).tag(SignUpView.IdentifierKind.phone)
                    Text("email".localized).tag(SignUpView.IdentifierKind.email)
                }
                .pickerStyle(.segmented)

                if signInKind == .phone {
                    TextField("phone_hint_bd".localized, text: $phone)
                        .keyboardType(.numberPad)
                        .textContentType(.telephoneNumber)
                } else {
                    TextField("email".localized, text: $email)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                SecureField("password".localized, text: $password)
                    .textContentType(.password)
            }
            Section {
                Button("sign_in".localized) { signInTapped() }
                    .disabled(isLoading)
                if isLoading { ProgressView() }
            }
            if !errorMessage.isEmpty {
                Section { Text(errorMessage).foregroundStyle(.red) }
            }
        }
    }

    private func signInTapped() {
        isLoading = true
        errorMessage = ""
        let identifier: AuthIdentifier = signInKind == .phone ? .phone(phone) : .email(email)
        Task {
            do {
                try await supabase.auth.signInKaj(identifier: identifier, password: password)
                await MainActor.run { isLoading = false }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = String(format: "signin_failed".localized, error.localizedDescription)
                }
            }
        }
    }

    private func handleSignIn() {
        isLoading = true
        Task {
            do {
                let url = URL(string: "kajhobe://auth-callback")!
                try await supabase.auth.session(from: url)
                await MainActor.run { self.isLoading = false }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = "Sign in failed: \(error.localizedDescription)"
                }
            }
        }
    }
}

/// Identifiable wrapper so a phone string can drive a `.sheet(item:)`.
private struct OtpPhone: Identifiable {
    let value: String
    var id: String { value }
}
