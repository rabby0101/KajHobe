import SwiftUI
import Supabase

/// Account creation with email + password. (Phone signup/OTP is postponed until a
/// BD SMS gateway is available — see Supabase.swift / the SMS edge function.)
struct SignUpView: View {
    @State private var fullName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var infoMessage = ""
    @State private var errorMessage = ""

    private var canSubmit: Bool {
        !fullName.trimmingCharacters(in: .whitespaces).isEmpty
            && email.contains("@")
            && password.count >= 6
            && !isLoading
    }

    var body: some View {
        Form {
            Section {
                TextField("full_name".localized, text: $fullName)
                    .textContentType(.name)
                TextField("email".localized, text: $email)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                SecureField("password".localized, text: $password)
                    .textContentType(.newPassword)
            } footer: {
                Text("password_min_hint".localized)
            }

            Section {
                Button("create_account".localized) { submit() }
                    .disabled(!canSubmit)
                if isLoading { ProgressView() }
            }

            if !infoMessage.isEmpty {
                Section { Text(infoMessage).foregroundStyle(.secondary) }
            }
            if !errorMessage.isEmpty {
                Section { Text(errorMessage).foregroundStyle(.red) }
            }
        }
    }

    private func submit() {
        isLoading = true
        infoMessage = ""
        errorMessage = ""
        let name = fullName.trimmingCharacters(in: .whitespaces)
        Task {
            do {
                _ = try await supabase.auth.signUp(
                    email: email,
                    password: password,
                    data: ["full_name": .string(name)]
                )
                await MainActor.run {
                    isLoading = false
                    infoMessage = "check_email_confirm".localized
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = String(format: "signup_failed".localized, error.localizedDescription)
                }
            }
        }
    }
}
