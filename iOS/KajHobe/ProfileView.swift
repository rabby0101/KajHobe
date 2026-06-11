import SwiftUI
import Supabase

nonisolated struct ProfileUpdate: Codable, Sendable {
    let full_name: String
    let bio: String
    let website: String
    let is_service_provider: Bool
    let updated_at: String
    let profession: String?
    let tagline: String?
    let experience_years: Int?
    let hourly_rate: Double?
    let team_rate: Double?
    let team_hours_label: String?
}

private enum ProfileTab: String, CaseIterable {
    case about = "About"
    case details = "Details"
    case account = "Account"
}

struct ProfileView: View {
    @State private var profile: Profile?
    @State private var isLoading = true
    @State private var isEditing = false
    @State private var isSaving = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingLogoutAlert = false
    @ObservedObject private var languageManager = LanguageManager.shared

    @State private var fullName = ""
    @State private var bio = ""
    @State private var website = ""
    @State private var isServiceProvider = false
    @State private var profession = ""
    @State private var tagline = ""
    @State private var experienceYears = ""
    @State private var hourlyRate = ""
    @State private var teamRate = ""
    @State private var teamHoursLabel = ""
    @State private var payoutNumberLoaded = ""
    @State private var payoutBkashNumber = ""

    @State private var selectedTab = ProfileTab.about

    var body: some View {
        NavigationView {
            if isLoading {
                VStack(spacing: 16) {
                    ProgressView().scaleEffect(1.2)
                    Text("Loading profile...").foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let profile = profile {
                ScrollView {
                    VStack(spacing: 20) {
                        heroSection(profile)

                        statCardsRow(profile)

                        tabStrip

                        switch selectedTab {
                        case .about: aboutSection(profile)
                        case .details: detailsSection(profile)
                        case .account: accountSection(profile)
                        }

                        Spacer().frame(height: 40)
                    }
                }
                .navigationTitle("My Profile")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        if isEditing {
                            Button("Cancel") { cancelEditing() }.foregroundStyle(.red)
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        if isEditing {
                            Button { saveProfile() } label: {
                                if isSaving {
                                    ProgressView().scaleEffect(0.8)
                                } else {
                                    Text("Save").fontWeight(.semibold)
                                }
                            }
                            .disabled(isSaving)
                        } else {
                            Button("Edit") { startEditing() }.fontWeight(.semibold)
                        }
                    }
                }
            } else {
                VStack(spacing: 20) {
                    Image(systemName: "person.crop.circle.badge.exclamationmark")
                        .font(.system(size: 60)).foregroundColor(.secondary)
                    Text("No profile found").font(.title2).fontWeight(.semibold)
                    Button("Reload") { loadProfile() }.buttonStyle(.borderedProminent)
                }
            }
        }
        .onAppear { loadProfile() }
        .alert("Error", isPresented: $showingError) { Button("OK") { } } message: { Text(errorMessage) }
        .alert("Logout", isPresented: $showingLogoutAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Logout", role: .destructive) { logout() }
        } message: {
            Text("Are you sure you want to logout? You will need to sign in again to access your account.")
        }
    }

    // MARK: - Hero Section

    @ViewBuilder
    private func heroSection(_ profile: Profile) -> some View {
        let displayName = isEditing ? fullName : (profile.full_name ?? "No name")
        let displayTagline = isEditing ? tagline : (profile.tagline ?? "")
        let profession = profile.profession ?? "User"
        let hourlyLabel: String? = {
            guard let rate = isEditing ? Double(hourlyRate) : profile.hourly_rate, rate > 0 else { return nil }
            return "৳\(formatRate(rate))/hr"
        }()

        ZStack(alignment: .bottomLeading) {
            Rectangle()
                .fill(Color(red: 0.10, green: 0.10, blue: 0.18))

            if let url = profile.avatar_url, let imageURL = URL(string: url) {
                AsyncImage(url: imageURL) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Color.black.opacity(0.3)
                }
                .overlay(
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.65)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
            } else {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.orange.opacity(0.35), .orange.opacity(0.12)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.white.opacity(0.25))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    )
                    .overlay(
                        LinearGradient(
                            colors: [.clear, .black.opacity(0.65)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Image(systemName: "handyman")
                        .font(.system(size: 10)).foregroundColor(.white.opacity(0.7))
                    Text(profession)
                        .font(.caption).foregroundColor(.white.opacity(0.7))
                }

                if isEditing {
                    TextField("Full Name", text: $fullName)
                        .font(.title2.weight(.bold)).foregroundColor(.white)
                        .tint(.orange)
                } else {
                    Text(displayName)
                        .font(.title2.weight(.bold)).foregroundColor(.white)
                        .lineLimit(1)
                }
                Text(profile.email ?? "")
                    .font(.caption).foregroundColor(.white.opacity(0.6))

                if isEditing {
                    TextField("Tagline", text: $tagline)
                        .font(.subheadline).foregroundColor(.white.opacity(0.85))
                        .tint(.orange)
                } else if !displayTagline.isEmpty {
                    Text(displayTagline)
                        .font(.subheadline).foregroundColor(.white.opacity(0.85))
                }

                HStack(spacing: 10) {
                    if let years = isEditing ? Int(experienceYears) : profile.experience_years, years > 0 {
                        Text("\(years) year\(years == 1 ? "" : "s") of experience")
                            .font(.caption2).foregroundColor(.white.opacity(0.85))
                    } else if !isEditing {
                        Text("New provider")
                            .font(.caption2).foregroundColor(.white.opacity(0.85))
                    }
                    if let label = hourlyLabel {
                        Text(label)
                            .font(.caption2).fontWeight(.semibold).foregroundColor(.white)
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(.orange).clipShape(Capsule())
                    }
                }
            }
            .padding(16)
        }
        .frame(height: 280)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal)
    }

    // MARK: - Stat Cards

    @ViewBuilder
    private func statCardsRow(_ profile: Profile) -> some View {
        let completed = profile.completed_jobs ?? 0
        let ratingText: String = {
            let r = profile.average_rating ?? 0
            return r > 0 ? String(format: "%.1f", r) : "New"
        }()
        let reviewCount = profile.ratings_count ?? 0
        let earnedText: String = {
            let e = profile.total_earnings ?? 0
            if e >= 100_000 { return "৳\(Int(e / 1000))K" }
            return "৳\(Int(e))"
        }()

        HStack(spacing: 10) {
            statCard(emoji: "💼", value: "\(completed)", label: "Completed", tint: Color.orange.opacity(0.15))
            statCard(emoji: "⭐", value: ratingText, label: "Rating", tint: Color.purple.opacity(0.15))
            statCard(emoji: "👥", value: "\(reviewCount)", label: "Customers", tint: Color.pink.opacity(0.15))
            statCard(emoji: "💰", value: earnedText, label: "Earned", tint: Color.green.opacity(0.15))
        }
        .padding(.horizontal)
    }

    private func statCard(emoji: String, value: String, label: String, tint: Color) -> some View {
        VStack(spacing: 4) {
            Text(emoji).font(.title3)
            Text(value).font(.title3.weight(.bold))
            Text(label).font(.caption2).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(tint)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Tab Strip

    private var tabStrip: some View {
        HStack(spacing: 0) {
            ForEach(ProfileTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { selectedTab = tab }
                } label: {
                    Text(tab.rawValue)
                        .font(.subheadline.weight(selectedTab == tab ? .semibold : .regular))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            selectedTab == tab
                                ? Color(.systemBackground)
                                : Color.clear
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Color(.systemGray5))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal)
    }

    // MARK: - About Tab

    @ViewBuilder
    private func aboutSection(_ profile: Profile) -> some View {
        VStack(spacing: 16) {
            sectionCard(title: "Bio") {
                if isEditing {
                    TextEditor(text: $bio)
                        .frame(minHeight: 100)
                        .padding(8)
                        .background(Color(.systemGray6)).cornerRadius(8)
                } else {
                    Text(profile.bio ?? "No bio yet")
                        .foregroundColor(profile.bio == nil ? .secondary : .primary)
                }
            }
            sectionCard(title: "Website") {
                if isEditing {
                    TextField("https://...", text: $website)
                        .textFieldStyle(.roundedBorder)
                } else {
                    if let ws = profile.website, !ws.isEmpty {
                        if let url = URL(string: ws) {
                            Link(ws, destination: url).foregroundColor(.orange)
                        } else {
                            Text(ws).font(.body)
                        }
                    } else {
                        Text("No website").foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Details Tab

    @ViewBuilder
    private func detailsSection(_ profile: Profile) -> some View {
        let isProvider = isEditing ? isServiceProvider : (profile.is_service_provider ?? false)

        VStack(spacing: 16) {
            sectionCard(title: "Account Type") {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Service Provider").font(.subheadline.weight(.medium))
                        Text("Enable to apply for jobs and offer services")
                            .font(.caption).foregroundColor(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { isProvider },
                        set: { _ in isServiceProvider.toggle() }
                    ))
                    .disabled(!isEditing)
                    .labelsHidden()
                }
            }

            if isProvider {
                sectionCard(title: "Provider Details") {
                    if isEditing {
                        providerField(title: "Profession", text: $profession, placeholder: "e.g. Electrician")
                        providerField(title: "Tagline", text: $tagline, placeholder: "e.g. Quick & reliable")
                        providerField(title: "Experience (years)", text: $experienceYears, placeholder: "e.g. 8", keyboard: .numberPad)
                        HStack(spacing: 12) {
                            providerField(title: "Hourly fee (৳)", text: $hourlyRate, placeholder: "e.g. 159", keyboard: .decimalPad)
                            providerField(title: "Team fee (৳)", text: $teamRate, placeholder: "e.g. 1059", keyboard: .decimalPad)
                        }
                        providerField(title: "Team hours label", text: $teamHoursLabel, placeholder: "e.g. 4-7 hrs")
                        providerField(title: "Payout bKash (private)", text: $payoutBkashNumber, placeholder: "01XXXXXXXXX", keyboard: .numberPad)
                        Text("Only used to pay you when a deal completes. Never shown to clients.")
                            .font(.caption2).foregroundColor(.secondary)
                    } else {
                        providerReadonlyRow("Profession", profile.profession)
                        providerReadonlyRow("Tagline", profile.tagline)
                        providerReadonlyRow("Experience", profile.experience_years.map { "\($0) year\($0 == 1 ? "" : "s")" })
                        providerReadonlyRow("Hourly fee", profile.hourly_rate.map { "৳\(formatRate($0))" })
                        providerReadonlyRow("Team work fee", profile.team_rate.map { "৳\(formatRate($0))" })
                        providerReadonlyRow("Team hours", profile.team_hours_label)
                        providerReadonlyRow("Payout bKash", payoutNumberLoaded.isEmpty ? nil : payoutNumberLoaded)
                    }
                }
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Account Tab

    @ViewBuilder
    private func accountSection(_ profile: Profile) -> some View {
        VStack(spacing: 16) {
            sectionCard(title: "Account Info") {
                HStack { Image(systemName: "envelope").foregroundColor(.secondary).frame(width: 20); Text(profile.email ?? "No email").font(.subheadline).foregroundColor(.secondary); Spacer() }
                HStack { Image(systemName: "person.badge.plus").foregroundColor(.secondary).frame(width: 20); Text(profile.is_service_provider == true ? "Service Provider" : "Client").font(.subheadline).foregroundColor(.secondary); Spacer() }
            }
            Button {
                let impact = UIImpactFeedbackGenerator(style: .medium)
                impact.impactOccurred()
                showingLogoutAlert = true
            } label: {
                HStack {
                    Image(systemName: "rectangle.portrait.and.arrow.right").foregroundColor(.white)
                    Text("Logout").foregroundColor(.white).fontWeight(.semibold)
                    Spacer()
                }
                .padding()
                .background(Color.red)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal)
    }

    // MARK: - Helpers

    private func sectionCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.subheadline.weight(.semibold))
            content()
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(.systemGray4), lineWidth: 0.5))
    }

    private func providerField(title: String, text: Binding<String>, placeholder: String, keyboard: UIKeyboardType = .default) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundColor(.secondary)
            TextField(placeholder, text: text)
                .keyboardType(keyboard)
                .textFieldStyle(.roundedBorder)
        }
    }

    private func providerReadonlyRow(_ title: String, _ value: String?) -> some View {
        HStack {
            Text(title).font(.subheadline).foregroundColor(.secondary)
            Spacer()
            Text(value?.isEmpty == false ? value! : "—")
                .font(.subheadline)
                .foregroundColor(value?.isEmpty == false ? .primary : .secondary)
        }
    }

    private func formatRate(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", value)
            : String(format: "%.2f", value)
    }

    // MARK: - Load / Edit / Save

    private func loadProfile() {
        isLoading = true
        Task {
            do {
                let user = try supabase.auth.requireCurrentUser()
                let fetched = try await Networking.shared.fetchProfile(userId: user.id.uuidString)
                var fetchedPayout = ""
                if fetched.is_service_provider == true,
                   let n = try? await EscrowNetworking.shared.fetchMyPayoutNumber() {
                    fetchedPayout = n ?? ""
                }
                await MainActor.run {
                    self.profile = fetched
                    self.payoutNumberLoaded = fetchedPayout
                    self.payoutBkashNumber = fetchedPayout
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
        guard let p = profile else { return }
        fullName = p.full_name ?? ""
        bio = p.bio ?? ""
        website = p.website ?? ""
        isServiceProvider = p.is_service_provider ?? false
        profession = p.profession ?? ""
        tagline = p.tagline ?? ""
        experienceYears = p.experience_years.map(String.init) ?? ""
        hourlyRate = p.hourly_rate.map { formatRate($0) } ?? ""
        teamRate = p.team_rate.map { formatRate($0) } ?? ""
        teamHoursLabel = p.team_hours_label ?? ""
        payoutBkashNumber = payoutNumberLoaded
        isEditing = true
    }

    private func cancelEditing() {
        payoutBkashNumber = payoutNumberLoaded
        isEditing = false
    }

    private func saveProfile() {
        guard profile != nil else { return }
        let trimmedPayout = payoutBkashNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalPayout = (isServiceProvider && !trimmedPayout.isEmpty) ? trimmedPayout : nil
        if let payout = finalPayout, payout.range(of: "^01[0-9]{9}$", options: .regularExpression) == nil {
            errorMessage = "Payout bKash number must be 11 digits starting with 01 (e.g. 01712345678)."
            showingError = true
            return
        }

        isSaving = true
        Task {
            do {
                let user = try supabase.auth.requireCurrentUser()

                let trimmedProfession = profession.trimmingCharacters(in: .whitespacesAndNewlines)
                let trimmedTagline = tagline.trimmingCharacters(in: .whitespacesAndNewlines)
                let trimmedTeamHours = teamHoursLabel.trimmingCharacters(in: .whitespacesAndNewlines)
                let parsedExperience = isServiceProvider ? Int(experienceYears.trimmingCharacters(in: .whitespacesAndNewlines)) : nil
                let parsedHourly = isServiceProvider ? Double(hourlyRate.trimmingCharacters(in: .whitespacesAndNewlines)) : nil
                let parsedTeam = isServiceProvider ? Double(teamRate.trimmingCharacters(in: .whitespacesAndNewlines)) : nil
                let finalProfession = (isServiceProvider && !trimmedProfession.isEmpty) ? trimmedProfession : nil
                let finalTagline = (isServiceProvider && !trimmedTagline.isEmpty) ? trimmedTagline : nil
                let finalTeamHours = (isServiceProvider && !trimmedTeamHours.isEmpty) ? trimmedTeamHours : nil

                let updates = ProfileUpdate(
                    full_name: fullName,
                    bio: bio,
                    website: website,
                    is_service_provider: isServiceProvider,
                    updated_at: ISO8601DateFormatter().string(from: Date()),
                    profession: finalProfession,
                    tagline: finalTagline,
                    experience_years: parsedExperience,
                    hourly_rate: parsedHourly,
                    team_rate: parsedTeam,
                    team_hours_label: finalTeamHours
                )

                try await supabase
                    .from("profiles")
                    .update(updates)
                    .eq("id", value: user.id.uuidString)
                    .execute()

                if let payout = finalPayout {
                    try await EscrowNetworking.shared.upsertMyPayoutNumber(payout)
                }

                await MainActor.run {
                    self.profile?.full_name = fullName
                    self.profile?.bio = bio
                    self.profile?.website = website
                    self.profile?.is_service_provider = isServiceProvider
                    self.profile?.profession = finalProfession
                    self.profile?.tagline = finalTagline
                    self.profile?.experience_years = parsedExperience
                    self.profile?.hourly_rate = parsedHourly
                    self.profile?.team_rate = parsedTeam
                    self.profile?.team_hours_label = finalTeamHours
                    self.payoutNumberLoaded = finalPayout ?? self.payoutNumberLoaded
                    self.isEditing = false
                    self.isSaving = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to save profile: \(error.localizedDescription)"
                    self.showingError = true
                    self.isSaving = false
                }
            }
        }
    }

    private func logout() {
        Task {
            do {
                try await supabase.auth.signOut()
                await MainActor.run {
                    NotificationCenter.default.post(name: NSNotification.Name("UserLoggedOut"), object: nil)
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to logout: \(error.localizedDescription)"
                    self.showingError = true
                }
            }
        }
    }
}

#Preview {
    ProfileView()
}

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