//
//  PublicProfileView.swift
//  KajHobe
//
//  Created by Push Notification Navigation
//

import SwiftUI
import Supabase

struct PublicProfileView: View {
    let userId: String
    @State private var profile: Profile?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var languageManager = LanguageManager.shared
    
    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Loading profile...")
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage = errorMessage {
                    VStack(spacing: 20) {
                        Image(systemName: "exclamationmark.circle")
                            .font(.system(size: 50))
                            .foregroundStyle(.red.opacity(0.8))
                        
                        Text("Profile not found")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                        
                        Text(errorMessage)
                            .foregroundStyle(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                        
                        Button("Close") {
                            dismiss()
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                } else if let profile = profile {
                    ScrollView {
                        VStack(spacing: 24) {
                            // Profile Header
                            VStack(spacing: 16) {
                                // Avatar
                                SimpleAvatar(
                                    imageURL: profile.avatar_url,
                                    name: profile.full_name ?? profile.email ?? "User",
                                    size: 120
                                )
                                
                                // Name and basic info
                                VStack(spacing: 8) {
                                    Text(profile.full_name ?? profile.email ?? "Anonymous User")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundStyle(.white)
                                    
                                    if let email = profile.email, profile.full_name != nil {
                                        Text(email)
                                            .font(.subheadline)
                                            .foregroundStyle(.white.opacity(0.8))
                                    }
                                    
                                    // Service Provider Badge
                                    if profile.is_service_provider == true {
                                        HStack(spacing: 6) {
                                            Image(systemName: "star.fill")
                                                .font(.caption)
                                            Text("Service Provider")
                                                .font(.caption)
                                                .fontWeight(.medium)
                                        }
                                        .foregroundStyle(.yellow)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 4)
                                        .background(.yellow.opacity(0.2))
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                    }
                                }
                            }
                            .padding(.top)
                            
                            // Profile Details
                            VStack(spacing: 20) {
                                if let bio = profile.bio, !bio.isEmpty {
                                    ProfileDetailCard(
                                        title: "About",
                                        content: bio,
                                        icon: "person.text.rectangle"
                                    )
                                }
                                
                                if let website = profile.website, !website.isEmpty {
                                    ProfileDetailCard(
                                        title: "Website",
                                        content: website,
                                        icon: "link",
                                        isLink: true
                                    )
                                }
                                
                                // Member since
                                if let createdAt = profile.created_at {
                                    ProfileDetailCard(
                                        title: "Member since",
                                        content: formatDate(createdAt),
                                        icon: "calendar"
                                    )
                                }
                            }
                            .padding(.horizontal)
                            
                            // Action Buttons
                            VStack(spacing: 12) {
                                Button(action: {
                                    // TODO: Implement send message functionality
                                    sendMessage()
                                }) {
                                    HStack {
                                        Image(systemName: "message")
                                        Text("Send Message")
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(.white.opacity(0.1))
                                    .foregroundStyle(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                                
                                Button(action: {
                                    // TODO: Implement report functionality
                                    reportUser()
                                }) {
                                    HStack {
                                        Image(systemName: "flag")
                                        Text("Report User")
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(.red.opacity(0.1))
                                    .foregroundStyle(.red)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                            }
                            .padding(.horizontal)
                            .padding(.bottom)
                        }
                    }
                }
            }
            .gradientBackground(animated: true)
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }
            }
        }
        .task {
            await loadProfile()
        }
    }
    
    private func loadProfile() async {
        do {
            let response = try await supabase
                .from("profiles")
                .select("*")
                .eq("id", value: userId)
                .execute()

            let decoder = JSONDecoder()
            let profiles = try decoder.decode([Profile].self, from: response.data)
            
            await MainActor.run {
                if let fetchedProfile = profiles.first {
                    self.profile = fetchedProfile
                    print("✅ Successfully loaded profile for user: \(userId)")
                } else {
                    self.errorMessage = "Profile not found"
                    print("❌ Profile not found for user: \(userId)")
                }
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to load profile: \(error.localizedDescription)"
                self.isLoading = false
                print("❌ Failed to load profile: \(error)")
            }
        }
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: dateString) else {
            return dateString
        }
        
        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .medium
        displayFormatter.timeStyle = .none
        return displayFormatter.string(from: date)
    }
    
    private func sendMessage() {
        // TODO: Implement message functionality
        // This could navigate to a new conversation or show a compose message view
        print("📱 Send message to user: \(userId)")
        
        // Example: Navigate to messages with this user
        NotificationCenter.default.post(
            name: NSNotification.Name("StartConversationWithUser"),
            object: userId
        )
        
        dismiss()
    }
    
    private func reportUser() {
        // TODO: Implement user reporting
        print("🚨 Report user: \(userId)")
        
        // You could show an action sheet with report options
        // or navigate to a reporting form
    }
}

struct ProfileDetailCard: View {
    let title: String
    let content: String
    let icon: String
    var isLink: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(.white.opacity(0.8))
                    .frame(width: 16)
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.white.opacity(0.8))
                
                Spacer()
            }
            
            if isLink, let url = URL(string: content) {
                Link(content, destination: url)
                    .font(.body)
                    .foregroundStyle(.blue)
            } else {
                Text(content)
                    .font(.body)
                    .foregroundStyle(.white)
            }
        }
        .padding()
        .background(.white.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    PublicProfileView(userId: "sample-user-id")
}