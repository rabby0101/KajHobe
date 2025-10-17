import SwiftUI

// MARK: - Public Profile Card Components

/// Compact profile card for interest request notifications
/// Shows essential provider info in a notification context
struct PublicProfileCard: View {
    let profile: PublicProfile
    let showFullDetails: Bool
    let onTap: () -> Void

    init(profile: PublicProfile, showFullDetails: Bool = false, onTap: @escaping () -> Void = {}) {
        self.profile = profile
        self.showFullDetails = showFullDetails
        self.onTap = onTap
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // Header with avatar and basic info
                HStack(spacing: 12) {
                    // Profile avatar with online indicator
                    ZStack(alignment: .bottomTrailing) {
                        AsyncImage(url: URL(string: profile.avatar_url ?? "")) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Circle()
                                .fill(Color.gray.opacity(0.3))
                                .overlay(
                                    Image(systemName: "person.fill")
                                        .foregroundColor(.gray)
                                )
                        }
                        .frame(width: 50, height: 50)
                        .clipShape(Circle())

                        // Online indicator
                        if profile.isOnline {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 14, height: 14)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white, lineWidth: 2)
                                )
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        // Name and trust badge
                        HStack(spacing: 8) {
                            Text(profile.full_name ?? "Unknown Provider")
                                .font(.headline)
                                .foregroundColor(.primary)

                            TrustBadge(trustLevel: profile.trustLevelEnum)
                        }

                        // Location and online status
                        HStack(spacing: 4) {
                            if let location = profile.location {
                                HStack(spacing: 2) {
                                    Image(systemName: "location.circle.fill")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(location)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }

                            if profile.isOnline {
                                Text("• Online")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            } else {
                                Text("• \(profile.formattedLastSeen)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    Spacer()

                    // Rating and job count
                    VStack(alignment: .trailing, spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .font(.caption)
                                .foregroundColor(.yellow)
                            Text(profile.formattedRating)
                                .font(.caption)
                                .fontWeight(.medium)
                        }

                        Text(profile.formattedJobCount)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                if showFullDetails {
                    // Additional details section
                    VStack(alignment: .leading, spacing: 8) {
                        // Bio
                        if let bio = profile.bio, !bio.isEmpty {
                            Text(bio)
                                .font(.body)
                                .lineLimit(3)
                                .foregroundColor(.secondary)
                        }

                        // Service categories
                        if !profile.topServiceCategories.isEmpty {
                            ServiceCategoryTags(categories: profile.topServiceCategories)
                        }

                        // Statistics row
                        HStack(spacing: 20) {
                            ProfileStatItem(
                                icon: "briefcase.fill",
                                label: "Jobs",
                                value: "\(profile.completed_jobs)"
                            )

                            ProfileStatItem(
                                icon: "star.fill",
                                label: "Rating",
                                value: profile.formattedRating
                            )

                            ProfileStatItem(
                                icon: "clock.fill",
                                label: "Response",
                                value: profile.responseTimeText
                            )

                            Spacer()
                        }
                    }
                }
            }
            .padding(16)
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

/// Minimal profile summary card for list views
struct PublicProfileSummaryCard: View {
    let summary: PublicProfileSummary
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Avatar with online indicator
                ZStack(alignment: .bottomTrailing) {
                    AsyncImage(url: URL(string: summary.avatar_url ?? "")) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .overlay(
                                Image(systemName: "person.fill")
                                    .foregroundColor(.gray)
                            )
                    }
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())

                    if summary.isOnline {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 10, height: 10)
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: 1)
                            )
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(summary.full_name ?? "Unknown Provider")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    HStack(spacing: 8) {
                        TrustBadge(trustLevel: summary.trustLevelEnum, compact: true)

                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .font(.caption2)
                                .foregroundColor(.yellow)
                            Text(summary.shortRating)
                                .font(.caption)
                        }

                        Text("• \(summary.completed_jobs) jobs")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

/// Detailed public profile view for full-screen presentation
struct PublicProfileDetailView: View {
    let profile: PublicProfile
    @State private var serviceHighlights: [ServiceHighlight] = []
    @State private var isLoadingHighlights = false
    @Environment(\.dismiss) private var dismiss

    private let networking = PublicProfileNetworking()

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Hero section
                    ProfileHeroSection(profile: profile)

                    // Statistics section
                    ProfileStatisticsSection(profile: profile)

                    // Bio section
                    if let bio = profile.bio, !bio.isEmpty {
                        ProfileBioSection(bio: bio)
                    }

                    // Service categories
                    if !profile.service_categories.isEmpty {
                        ProfileServiceCategoriesSection(categories: profile.service_categories)
                    }

                    // Service highlights
                    if !serviceHighlights.isEmpty {
                        ProfileServiceHighlightsSection(highlights: serviceHighlights)
                    }

                    // Activity section
                    ProfileActivitySection(profile: profile)

                    Spacer(minLength: 50)
                }
                .padding(.horizontal, 16)
            }
            .navigationTitle("Provider Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .task {
            await loadServiceHighlights()
        }
    }

    private func loadServiceHighlights() async {
        isLoadingHighlights = true
        do {
            serviceHighlights = try await networking.fetchServiceHighlights(profile.id)
        } catch {
            print("Failed to load service highlights: \(error)")
        }
        isLoadingHighlights = false
    }
}

// MARK: - Supporting Components

/// Trust level badge with color coding
struct TrustBadge: View {
    let trustLevel: TrustLevel
    let compact: Bool

    init(trustLevel: TrustLevel, compact: Bool = false) {
        self.trustLevel = trustLevel
        self.compact = compact
    }

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: trustLevel.icon)
                .font(compact ? .caption2 : .caption)

            if !compact {
                Text(trustLevel.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
            }
        }
        .foregroundColor(colorForTrustLevel)
        .padding(.horizontal, compact ? 4 : 6)
        .padding(.vertical, compact ? 2 : 3)
        .background(colorForTrustLevel.opacity(0.1))
        .cornerRadius(compact ? 4 : 6)
    }

    private var colorForTrustLevel: Color {
        switch trustLevel {
        case .unverified: return .gray
        case .newcomer: return .blue
        case .established: return .green
        case .experienced: return .orange
        case .expert: return .purple
        }
    }
}

/// Service category tags display
struct ServiceCategoryTags: View {
    let categories: [String]

    var body: some View {
        LazyHGrid(rows: [GridItem(.adaptive(minimum: 30))], spacing: 8) {
            ForEach(categories, id: \.self) { category in
                Text(category)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(12)
            }
        }
    }
}

/// Statistics item for profile details
struct ProfileStatItem: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.blue)

            Text(value)
                .font(.caption)
                .fontWeight(.semibold)

            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Profile Detail Sections

struct ProfileHeroSection: View {
    let profile: PublicProfile

    var body: some View {
        VStack(spacing: 16) {
            // Large avatar with online indicator
            ZStack(alignment: .bottomTrailing) {
                AsyncImage(url: URL(string: profile.avatar_url ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.largeTitle)
                                .foregroundColor(.gray)
                        )
                }
                .frame(width: 100, height: 100)
                .clipShape(Circle())

                if profile.isOnline {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 20, height: 20)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 3)
                        )
                }
            }

            VStack(spacing: 8) {
                Text(profile.full_name ?? "Unknown Provider")
                    .font(.title2)
                    .fontWeight(.bold)

                TrustBadge(trustLevel: profile.trustLevelEnum)

                if let location = profile.location {
                    HStack(spacing: 4) {
                        Image(systemName: "location.circle.fill")
                            .foregroundColor(.secondary)
                        Text(location)
                            .foregroundColor(.secondary)
                    }
                    .font(.subheadline)
                }

                Text(profile.isOnline ? "Online now" : "Last seen \(profile.formattedLastSeen)")
                    .font(.caption)
                    .foregroundColor(profile.isOnline ? .green : .secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
}

struct ProfileStatisticsSection: View {
    let profile: PublicProfile

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Statistics")
                .font(.headline)

            HStack(spacing: 20) {
                ProfileStatItem(
                    icon: "briefcase.fill",
                    label: "Completed Jobs",
                    value: "\(profile.completed_jobs)"
                )

                ProfileStatItem(
                    icon: "star.fill",
                    label: "Average Rating",
                    value: profile.formattedRating
                )

                ProfileStatItem(
                    icon: "banknote.fill",
                    label: "Total Earnings",
                    value: profile.formattedEarnings
                )

                ProfileStatItem(
                    icon: "clock.fill",
                    label: "Response Time",
                    value: profile.responseTimeText
                )

                Spacer()
            }
        }
        .padding(16)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct ProfileBioSection: View {
    let bio: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("About")
                .font(.headline)

            Text(bio)
                .font(.body)
                .lineSpacing(4)
        }
    }
}

struct ProfileServiceCategoriesSection: View {
    let categories: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Service Categories")
                .font(.headline)

            ServiceCategoryTags(categories: categories)
        }
    }
}

struct ProfileServiceHighlightsSection: View {
    let highlights: [ServiceHighlight]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Service Highlights")
                .font(.headline)

            ForEach(highlights) { highlight in
                ServiceHighlightCard(highlight: highlight)
            }
        }
    }
}

struct ServiceHighlightCard: View {
    let highlight: ServiceHighlight

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(highlight.category)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(highlight.formattedJobCount)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(highlight.formattedRating)
                    .font(.caption)
                    .fontWeight(.medium)

                Text(highlight.formattedRecentCompletion)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
    }
}

struct ProfileActivitySection: View {
    let profile: PublicProfile

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Activity")
                .font(.headline)

            VStack(spacing: 8) {
                HStack {
                    Text("Member since")
                    Spacer()
                    Text(formattedMemberSince)
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("Profile last updated")
                    Spacer()
                    Text(formattedLastUpdated)
                        .foregroundColor(.secondary)
                }

                if profile.hasExperience {
                    HStack {
                        Text("Experience level")
                        Spacer()
                        Text(profile.trustLevelEnum.displayName)
                            .foregroundColor(.blue)
                    }
                }
            }
            .font(.subheadline)
        }
        .padding(16)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private var formattedMemberSince: String {
        guard let createdAt = profile.created_at else { return "Unknown" }
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: createdAt) else { return "Unknown" }
        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "MMM yyyy"
        return monthFormatter.string(from: date)
    }

    private var formattedLastUpdated: String {
        guard let lastUpdated = profile.last_updated else { return "Unknown" }
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: lastUpdated) else { return "Unknown" }
        let now = Date()
        let interval = now.timeIntervalSince(date)
        let days = Int(interval / 86400)

        if days == 0 {
            return "Today"
        } else if days == 1 {
            return "Yesterday"
        } else if days < 7 {
            return "\(days) days ago"
        } else {
            return "Over a week ago"
        }
    }
}

// MARK: - Preview Support
#if DEBUG
struct PublicProfileComponents_Previews: PreviewProvider {
    static var sampleProfile = PublicProfile(
        id: "123",
        full_name: "John Doe",
        avatar_url: nil,
        bio: "Experienced handyman with 5+ years of experience in home repairs and maintenance.",
        location: "Khulna, Bangladesh",
        website: "https://johndoe.com",
        is_service_provider: true,
        created_at: "2023-01-01T00:00:00Z",
        completed_jobs: 25,
        avg_job_value: 1500.0,
        total_earnings: 37500.0,
        avg_rating: 4.8,
        review_count: 23,
        is_online: true,
        last_seen_at: "2024-01-01T12:00:00Z",
        average_response_time_minutes: 30,
        service_categories: ["Home Repair", "Plumbing", "Electrical"],
        trust_level: "experienced",
        last_updated: "2024-01-01T12:00:00Z"
    )

    static var previews: some View {
        Group {
            PublicProfileCard(profile: sampleProfile, showFullDetails: true) {}
                .previewDisplayName("Profile Card - Full")

            PublicProfileCard(profile: sampleProfile, showFullDetails: false) {}
                .previewDisplayName("Profile Card - Compact")

            PublicProfileDetailView(profile: sampleProfile)
                .previewDisplayName("Profile Detail View")
        }
        .previewLayout(.sizeThatFits)
        .padding()
    }
}
#endif