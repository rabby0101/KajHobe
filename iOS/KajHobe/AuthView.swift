import SwiftUI
import Supabase
import Auth

struct AuthView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var result: Result<Void, Error>?
    @State private var isAuthenticated = false
    @State private var errorMessage = ""
    @State private var showingError = false
    var body: some View {
        VStack(spacing: 0) {
            // Logo header section
            Image("AppLogoOnDark")
                .resizable()
                .scaledToFit()
                .frame(height: 80)
                .padding(.top, 60)
                .padding(.bottom, 24)

            // Existing form
            Form {
                Section {
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("Password", text: $password)
                        .textContentType(.password)
                }
                Section {
                    Button("Sign in") {
                        signInButtonTapped()
                    }
                    if isLoading {
                        ProgressView()
                    }
                }
                if let result {
                    Section {
                        switch result {
                        case .success:
                            Text("Signed in successfully.")
                        case .failure(let error):
                            Text(error.localizedDescription).foregroundStyle(.red)
                        }
                    }
                }
            }
        }
        .onOpenURL(perform: { url in
            handleSignIn()
        })
    }
    func signInButtonTapped() {
        signInWithEmail()
    }
    
    private func handleSignIn() {
        isLoading = true
        
        Task {
            do {
                let url = URL(string: "kajhobe://auth-callback")!
                try await supabase.auth.session(from: url)
                
                await MainActor.run {
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = "Sign in failed: \(error.localizedDescription)"
                    self.showingError = true
                }
            }
        }
    }
    
    private func signInWithEmail() {
        isLoading = true
        
        Task {
            do {
                _ = try await supabase.auth.signIn(email: email, password: password)
                
                await MainActor.run {
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = "Sign in failed: \(error.localizedDescription)"
                    self.showingError = true
                }
            }
        }
    }
} 