import SwiftUI
import Supabase

/// Account creation. The user picks an identity type — email or BD phone — then
/// supplies a name + password. Phone signups need an OTP step (handled by the
/// parent via `onPhoneOTPRequired`); email signups get a confirmation link.
struct SignUpView: View {
    /// Called when a phone signup succeeds and an OTP must be entered next.
    var onPhoneOTPRequired: (_ phone: String, _ fullName: String) -> Void

    enum IdentifierKind: String, CaseIterable { case phone, email }

    @State private var kind: IdentifierKind = .phone
    @State private var fullName = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var infoMessage = ""
    @State private var errorMessage = ""

    private var isPhoneValid: Bool {
        phone.range(of: "^01[0-9]{9}$", options: .regularExpression) != nil
    }
    private var canSubmit: Bool {
        !fullName.trimmingCharacters(in: .whitespaces).isEmpty
            && password.count >= 6
            && (kind == .phone ? isPhoneValid : email.contains("@"))
            && !isLoading
    }

    var body: some View {
        Form {
            Section {
                Picker("signup_identity".localized, selection: $kind) {
                    Text("phone".localized).tag(IdentifierKind.phone)
                    Text("email".localized).tag(IdentifierKind.email)
                }
                .pickerStyle(.segmented)
            }

            Section {
                TextField("full_name".localized, text: $fullName)
                    .textContentType(.name)

                if kind == .phone {
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
        let identifier: AuthIdentifier = kind == .phone ? .phone(phone) : .email(email)

        Task {
            do {
                let needsOTP = try await supabase.auth.signUpKaj(
                    identifier: identifier, password: password, fullName: name
                )
                await MainActor.run {
                    isLoading = false
                    if needsOTP {
                        onPhoneOTPRequired(phone, name)
                    } else {
                        // Email path: confirmation link sent.
                        infoMessage = "check_email_confirm".localized
                    }
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
