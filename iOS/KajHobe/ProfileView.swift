import SwiftUI
import Supabase

// MARK: - Profile Update Structure
nonisolated struct ProfileUpdate: Codable, Sendable {
    let full_name: String
    let bio: String
    let website: String
    let is_service_provider: Bool
    let updated_at: String
}

struct ProfileView: View {
    @State private var profile: Profile?
    @State private var isLoading = true
    @State private var isEditing = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingLogoutAlert = false
    @State private var showingLanguageSelection = false
    @ObservedObject private var languageManager = LanguageManager.shared
    
    // Editable fields
    @State private var fullName = ""
    @State private var bio = ""
    @State private var website = ""
    @State private var isServiceProvider = false
    
    var body: some View {
        NavigationView {
            if isLoading {
                ProgressView("Loading profile...")
            } else if let profile = profile {
                ScrollView {
                    VStack(spacing: 20) {
                        // Profile Header
                        VStack(spacing: 16) {
                            // Avatar (cache removed)
                            SimpleAvatar(
                                imageURL: profile.avatar_url,
                                name: profile.full_name ?? profile.email ?? "User",
                                size: 120
                            )
                            
                            // Name and email
                            VStack(spacing: 8) {
                                if isEditing {
                                    TextField("Full Name", text: $fullName)
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                        .multilineTextAlignment(.center)
                                } else {
                                    Text(profile.full_name ?? "No name")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                }
                                
                                Text(profile.email ?? "No email")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        
                        // Service Provider Toggle
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Account Type")
                                .font(.headline)
                            
                            Toggle(isOn: isEditing ? $isServiceProvider : .constant(profile.is_service_provider ?? false)) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Service Provider")
                                        .font(.body)
                                    Text("Enable to apply for jobs and offer services")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .disabled(!isEditing)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                        }
                        .padding(.horizontal)
                        
                        // Profile Details
                        VStack(alignment: .leading, spacing: 16) {
                            // Bio
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Bio")
                                    .font(.headline)
                                
                                if isEditing {
                                    TextEditor(text: $bio)
                                        .frame(minHeight: 100)
                                        .padding(8)
                                        .background(Color(.systemGray6))
                                        .cornerRadius(8)
                                } else {
                                    Text(profile.bio ?? "No bio")
                                        .font(.body)
                                        .foregroundColor(profile.bio == nil ? .secondary : .primary)
                                }
                            }
                            
                            // Website
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Website")
                                    .font(.headline)
                                
                                if isEditing {
                                    TextField("Website URL", text: $website)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                } else {
                                    if let website = profile.website, !website.isEmpty {
                                        if let url = URL(string: website) {
                                            Link(website, destination: url)
                                                .font(.body)
                                                .foregroundColor(.blue)
                                        } else {
                                            Text(website)
                                                .font(.body)
                                                .foregroundColor(.red)
                                        }
                                    } else {
                                        Text("No website")
                                            .font(.body)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            
                            // Stats (if service provider)
                            if profile.is_service_provider == true {
                                Divider()
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Service Provider Stats")
                                        .font(.headline)
                                    
                                    HStack(spacing: 40) {
                                        VStack {
                                            Text("\(profile.ratings_count ?? 0)")
                                                .font(.title2)
                                                .fontWeight(.bold)
                                            Text("Reviews")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        VStack {
                                            HStack(spacing: 4) {
                                                Text(String(format: "%.1f", profile.average_rating ?? 0.0))
                                                    .font(.title2)
                                                    .fontWeight(.bold)
                                                Image(systemName: "star.fill")
                                                    .foregroundColor(.yellow)
                                            }
                                            Text("Rating")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                        
                        // Language Selection Section
                        VStack(alignment: .leading, spacing: 16) {
                            Divider()
                            
                            VStack(alignment: .leading, spacing: 12) {
                                Text("app_language".localized)
                                    .font(.headline)
                                
                                Button(action: {
                                    showingLanguageSelection = true
                                }) {
                                    HStack {
                                        Image(systemName: "globe")
                                            .foregroundColor(.blue)
                                            .frame(width: 20)
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("language".localized)
                                                .font(.body)
                                                .foregroundColor(.primary)
                                            
                                            Text("\(languageManager.currentLanguage.flag) \(languageManager.currentLanguage.displayName)")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        Spacer()
                                        
                                        Image(systemName: "chevron.right")
                                            .foregroundColor(.secondary)
                                            .font(.caption)
                                    }
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(10)
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal)
                        
                        // Logout Section
                        VStack(alignment: .leading, spacing: 16) {
                            Divider()
                            
                            VStack(alignment: .leading, spacing: 12) {
                                Text("account".localized)
                                    .font(.headline)
                                
                                // Account Info
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Image(systemName: "envelope")
                                            .foregroundColor(.secondary)
                                            .frame(width: 20)
                                        Text(profile.email ?? "No email")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                        Spacer()
                                    }
                                    
                                    HStack {
                                        Image(systemName: "person.badge.plus")
                                            .foregroundColor(.secondary)
                                            .frame(width: 20)
                                        Text(profile.is_service_provider == true ? "Service Provider" : "Client")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                        Spacer()
                                    }
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(10)
                                
                                // Logout Button
                                Button(action: {
                                    // Add haptic feedback for logout action
                                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                    impactFeedback.impactOccurred()
                                    
                                    showingLogoutAlert = true
                                }) {
                                    HStack {
                                        Image(systemName: "rectangle.portrait.and.arrow.right")
                                            .foregroundColor(.white)
                                        Text("Logout")
                                            .foregroundColor(.white)
                                            .fontWeight(.semibold)
                                        Spacer()
                                    }
                                    .padding()
                                    .background(Color.red)
                                    .cornerRadius(10)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .navigationTitle("Profile")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(isEditing ? "Save" : "Edit") {
                            if isEditing {
                                saveProfile()
                            } else {
                                startEditing()
                            }
                        }
                        .disabled(isLoading)
                    }
                    
                    if isEditing {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Cancel") {
                                cancelEditing()
                            }
                        }
                    }
                }
            } else {
                VStack(spacing: 20) {
                    Image(systemName: "person.crop.circle.badge.exclamationmark")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)
                    
                    Text("No profile found")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Button("Reload") {
                        loadProfile()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .onAppear {
            loadProfile()
        }
        .sheet(isPresented: $showingLanguageSelection) {
            LanguageSelectionView()
        }
        .alert("error".localized, isPresented: $showingError) {
            Button("ok".localized) { }
        } message: {
            Text(errorMessage)
        }
        .alert("Logout", isPresented: $showingLogoutAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Logout", role: .destructive) {
                // Add haptic feedback for destructive action
                let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
                impactFeedback.impactOccurred()
                
                logout()
            }
        } message: {
            Text("Are you sure you want to logout? You will need to sign in again to access your account.")
        }
    }
    
    private func loadProfile() {
        isLoading = true
        
        Task {
            do {
                let user = try await supabase.auth.user()
                let fetchedProfile = try await Networking.shared.fetchProfile(userId: user.id.uuidString)
                await MainActor.run {
                    self.profile = fetchedProfile
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to load profile: \(error.localizedDescription)"
                    self.showingError = true
                    self.isLoading = false
                }
            }
        }
    }
    
    private func startEditing() {
        guard let profile = profile else { return }
        fullName = profile.full_name ?? ""
        bio = profile.bio ?? ""
        website = profile.website ?? ""
        isServiceProvider = profile.is_service_provider ?? false
        isEditing = true
    }
    
    private func cancelEditing() {
        isEditing = false
    }
    
    private func saveProfile() {
        guard profile != nil else { return }
        
        Task {
            do {
                let user = try await supabase.auth.user()
                
                // Create a properly encodable update structure
                let updates = ProfileUpdate(
                    full_name: fullName,
                    bio: bio,
                    website: website,
                    is_service_provider: isServiceProvider,
                    updated_at: ISO8601DateFormatter().string(from: Date())
                )
                
                try await supabase
                    .from("profiles")
                    .update(updates)
                    .eq("id", value: user.id.uuidString)
                    .execute()
                
                // Update local profile
                await MainActor.run {
                    self.profile?.full_name = fullName
                    self.profile?.bio = bio
                    self.profile?.website = website
                    self.profile?.is_service_provider = isServiceProvider
                    self.isEditing = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to save profile: \(error.localizedDescription)"
                    self.showingError = true
                }
            }
        }
    }
    
    private func logout() {
        Task {
            do {
                try await supabase.auth.signOut()
                print("✅ User logged out successfully")
                
                // Reset the app state by posting a notification
                await MainActor.run {
                    NotificationCenter.default.post(name: NSNotification.Name("UserLoggedOut"), object: nil)
                }
            } catch {
                print("❌ Error logging out: \(error)")
                await MainActor.run {
                    self.errorMessage = "Failed to logout: \(error.localizedDescription)"
                    self.showingError = true
                }
            }
        }
    }
}

// Simple Avatar replacement for cached avatar
struct SimpleAvatar: View {
    let imageURL: String?
    let name: String
    let size: CGFloat
    
    private var initial: String {
        String(name.prefix(1).uppercased())
    }
    
    var body: some View {
        Group {
            if let urlString = imageURL, let url = URL(string: urlString) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    ProgressView()
                        .scaleEffect(0.7)
                }
                .frame(width: size, height: size)
                .clipShape(Circle())
            } else {
                Circle()
                    .fill(LinearGradient(
                        gradient: Gradient(colors: [.blue, .purple]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: size, height: size)
                    .overlay(
                        Text(initial)
                            .font(.system(size: size * 0.4, weight: .semibold))
                            .foregroundColor(.white)
                    )
            }
        }
    }
}

#Preview {
    ProfileView()
} 
