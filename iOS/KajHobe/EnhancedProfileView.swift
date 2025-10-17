import SwiftUI
import Supabase

struct EnhancedProfileView: View {
    @State private var profile: Profile?
    @State private var isLoading = true
    @State private var isEditing = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingLogoutAlert = false
    @State private var showingSkillsEditor = false
    @State private var showingPortfolioEditor = false
    @State private var completionPercentage: Double = 0.0
    
    // Profile fields
    @State private var fullName = ""
    @State private var bio = ""
    @State private var website = ""
    @State private var isServiceProvider = false
    @State private var skills: [String] = []
    @State private var hourlyRate: String = ""
    @State private var experience = ""
    @State private var location = ""
    @State private var availability = "Available"
    @State private var languages: [String] = []
    @State private var certifications: [String] = []
    
    var body: some View {
        NavigationStack {
            if isLoading {
                ProgressView("Loading profile...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemGroupedBackground))
            } else if let profile = profile {
                ScrollView {
                    VStack(spacing: 24) {
                        // Profile Completion Card
                        ProfileCompletionCard(
                            completionPercentage: completionPercentage,
                            onComplete: loadProfile
                        )
                        
                        // Profile Header
                        ProfileHeaderSection(
                            profile: profile,
                            isEditing: isEditing,
                            fullName: $fullName,
                            bio: $bio,
                            location: $location,
                            availability: $availability
                        )
                        
                        // Quick Stats (for service providers)
                        if isServiceProvider {
                            QuickStatsSection(
                                completedJobs: 15,
                                rating: 4.8,
                                responseTime: "2 hours"
                            )
                        }
                        
                        // Skills Section
                        SkillsSection(
                            skills: $skills,
                            isEditing: isEditing,
                            onEditSkills: {
                                showingSkillsEditor = true
                            }
                        )
                        
                        // Professional Info
                        ProfessionalInfoSection(
                            isEditing: isEditing,
                            hourlyRate: $hourlyRate,
                            experience: $experience,
                            languages: $languages,
                            certifications: $certifications
                        )
                        
                        // Portfolio Section (for service providers)
                        if isServiceProvider {
                            PortfolioSection(
                                onEditPortfolio: {
                                    showingPortfolioEditor = true
                                }
                            )
                        }
                        
                        // Contact Information
                        ContactInfoSection(
                            isEditing: isEditing,
                            website: $website,
                            email: profile.email ?? ""
                        )
                        
                        // Account Actions
                        AccountActionsSection(
                            onLogout: {
                                showingLogoutAlert = true
                            }
                        )
                    }
                    .padding(.horizontal)
                }
                .background(Color(.systemGroupedBackground))
            } else {
                // Simple empty state for profile context
                VStack {
                    Image(systemName: "person.circle")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    Text("No profile data available")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemGroupedBackground))
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
                .fontWeight(.semibold)
            }
        }
        .task {
            await loadProfile()
        }
        .sheet(isPresented: $showingSkillsEditor) {
            SkillsEditorView(skills: $skills)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingPortfolioEditor) {
            PortfolioEditorView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .alert("Sign Out", isPresented: $showingLogoutAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Sign Out", role: .destructive) {
                signOut()
            }
        } message: {
            Text("Are you sure you want to sign out?")
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func loadProfile() async {
        isLoading = true
        do {
            profile = try await Networking.shared.getCurrentUserProfile()
            if let profile = profile {
                populateFields(from: profile)
                calculateCompletionPercentage()
            }
        } catch {
            errorMessage = "Failed to load profile: \(error.localizedDescription)"
            showingError = true
        }
        isLoading = false
    }
    
    private func populateFields(from profile: Profile) {
        fullName = profile.full_name ?? ""
        bio = profile.bio ?? ""
        website = profile.website ?? ""
        isServiceProvider = profile.is_service_provider ?? false
        location = profile.location ?? ""
        // Add more field population as needed
    }
    
    private func calculateCompletionPercentage() {
        var completedFields = 0
        let totalFields = 8
        
        if !fullName.isEmpty { completedFields += 1 }
        if !bio.isEmpty { completedFields += 1 }
        if !location.isEmpty { completedFields += 1 }
        if !skills.isEmpty { completedFields += 1 }
        if !hourlyRate.isEmpty { completedFields += 1 }
        if !experience.isEmpty { completedFields += 1 }
        if !website.isEmpty { completedFields += 1 }
        if !languages.isEmpty { completedFields += 1 }
        
        completionPercentage = Double(completedFields) / Double(totalFields)
    }
    
    private func startEditing() {
        isEditing = true
    }
    
    private func saveProfile() {
        Task {
            // Save profile logic here
            await loadProfile()
            isEditing = false
        }
    }
    
    private func signOut() {
        Task {
            do {
                try await supabase.auth.signOut()
            } catch {
                errorMessage = "Failed to sign out: \(error.localizedDescription)"
                showingError = true
            }
        }
    }
}

// MARK: - Profile Completion Card
struct ProfileCompletionCard: View {
    let completionPercentage: Double
    let onComplete: () async -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Profile Completion")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("\(Int(completionPercentage * 100))% complete")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 6)
                        .frame(width: 60, height: 60)
                    
                    Circle()
                        .trim(from: 0, to: completionPercentage)
                        .stroke(
                            AngularGradient(
                                colors: [.blue, .purple, .blue],
                                center: .center
                            ),
                            style: StrokeStyle(lineWidth: 6, lineCap: .round)
                        )
                        .frame(width: 60, height: 60)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 1.0), value: completionPercentage)
                    
                    Text("\(Int(completionPercentage * 100))%")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }
            }
            
            if completionPercentage < 1.0 {
                Text("Complete your profile to get more job opportunities")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Profile Header Section
struct ProfileHeaderSection: View {
    let profile: Profile
    let isEditing: Bool
    @Binding var fullName: String
    @Binding var bio: String
    @Binding var location: String
    @Binding var availability: String
    
    var body: some View {
        VStack(spacing: 16) {
            // Avatar (cache removed)
            SimpleAvatar(
                imageURL: profile.avatar_url,
                name: profile.full_name ?? profile.email ?? "User",
                size: 100
            )
            .overlay(
                Circle()
                    .stroke(Color.blue.opacity(0.3), lineWidth: 3)
            )
            
            VStack(spacing: 8) {
                if isEditing {
                    TextField("Full Name", text: $fullName)
                        .font(.title2)
                        .fontWeight(.bold)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .multilineTextAlignment(.center)
                } else {
                    Text(fullName.isEmpty ? "Add your name" : fullName)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(fullName.isEmpty ? .secondary : .primary)
                }
                
                HStack(spacing: 4) {
                    Image(systemName: "location")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if isEditing {
                        TextField("Location", text: $location)
                            .font(.subheadline)
                            .textFieldStyle(PlainTextFieldStyle())
                    } else {
                        Text(location.isEmpty ? "Add location" : location)
                            .font(.subheadline)
                            .foregroundColor(location.isEmpty ? .secondary : .primary)
                    }
                }
                
                // Status indicator
                HStack(spacing: 6) {
                    Circle()
                        .fill(availability == "Available" ? Color.green : Color.orange)
                        .frame(width: 8, height: 8)
                    
                    Text(availability)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(availability == "Available" ? .green : .orange)
                }
            }
            
            if isEditing {
                TextEditor(text: $bio)
                    .frame(minHeight: 80)
                    .padding(8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            } else {
                Text(bio.isEmpty ? "Add a bio to tell clients about yourself" : bio)
                    .font(.body)
                    .foregroundColor(bio.isEmpty ? .secondary : .primary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Quick Stats Section
struct QuickStatsSection: View {
    let completedJobs: Int
    let rating: Double
    let responseTime: String
    
    var body: some View {
        HStack(spacing: 20) {
            StatItem(
                title: "Jobs Completed",
                value: "\(completedJobs)",
                icon: "checkmark.circle.fill",
                color: .green
            )
            
            StatItem(
                title: "Rating",
                value: String(format: "%.1f", rating),
                icon: "star.fill",
                color: .yellow
            )
            
            StatItem(
                title: "Response Time",
                value: responseTime,
                icon: "clock.fill",
                color: .blue
            )
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

struct StatItem: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Skills Section
struct SkillsSection: View {
    @Binding var skills: [String]
    let isEditing: Bool
    let onEditSkills: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Skills")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if !isEditing {
                    Button("Edit") {
                        onEditSkills()
                    }
                    .font(.subheadline)
                    .foregroundColor(.blue)
                }
            }
            
            if skills.isEmpty {
                Text("Add skills to showcase your expertise")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .padding(.vertical)
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                    ForEach(skills, id: \.self) { skill in
                        SkillChip(skill: skill)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

struct SkillChip: View {
    let skill: String
    
    var body: some View {
        Text(skill)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.blue.opacity(0.1))
            .foregroundColor(.blue)
            .cornerRadius(16)
    }
}

// MARK: - Other sections would continue here...
// For brevity, I'll add placeholder views for the remaining sections

struct ProfessionalInfoSection: View {
    let isEditing: Bool
    @Binding var hourlyRate: String
    @Binding var experience: String
    @Binding var languages: [String]
    @Binding var certifications: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Professional Information")
                .font(.headline)
                .fontWeight(.semibold)
            
            // Implementation would go here
            Text("Professional info content...")
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

struct PortfolioSection: View {
    let onEditPortfolio: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Portfolio")
                .font(.headline)
                .fontWeight(.semibold)
            
            // Implementation would go here
            Text("Portfolio content...")
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

struct ContactInfoSection: View {
    let isEditing: Bool
    @Binding var website: String
    let email: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Contact Information")
                .font(.headline)
                .fontWeight(.semibold)
            
            // Implementation would go here
            Text("Contact info content...")
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

struct AccountActionsSection: View {
    let onLogout: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            Button(action: onLogout) {
                Text("Sign Out")
                    .font(.headline)
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(12)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Skills Editor Sheet
struct SkillsEditorView: View {
    @Binding var skills: [String]
    @State private var newSkill = ""
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                HStack {
                    TextField("Add a skill...", text: $newSkill)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Button("Add") {
                        if !newSkill.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            skills.append(newSkill.trimmingCharacters(in: .whitespacesAndNewlines))
                            newSkill = ""
                        }
                    }
                    .disabled(newSkill.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding()
                
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                        ForEach(skills.indices, id: \.self) { index in
                            HStack {
                                Text(skills[index])
                                    .font(.body)
                                
                                Spacer()
                                
                                Button(action: {
                                    skills.remove(at: index)
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.red)
                                }
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }
                    }
                    .padding()
                }
                
                Spacer()
            }
            .navigationTitle("Edit Skills")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Portfolio Editor (placeholder)
struct PortfolioEditorView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Text("Portfolio Editor")
                .navigationTitle("Edit Portfolio")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
        }
    }
}

#Preview {
    EnhancedProfileView()
}