import SwiftUI
import Supabase
import Auth

struct DashboardView: View {
    @State private var dashboardData: DashboardData?
    @State private var activeDeals: [DealWithCompletion] = []
    @State private var isLoading = true
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var selectedDeal: DealWithCompletion?
    @State private var showingProfile = false
    @State private var realtimeChannel: RealtimeChannelV2?
    @State private var isRefreshing = false
    @State private var hasRealtimeUpdate = false
    @State private var refreshTimer: Timer?
    @State private var autoRefreshInterval: TimeInterval = 300 // 5 minutes

    // Analytics & reputation data (feeds charts, reputation card, drill-downs).
    @State private var myDeals: [Deal] = []
    @State private var myReviews: [ProviderReview] = []
    @State private var drillDownFilter: DealsListView.Filter?
    @State private var showingReviewsList = false

    private let reviewNetworking = PublicProfileNetworking()
    
    // MARK: - Main Dashboard Content
    private var dashboardContent: some View {
        ScrollView {
            if isLoading {
                ProgressView("Loading dashboard...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
            } else {
                VStack(spacing: 20) {
                    // Dashboard Stats
                    if let data = dashboardData {
                        dashboardStatsSection(data: data)
                            .animatedContainer(delay: 0.2)
                    } else {
                        // Show empty state if no dashboard data
                        emptyDashboardState()
                            .animatedContainer(delay: 0.3)
                    }
                    
                    // Analytics charts (money flow, status breakdown, rating trend)
                    if let data = dashboardData, !myDeals.isEmpty || !myReviews.isEmpty {
                        DashboardChartsSection(
                            deals: myDeals,
                            reviews: myReviews,
                            userId: currentUserId ?? ""
                        )
                        .animatedContainer(delay: 0.4)

                        // Reputation: trust progress, rating distribution, latest reviews
                        DashboardReputationCard(
                            reviews: myReviews,
                            averageRating: data.average_rating,
                            completedJobs: data.completed_deals_count
                        ) {
                            showingReviewsList = true
                        }
                        .animatedContainer(delay: 0.5)
                    }

                    // Active Deals (read-only overview; tap a card to open Deal Details,
                    // where completion is requested/approved/rejected)
                    if !activeDeals.isEmpty {
                        activeDealsSection()
                            .animatedContainer(delay: 0.6)
                    }

                    // Recent Activity
                    if let data = dashboardData, let recentDeals = data.recent_deals, !recentDeals.isEmpty {
                        recentActivitySection(deals: recentDeals)
                            .animatedContainer(delay: 0.8)
                    }
                }
                .padding()
            }
        }
    }
    
    var body: some View {
        NavigationView {
            dashboardContent
            .background(Color.clear)
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    NavigationLink(destination: NotificationSettingsView()) {
                        Image(systemName: "bell.badge")
                            .font(.title2)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingProfile = true
                    }) {
                        Image(systemName: "person.circle")
                            .font(.title2)
                    }
                }
            }
            .refreshable {
                // Add haptic feedback for pull-to-refresh
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
                
                await loadDashboardData(forceRefresh: true)
            }
        }
        .onAppear {
            Task {
                // Seed instantly from cache (memory → disk) so the dashboard paints
                // on the first frame instead of a spinner — the fetch below then
                // refreshes silently in the background.
                if dashboardData == nil,
                   let uid = supabase.auth.currentUser?.id.uuidString {
                    if let cached = DashboardCache.shared.peek(userId: uid) {
                        dashboardData = cached.dashboard
                        activeDeals = cached.activeDeals
                        isLoading = false
                    } else if let disk = await DashboardCache.shared.load(userId: uid) {
                        dashboardData = disk.dashboard
                        activeDeals = disk.activeDeals
                        isLoading = false
                    }
                }
                await loadDashboardData()
                await setupRealtimeSubscription()
                startAutoRefreshTimer()
            }
        }
        .onDisappear {
            // Don't cleanup real-time subscription on disappear to keep it alive
            stopAutoRefreshTimer()
            // print("📊 Dashboard disappeared - keeping real-time active")
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            // Refresh when app comes back to foreground
            Task {
                // print("📊 App entered foreground - refreshing dashboard")
                await loadDashboardData(forceRefresh: true)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshDashboard"))) { _ in
            // Refresh when dashboard tab becomes active
            Task {
                // print("📊 Dashboard tab became active - refreshing data")
                await loadDashboardData(forceRefresh: true)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("DealUpdated"))) { _ in
            // Refresh when deals are updated from other parts of the app
            Task {
                // print("📊 Deal updated notification received - refreshing dashboard")
                await loadDashboardData(forceRefresh: true)
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .sheet(item: $selectedDeal) { deal in
            DealDetailView(deal: deal)
        }
        .sheet(isPresented: $showingProfile) {
            ProfileView()
        }
        .sheet(item: $drillDownFilter) { filter in
            DealsListView(deals: myDeals, filter: filter)
        }
        .sheet(isPresented: $showingReviewsList) {
            ReviewsListView(reviews: myReviews)
        }
    }

    private var currentUserId: String? {
        supabase.auth.currentUser?.id.uuidString
    }
    
    @ViewBuilder
    private func emptyDashboardState() -> some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(.blue)
                Text("Overview")
                    .font(.headline)
                Spacer()
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                StatCard(
                    title: "Active Deals",
                    value: "0",
                    icon: "briefcase.fill",
                    color: .blue
                )
                
                StatCard(
                    title: "Completed",
                    value: "0",
                    icon: "checkmark.circle.fill",
                    color: .green
                )
                
                StatCard(
                    title: "Earnings",
                    value: "$0",
                    icon: "dollarsign.circle.fill",
                    color: .orange
                )
                
                StatCard(
                    title: "Rating",
                    value: "4.5",
                    icon: "star.fill",
                    color: .yellow
                )
            }
            
            // Add helpful call-to-action for empty dashboard
            VStack(spacing: 12) {
                Text("Get started with your first job")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                VStack(spacing: 8) {
                    NavigationLink(destination: JobsListView()) {
                        HStack {
                            Image(systemName: "briefcase")
                            Text("Browse Available Jobs")
                        }
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .cornerRadius(12)
                    }
                    
                    NavigationLink(destination: PostJobView()) {
                        HStack {
                            Image(systemName: "plus")
                            Text("Post a Job")
                        }
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(12)
                    }
                }
            }
            .padding(.top, 16)
        }
        .padding()
        .background(CardBackground())
        .cornerRadius(12)
    }
    
    @ViewBuilder
    private func dashboardStatsSection(data: DashboardData) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(.blue)
                Text("Overview")
                    .font(.headline)
                Spacer()
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                StatCard(
                    title: "Active Deals",
                    value: "\(data.active_deals_count)",
                    icon: "briefcase.fill",
                    color: .blue
                ) {
                    drillDownFilter = .active
                }

                StatCard(
                    title: "Completed",
                    value: "\(data.completed_deals_count)",
                    icon: "checkmark.circle.fill",
                    color: .green
                ) {
                    drillDownFilter = .completed
                }

                StatCard(
                    title: data.user_type == "provider" ? "Total Earned" : "Total Spent",
                    value: "$\(Int(data.user_type == "provider" ? data.total_earnings : data.total_spent))",
                    icon: data.user_type == "provider" ? "dollarsign.circle.fill" : "creditcard.fill",
                    color: .orange
                ) {
                    drillDownFilter = .completed
                }

                StatCard(
                    title: "Rating",
                    value: String(format: "%.1f", data.average_rating),
                    icon: "star.fill",
                    color: .yellow
                ) {
                    showingReviewsList = true
                }
            }
        }
        .padding()
        .background(CardBackground())
        .cornerRadius(12)
    }
    
    @ViewBuilder
    private func activeDealsSection() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "briefcase.fill")
                    .foregroundColor(.blue)
                Text("Active Deals")
                    .font(.headline)
                Spacer()
            }
            
            ForEach(activeDeals, id: \.id) { deal in
                ActiveDealCard(deal: deal) {
                    selectedDeal = deal
                }
            }
        }
        .padding()
        .background(CardBackground())
        .cornerRadius(12)
    }
    
    @ViewBuilder
    private func recentActivitySection(deals: [DashboardDeal]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "clock.fill")
                    .foregroundColor(.purple)
                Text("Recent Activity")
                    .font(.headline)
                Spacer()
            }
            
            ForEach(deals, id: \.id) { deal in
                RecentDealCard(deal: deal) {
                    // Resolve the summary row to a full deal for the detail view.
                    if let fullDeal = myDeals.first(where: { $0.id == deal.id }) {
                        selectedDeal = DealWithCompletion(from: fullDeal)
                    } else if let active = activeDeals.first(where: { $0.id == deal.id }) {
                        selectedDeal = active
                    }
                }
            }
        }
        .padding()
        .background(CardBackground())
        .cornerRadius(12)
    }
    
    private func loadDashboardData(forceRefresh: Bool = false) async {
        // For real-time updates, we don't need to prevent concurrent loads
        // Allow immediate updates for responsive UI
        
        // Only show loading for initial load, not for real-time updates
        await MainActor.run {
            if dashboardData == nil {
                isLoading = true
            } else if forceRefresh {
                isRefreshing = true
            }
        }
        
        do {
            print("📊 Starting dashboard data fetch...")
            async let dashboardDataFetch = Networking.shared.fetchDashboardData(forceRefresh: forceRefresh)
            async let activeDealsDataFetch = Networking.shared.fetchActiveDeals(forceRefresh: forceRefresh)

            let (dashboard, deals) = try await (dashboardDataFetch, activeDealsDataFetch)

            // Analytics data (charts, reputation, drill-downs) loads alongside but
            // never fails the dashboard — charts just show their empty states.
            await loadAnalyticsData()

            print("📊 Dashboard data received - Active deals: \(dashboard.active_deals_count), Completed: \(dashboard.completed_deals_count)")
            print("📊 Fetched \(deals.count) active deals")

            // Convert Deal to DealWithCompletion and remove duplicates (done outside
            // the MainActor block so the converted array can also be persisted below).
            let convertedDeals = deals.map(DealWithCompletion.init(from:)).uniqued(by: \.id)

            await MainActor.run {
                // Add smooth animation for real-time updates
                withAnimation(.easeInOut(duration: 0.3)) {
                    self.dashboardData = dashboard
                    self.activeDeals = convertedDeals
                }
                self.isLoading = false
                self.isRefreshing = false

                // Persist for instant paint on the next visit / cold start.
                if let uid = supabase.auth.currentUser?.id.uuidString {
                    DashboardCache.shared.save(
                        DashboardSnapshot(dashboard: dashboard, activeDeals: convertedDeals),
                        userId: uid
                    )
                }
            }

            print("📊 Dashboard data refreshed successfully")
        } catch {
            print("❌ Dashboard data refresh failed: \(error)")
            await MainActor.run {
                self.errorMessage = "Failed to load dashboard data: \(error.localizedDescription)"
                self.showingError = true
                self.isLoading = false
                self.isRefreshing = false
            }
        }
    }
    
    /// Fetch the full deal list and the user's received reviews for the
    /// analytics + reputation sections. Best-effort: failures leave the
    /// previous data in place and never surface an error alert.
    private func loadAnalyticsData() async {
        guard let userId = currentUserId else { return }

        async let dealsFetch = try? Networking.shared.fetchMyDeals()
        async let reviewsFetch = try? reviewNetworking.fetchReviews(userId.lowercased())
        let (deals, reviews) = await (dealsFetch, reviewsFetch)

        await MainActor.run {
            withAnimation(.easeInOut(duration: 0.3)) {
                if let deals { self.myDeals = deals }
                if let reviews { self.myReviews = reviews }
            }
        }
    }

    // MARK: - Real-time Functions

    private func setupRealtimeSubscription() async {
        // Clean up any existing subscription first
        await cleanupRealtimeSubscription()
        
        do {
            let user = try supabase.auth.requireCurrentUser()
            
            // print("📊 Setting up real-time subscription for dashboard")
            
            // Create a channel for this user's deals with unique identifier
            let channelId = "dashboard:\(user.id):\(Date().timeIntervalSince1970)"
            let channel = supabase.realtimeV2.channel(channelId)
            
            // Listen for deal changes (INSERT, UPDATE, DELETE)
            _ = channel.onPostgresChange(
                AnyAction.self,
                schema: "public",
                table: "deals"
            ) { action in
                Task { @MainActor in
                    // print("📊 Real-time deal update received: \(action)")
                    
                    // Add haptic feedback for real-time updates
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                    
                    // Show visual indicator
                    withAnimation(.easeInOut(duration: 0.5)) {
                        self.hasRealtimeUpdate = true
                    }
                    
                    await self.loadDashboardData(forceRefresh: true)
                    
                    // Hide indicator after a short delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            self.hasRealtimeUpdate = false
                        }
                    }
                }
            }
            
            // Listen for completion request changes
            _ = channel.onPostgresChange(
                AnyAction.self,
                schema: "public",
                table: "deal_completion_requests"
            ) { action in
                Task { @MainActor in
                    // print("📊 Real-time completion request update received: \(action)")
                    
                    // Add haptic feedback
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.impactOccurred()
                    
                    await self.loadDashboardData(forceRefresh: true)
                }
            }
            
            // Listen for deal offer changes (for new offers coming in)
            _ = channel.onPostgresChange(
                AnyAction.self,
                schema: "public",
                table: "deal_offers"
            ) { action in
                Task { @MainActor in
                    // print("📊 Real-time deal offer update received: \(action)")
                    
                    // Add stronger haptic feedback for new offers
                    let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
                    impactFeedback.impactOccurred()
                    
                    await self.loadDashboardData(forceRefresh: true)
                }
            }
            
            // Listen for job status changes (in case jobs get completed)
            _ = channel.onPostgresChange(
                AnyAction.self,
                schema: "public",
                table: "jobs"
            ) { action in
                Task { @MainActor in
                    // print("📊 Real-time job update received: \(action)")
                    await self.loadDashboardData(forceRefresh: true)
                }
            }
            
            // Subscribe to the channel
            await channel.subscribe()
            
            // Store the channel for cleanup
            await MainActor.run {
                self.realtimeChannel = channel
            }
            
            // print("✅ Real-time dashboard subscription setup complete")
        } catch {
            // print("❌ Error setting up real-time dashboard: \(error)")
        }
    }
    
    private func cleanupRealtimeSubscription() async {
        // print("📊 Cleaning up real-time dashboard subscription")
        
        if let channel = realtimeChannel {
            await channel.unsubscribe()
            await MainActor.run {
                self.realtimeChannel = nil
            }
        }
    }
    
    // MARK: - Auto-Refresh Timer Functions
    
    private func startAutoRefreshTimer() {
        stopAutoRefreshTimer() // Stop any existing timer
        
        refreshTimer = Timer.scheduledTimer(withTimeInterval: autoRefreshInterval, repeats: true) { _ in
            Task {
                // print("📊 Auto-refreshing dashboard data...")
                await loadDashboardData(forceRefresh: true)
                
                // Also check and reconnect real-time subscription if needed
                await ensureRealtimeConnection()
            }
        }
        
        // print("📊 Auto-refresh timer started (interval: \(autoRefreshInterval)s)")
    }
    
    private func ensureRealtimeConnection() async {
        // Check if real-time subscription is still active
        if realtimeChannel == nil {
            // print("📊 Real-time connection lost, reconnecting...")
            await setupRealtimeSubscription()
        }
    }
    
    private func stopAutoRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        // print("📊 Auto-refresh timer stopped")
    }
    
}

// MARK: - Supporting Views

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    /// When set, the card is tappable and drills into a detail list.
    var onTap: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Spacer()
                if onTap != nil {
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Text(value)
                .font(.title2)
                .fontWeight(.bold)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.tertiarySystemGroupedBackground))
        .cornerRadius(8)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap?()
        }
    }
}

struct ActiveDealCard: View {
    let deal: DealWithCompletion
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(deal.job?.title ?? "Unknown Job")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                Spacer()
                Text("$\(deal.agreed_amount)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.green)
            }
            
            HStack {
                Text("with \(deal.client_profile?.full_name ?? deal.provider_profile?.full_name ?? "Unknown")")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                
                HStack(spacing: 4) {
                    Circle()
                        .fill(statusColor(deal.completion_status))
                        .frame(width: 8, height: 8)
                    Text(deal.completion_status.replacingOccurrences(of: "_", with: " ").capitalized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(CardBackground(opacity: 0.15))
        .cornerRadius(8)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(AnimationSystem.Presets.scaleIn) {
                onTap()
            }
        }
    }

    private func statusColor(_ status: String) -> Color {
        switch status {
        case "completed":
            return .green
        case "in_progress":
            return .blue
        case "pending_approval":
            return .orange
        default:
            return .gray
        }
    }
}

struct RecentDealCard: View {
    let deal: DashboardDeal
    /// When set, tapping the card opens the deal's detail view.
    var onTap: (() -> Void)? = nil

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(deal.job_title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("with \(deal.other_party_name ?? "Unknown")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("$\(deal.agreed_amount)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.green)
                
                HStack(spacing: 4) {
                    Circle()
                        .fill(statusColor(deal.completion_status))
                        .frame(width: 6, height: 6)
                    Text(deal.completion_status.replacingOccurrences(of: "_", with: " ").capitalized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if onTap != nil {
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.tertiarySystemGroupedBackground))
        .cornerRadius(8)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap?()
        }
    }

    private func statusColor(_ status: String) -> Color {
        switch status {
        case "completed":
            return .green
        case "in_progress":
            return .blue
        case "pending_approval":
            return .orange
        default:
            return .gray
        }
    }
}

// Preview removed due to iOS 26 beta compilation issues

// MARK: - Array Extension for Removing Duplicates
extension Array {
    func uniqued<T: Hashable>(by keyPath: KeyPath<Element, T>) -> [Element] {
        var seen: Set<T> = []
        return filter { seen.insert($0[keyPath: keyPath]).inserted }
    }
}