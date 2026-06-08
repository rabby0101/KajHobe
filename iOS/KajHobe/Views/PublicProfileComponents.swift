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
/// Tabs on the provider profile, matching the reference mockup.
enum ProviderProfileTab: String, CaseIterable, Identifiable {
    case about = "About"
    case availability = "Availability"
    case experience = "Experience"
    case reviews = "Reviews"
    var id: String { rawValue }
}

struct PublicProfileDetailView: View {
    let profile: PublicProfile

    @State private var serviceHighlights: [ServiceHighlight] = []
    @State private var reviews: [ProviderReview] = []
    @State private var isLoadingHighlights = false
    @State private var isLoadingReviews = false
    @State private var selectedTab: ProviderProfileTab = .about
    @State private var isBioExpanded = false
    @Environment(\.dismiss) private var dismiss

    private let networking = PublicProfileNetworking()

    private let accent = Color(red: 1.0, green: 0.58, blue: 0.0) // warm orange

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    heroHeader
                    statCardsRow
                    tabStrip
                    tabContent
                    pricingRow
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task {
            await loadServiceHighlights()
            await loadReviews()
        }
    }

    // MARK: - Hero

    private var heroHeader: some View {
        ZStack(alignment: .bottomLeading) {
            AsyncImage(url: URL(string: profile.avatar_url ?? "")) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                LinearGradient(
                    colors: [accent.opacity(0.35), accent.opacity(0.12)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                .overlay(
                    Image(systemName: "person.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.white.opacity(0.8))
                )
            }
            .frame(height: 300)
            .frame(maxWidth: .infinity)
            .clipped()

            // Legibility scrim
            LinearGradient(
                colors: [.clear, .black.opacity(0.65)],
                startPoint: .center, endPoint: .bottom
            )
            .frame(height: 300)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "wrench.and.screwdriver.fill")
                        .font(.caption)
                    Text(profile.profession ?? profile.topServiceCategories.first ?? "Service Provider")
                        .font(.subheadline).fontWeight(.medium)
                }
                .foregroundColor(.white.opacity(0.9))

                Text(profile.full_name ?? "Unknown Provider")
                    .font(.title).fontWeight(.bold)
                    .foregroundColor(.white)

                if let tagline = profile.tagline, !tagline.isEmpty {
                    Text(tagline)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.85))
                }

                HStack(spacing: 10) {
                    Text(profile.experienceText)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.85))

                    if let rate = profile.formattedHourlyRate {
                        Text(rate)
                            .font(.caption).fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(Capsule().fill(accent))
                    }
                }
                .padding(.top, 2)
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Stat cards

    private var statCardsRow: some View {
        HStack(spacing: 12) {
            ProviderStatCard(
                emoji: "💼", value: experienceValue, label: "Experience",
                tint: Color.orange.opacity(0.15))
            ProviderStatCard(
                emoji: "⭐️", value: profile.avg_rating > 0 ? profile.formattedRating : "New",
                label: "Rating", tint: Color.purple.opacity(0.15))
            ProviderStatCard(
                emoji: "👥", value: profile.formattedCustomers, label: "Customers",
                tint: Color.pink.opacity(0.15))
        }
    }

    private var experienceValue: String {
        if let years = profile.experience_years, years > 0 {
            return "\(years) yr\(years == 1 ? "" : "s")"
        }
        return "New"
    }

    // MARK: - Tabs

    private var tabStrip: some View {
        HStack(spacing: 0) {
            ForEach(ProviderProfileTab.allCases) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { selectedTab = tab }
                } label: {
                    Text(tab.rawValue)
                        .font(.subheadline)
                        .fontWeight(selectedTab == tab ? .semibold : .regular)
                        .foregroundColor(selectedTab == tab ? .primary : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            selectedTab == tab
                            ? AnyView(RoundedRectangle(cornerRadius: 12).fill(Color(.systemBackground)).shadow(color: .black.opacity(0.08), radius: 3, y: 1))
                            : AnyView(Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(.systemGray6)))
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .about:        aboutTab
        case .availability: availabilityTab
        case .experience:   experienceTab
        case .reviews:      reviewsTab
        }
    }

    private var aboutTab: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("About \(profile.full_name ?? "Provider")")
                .font(.headline)

            let bio = profile.bio?.isEmpty == false ? profile.bio! : "This provider hasn't added a bio yet."
            Text(bio)
                .font(.body)
                .foregroundColor(profile.bio?.isEmpty == false ? .primary : .secondary)
                .lineLimit(isBioExpanded ? nil : 4)
                .lineSpacing(4)

            if let bioText = profile.bio, bioText.count > 160 {
                Button(isBioExpanded ? "Read Less" : "Read More") {
                    withAnimation { isBioExpanded.toggle() }
                }
                .font(.subheadline).fontWeight(.semibold)
                .foregroundColor(accent)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var availabilityTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Circle()
                    .fill(profile.isOnline ? Color.green : Color.gray)
                    .frame(width: 10, height: 10)
                Text(profile.isOnline ? "Online now" : "Last seen \(profile.formattedLastSeen)")
                    .font(.subheadline)
                    .foregroundColor(profile.isOnline ? .green : .secondary)
            }
            HStack {
                Image(systemName: "clock.fill").foregroundColor(.secondary)
                Text("Typically responds in \(profile.responseTimeText)")
                    .font(.subheadline).foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
    }

    private var experienceTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !profile.service_categories.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Service Categories").font(.headline)
                    ServiceCategoryTags(categories: profile.service_categories)
                }
            }
            if isLoadingHighlights {
                ProgressView().frame(maxWidth: .infinity)
            } else if !serviceHighlights.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Specializations").font(.headline)
                    ForEach(serviceHighlights) { highlight in
                        ServiceHighlightCard(highlight: highlight)
                    }
                }
            } else {
                Text("No experience details yet.")
                    .font(.subheadline).foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var reviewsTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            if isLoadingReviews {
                ProgressView().frame(maxWidth: .infinity)
            } else if reviews.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "star.bubble")
                        .font(.largeTitle).foregroundColor(.secondary)
                    Text("No reviews yet")
                        .font(.subheadline).foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                ForEach(reviews) { review in
                    ProviderReviewCard(review: review)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Pricing

    @ViewBuilder
    private var pricingRow: some View {
        if profile.formattedHourlyRate != nil || profile.formattedTeamRate != nil {
            HStack(spacing: 12) {
                if let hourly = profile.formattedHourlyRate {
                    PricingCard(icon: "dollarsign.circle", title: "Hourly Fee",
                                value: hourly, caption: nil)
                }
                if let team = profile.formattedTeamRate {
                    PricingCard(icon: "person.3.fill", title: "Team Work",
                                value: team, caption: profile.team_hours_label)
                }
            }
        }
    }

    // MARK: - Loading

    private func loadServiceHighlights() async {
        isLoadingHighlights = true
        do {
            serviceHighlights = try await networking.fetchServiceHighlights(profile.id)
        } catch {
            print("Failed to load service highlights: \(error)")
        }
        isLoadingHighlights = false
    }

    private func loadReviews() async {
        isLoadingReviews = true
        do {
            reviews = try await networking.fetchReviews(profile.id)
        } catch {
            print("Failed to load reviews: \(error)")
        }
        isLoadingReviews = false
    }
}

// MARK: - Provider profile building blocks

/// Colored stat tile used in the three-up row under the hero.
struct ProviderStatCard: View {
    let emoji: String
    let value: String
    let label: String
    let tint: Color

    var body: some View {
        VStack(spacing: 6) {
            Text(emoji).font(.title3)
            Text(value)
                .font(.headline).fontWeight(.bold)
                .lineLimit(1).minimumScaleFactor(0.7)
            Text(label)
                .font(.caption).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(RoundedRectangle(cornerRadius: 16).fill(tint))
    }
}

/// Hourly / team-work fee card in the pricing row.
struct PricingCard: View {
    let icon: String
    let title: String
    let value: String
    let caption: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon).foregroundColor(.secondary)
                Text(title).font(.subheadline).foregroundColor(.secondary)
            }
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value).font(.title3).fontWeight(.bold)
                if let caption, !caption.isEmpty {
                    Text("(\(caption))").font(.caption).foregroundColor(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(.systemGray6)))
    }
}

/// One review row in the Reviews tab.
struct ProviderReviewCard: View {
    let review: ProviderReview

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                AsyncImage(url: URL(string: review.reviewer_avatar ?? "")) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle().fill(Color.gray.opacity(0.3))
                        .overlay(Image(systemName: "person.fill").foregroundColor(.gray))
                }
                .frame(width: 36, height: 36)
                .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(review.displayName).font(.subheadline).fontWeight(.medium)
                    Text(review.formattedDate).font(.caption2).foregroundColor(.secondary)
                }
                Spacer()
                HStack(spacing: 2) {
                    ForEach(0..<5, id: \.self) { i in
                        Image(systemName: i < review.rating ? "star.fill" : "star")
                            .font(.caption2)
                            .foregroundColor(.yellow)
                    }
                }
            }
            if let comment = review.comment, !comment.isEmpty {
                Text(comment).font(.subheadline).foregroundColor(.primary)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
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
        last_updated: "2024-01-01T12:00:00Z",
        profession: "Professional Repair Man",
        tagline: "Best Electrician",
        experience_years: 8,
        hourly_rate: 159,
        team_rate: 1059,
        team_hours_label: "4-7 hrs"
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