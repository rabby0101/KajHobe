import SwiftUI
import Supabase
import Auth

struct AuthView: View {
    enum Mode: String, CaseIterable { case signIn, signUp }

    @State private var mode: Mode = .signIn
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage = ""

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
            case .signIn: signInForm
            case .signUp: SignUpView()
            }
        }
        .onOpenURL { url in handleCallback(url) }
    }

    private var signInForm: some View {
        Form {
            Section {
                TextField("email".localized, text: $email)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                SecureField("password".localized, text: $password)
                    .textContentType(.password)
            }
            Section {
                Button("sign_in".localized) { signInTapped() }
                    .disabled(isLoading)
                if isLoading { ProgressView() }
            }
            Section("continue_with".localized) {
                Button { oauth(.google) } label: { Label("Google", systemImage: "globe") }
                Button { oauth(.apple) } label: { Label("Apple", systemImage: "applelogo") }
                Button { oauth(.facebook) } label: { Label("Facebook", systemImage: "person.2.fill") }
            }
            if !errorMessage.isEmpty {
                Section { Text(errorMessage).foregroundStyle(.red) }
            }
        }
    }

    private func signInTapped() {
        isLoading = true
        errorMessage = ""
        Task {
            do {
                _ = try await supabase.auth.signIn(email: email, password: password)
                await MainActor.run { isLoading = false }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = String(format: "signin_failed".localized, error.localizedDescription)
                }
            }
        }
    }

    /// Browser-redirect OAuth. The SDK presents a web auth session and completes
    /// it via the `kajhobe://auth-callback` scheme.
    private func oauth(_ provider: Provider) {
        isLoading = true
        errorMessage = ""
        Task {
            do {
                try await supabase.auth.signInWithOAuth(
                    provider: provider,
                    redirectTo: URL(string: "kajhobe://auth-callback")
                )
                await MainActor.run { isLoading = false }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = String(format: "signin_failed".localized, error.localizedDescription)
                }
            }
        }
    }

    private func handleCallback(_ url: URL) {
        Task {
            do {
                try await supabase.auth.session(from: url)
                await MainActor.run { isLoading = false }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "Sign in failed: \(error.localizedDescription)"
                }
            }
        }
    }
}
