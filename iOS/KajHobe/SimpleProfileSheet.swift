import SwiftUI
import Supabase

// Simple model matching the database
struct SimplePublicProfile: Codable, Identifiable {
    let id: String
    let full_name: String?
    let avatar_url: String?
    let bio: String?
    let location: String?
    let website: String?
    let is_service_provider: Bool
    let created_at: String
    let completed_jobs: Int
    let avg_job_value: Double
    let total_earnings: Double
    let avg_rating: Double
    let review_count: Int
    let is_online: Bool
    let last_seen_at: String?
    let average_response_time_minutes: Int?
    let service_categories: [String]
    let trust_level: String
    let last_updated: String

    // Provider detail fields (power the redesigned PublicProfileDetailView)
    var profession: String? = nil
    var tagline: String? = nil
    var experience_years: Int? = nil
    var hourly_rate: Double? = nil
    var team_rate: Double? = nil
    var team_hours_label: String? = nil

    /// Bridge to the rich PublicProfile model used by the redesigned profile screen.
    func toPublicProfile() -> PublicProfile {
        PublicProfile(
            id: id,
            full_name: full_name,
            avatar_url: avatar_url,
            bio: bio,
            location: location,
            website: website,
            is_service_provider: is_service_provider,
            created_at: created_at,
            completed_jobs: completed_jobs,
            avg_job_value: avg_job_value,
            total_earnings: total_earnings,
            avg_rating: avg_rating,
            review_count: review_count,
            is_online: is_online,
            last_seen_at: last_seen_at,
            average_response_time_minutes: average_response_time_minutes,
            service_categories: service_categories,
            trust_level: trust_level,
            last_updated: last_updated,
            profession: profession,
            tagline: tagline,
            experience_years: experience_years,
            hourly_rate: hourly_rate,
            team_rate: team_rate,
            team_hours_label: team_hours_label
        )
    }
}

// Simple profile sheet view
struct SimpleProfileSheet: View {
    let profile: SimplePublicProfile
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Debug info
                    Text("DEBUG: Profile ID: \(profile.id)")
                        .font(.caption)
                        .foregroundColor(.red)

                    // Header with avatar and basic info
                    VStack(spacing: 16) {
                        // Avatar
                        if let avatarUrl = profile.avatar_url, !avatarUrl.isEmpty {
                            AsyncImage(url: URL(string: avatarUrl)) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Circle()
                                    .fill(Color.blue.opacity(0.3))
                                    .overlay(
                                        Text(String(profile.full_name?.prefix(1) ?? "?"))
                                            .font(.title)
                                            .foregroundColor(.white)
                                    )
                            }
                            .frame(width: 100, height: 100)
                            .clipShape(Circle())
                        } else {
                            Circle()
                                .fill(Color.blue.opacity(0.3))
                                .frame(width: 100, height: 100)
                                .overlay(
                                    Text(String(profile.full_name?.prefix(1) ?? "?"))
                                        .font(.title)
                                        .foregroundColor(.white)
                                )
                        }

                        // Name and basic info
                        VStack(spacing: 8) {
                            Text(profile.full_name ?? "Unknown Provider")
                                .font(.title2)
                                .fontWeight(.bold)
                                .multilineTextAlignment(.center)

                            if let location = profile.location, !location.isEmpty {
                                HStack {
                                    Image(systemName: "location")
                                        .font(.caption)
                                    Text(location)
                                        .font(.subheadline)
                                }
                                .foregroundColor(.secondary)
                            }

                            // Trust level badge
                            if !profile.trust_level.isEmpty{
                                Text(profile.trust_level.capitalized)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 4)
                                    .background(Color.blue.opacity(0.2))
                                    .foregroundColor(.blue)
                                    .cornerRadius(12)
                            }

                            // Online status
                            HStack {
                                Circle()
                                    .fill(profile.is_online ? Color.green : Color.gray)
                                    .frame(width: 8, height: 8)
                                Text(profile.is_online ? "Online" : "Offline")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding()

                    // Stats section
                    VStack(spacing: 12) {
                        Text("Statistics")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        HStack(spacing: 0) {
                            // Jobs completed
                            VStack(spacing: 4) {
                                Text("\(profile.completed_jobs)")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                Text("Jobs")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)

                            // Rating
                            VStack(spacing: 4) {
                                Text(String(format: "%.1f", profile.avg_rating))
                                    .font(.title2)
                                    .fontWeight(.bold)
                                Text("Rating")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)

                            // Reviews
                            VStack(spacing: 4) {
                                Text("\(profile.review_count)")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                Text("Reviews")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)

                    // Bio section
                    if let bio = profile.bio, !bio.isEmpty {
                        VStack(spacing: 12) {
                            Text("About")
                                .font(.headline)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Text(bio)
                                .font(.body)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal)
                    } else {
                        VStack(spacing: 12) {
                            Text("About")
                                .font(.headline)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Text("No bio available")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal)
                    }

                    Spacer(minLength: 20)
                }
                .padding(.top)
            }
            .navigationTitle("Provider Profile")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Done") {
                dismiss()
            })
        }
        .onAppear {
            print("🎭 SimpleProfileSheet appeared for: \(profile.full_name ?? "Unknown")")
        }
    }
}
