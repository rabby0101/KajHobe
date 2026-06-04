import SwiftUI
import Supabase
import Realtime

struct JobsListView: View {
    @State private var jobs: [Job] = []
    @State private var isLoading = false
    @State private var error: Error?
    @State private var searchText = ""
    @State private var selectedCategory: String? = nil
    @State private var showingAllCategories = false
    @State private var showingEnhancedSearch = false
    @State private var categorySheetToShow: String? = nil
    @State private var realtimeChannel: RealtimeChannelV2?
    @State private var userLocation = "Khulna"
    @State private var userProfile: Profile?
    @State private var showingFavoriteCategoriesSelector = false
    @State private var showingSearchSheet = false
    
    // Use hardcoded categories for better performance
    private let serviceCategories = HardcodedServiceCategory.categories
    
    // Premium theme manager (temporarily disabled)
    // @StateObject private var themeManager = ThemeManager.shared
    
    var filteredJobs: [Job] {
        var filtered = jobs
        
        // Filter by search text
        if !searchText.isEmpty {
            filtered = filtered.filter { job in
                job.title.localizedCaseInsensitiveContains(searchText) ||
                job.description.localizedCaseInsensitiveContains(searchText) ||
                job.category.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Filter by category
        if let selectedCategory = selectedCategory {
            filtered = filtered.filter { 
                $0.category.localizedCaseInsensitiveContains(selectedCategory)
            }
        }
        
        return filtered
    }
    
    // Smart job categorization
    var jobsNearYou: [Job] {
        return jobs.filter { job in
            job.status == "open" && 
            (job.location.localizedCaseInsensitiveContains(userLocation) ||
             job.location.localizedCaseInsensitiveContains("Khulna"))
        }.prefix(6).map { $0 }
    }
    
    var featuredJobs: [Job] {
        return jobs.filter { job in
            job.status == "open" && 
            (job.urgent == true || job.budget >= 5000)
        }
        .sorted { job1, job2 in
            if (job1.urgent ?? false) && !(job2.urgent ?? false) { return true }
            if !(job1.urgent ?? false) && (job2.urgent ?? false) { return false }
            return job1.budget > job2.budget
        }
        .prefix(6).map { $0 }
    }
    
    var recentJobs: [Job] {
        return jobs.filter { $0.status == "open" }
            .sorted { ($0.created_at ?? "") > ($1.created_at ?? "") }
            .prefix(6).map { $0 }
    }
    
    // Get filtered jobs for the selected category sheet
    var categorySheetJobs: [Job] {
        guard let categorySheetToShow = categorySheetToShow else { return jobs }
        return jobs.filter { $0.category.localizedCaseInsensitiveContains(categorySheetToShow) }
    }
    
    // Get the first 4 categories for horizontal scroll
    var displayCategories: [HardcodedServiceCategory] {
        return Array(serviceCategories.prefix(4))
    }
    
    // Get favorite categories from user profile
    var favoriteCategories: [HardcodedServiceCategory] {
        guard let profile = userProfile, 
              let favCategories = profile.favorite_categories,
              !favCategories.isEmpty else {
            return Array(serviceCategories.prefix(4)) // Default first 4 categories
        }
        
        return favCategories.compactMap { categoryName in
            serviceCategories.first { $0.name == categoryName }
        }
    }
    
    // Get jobs for favorite categories
    var favoriteJobsForCategories: [Job] {
        let categoryNames = favoriteCategories.map { $0.name }
        return jobs.filter { job in
            job.status == "open" && categoryNames.contains { categoryName in
                job.category.localizedCaseInsensitiveContains(categoryName)
            }
        }.prefix(8).map { $0 }
    }
    
    // Home button view
    private var homeButton: some View {
        Button(action: {
            selectedCategory = nil
        }) {
            Image(systemName: "house.fill")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(categorySheetToShow == nil ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(categorySheetToShow == nil ? Color.blue : Color(.systemGray6))
                .cornerRadius(20)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // Show all categories button
    private var showAllButton: some View {
        Button(action: {
            categorySheetToShow = nil
            showingAllCategories = true
        }) {
            HStack(spacing: 4) {
                Text("Show All")
                Image(systemName: "chevron.down")
                    .font(.caption)
            }
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundColor(.blue)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(20)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Premium Homepage Sections
    
    // Favorite Categories Section
    private var favoriteCategoriesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your Favorite Categories")
                        .font(.title2)
                        .foregroundColor(.primary)
                    
                    Text("Quick access to your preferred services")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("Edit") {
                    showingFavoriteCategoriesSelector = true
                }
                .font(.subheadline)
                .foregroundColor(.blue)
            }
            .padding(.horizontal, 24)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(favoriteCategories) { category in
                    VStack(spacing: 8) {
                        Text(category.icon)
                            .font(.system(size: 24))
                        
                        Text(category.name)
                            .font(.caption)
                            .fontWeight(.medium)
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                            .foregroundColor(.primary)
                        
                        Text("\(getJobCount(for: category.name)) jobs")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, minHeight: 100, maxHeight: 100)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .onTapGesture {
                        categorySheetToShow = category.name
                        showingAllCategories = true
                    }
                }
            }
            .padding(.horizontal, 24)
        }
    }
    
    
    // Jobs Near You Section (Carousel Style)
    private var jobsNearYouSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Jobs Near You")
                        .font(.title2)
                        .foregroundColor(.primary)
                    
                    Text("Opportunities in your area")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                NavigationLink("View All", destination: AllJobsView(jobs: Array(jobsNearYou), onJobDeleted: {
                    Task { await loadJobs() }
                }))
                .font(.subheadline)
                .foregroundColor(.blue)
            }
            .padding(.horizontal, 24)
            
            // Horizontal carousel instead of grid
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(jobsNearYou.prefix(6)) { job in
                        JobCardView(
                            job: job,
                            onJobDeleted: { Task { await loadJobs() } }
                        )
                        .frame(width: 280)
                    }
                }
                .padding(.horizontal, 24)
            }
        }
    }
    
    // Featured Jobs Section
    private var featuredJobsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Featured Jobs")
                        .font(.title2)
                        .foregroundColor(.primary)
                    
                    Text("High-value and urgent opportunities")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                NavigationLink("View All", destination: AllJobsView(jobs: Array(featuredJobs), onJobDeleted: {
                    Task { await loadJobs() }
                }))
                .font(.subheadline)
                .foregroundColor(.blue)
            }
            .padding(.horizontal, 24)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(featuredJobs.prefix(4)) { job in
                        JobCardView(
                            job: job,
                            onJobDeleted: { Task { await loadJobs() } }
                        )
                        .frame(width: 320)
                    }
                }
                .padding(.horizontal, 24)
            }
        }
    }
    
    // Recently Posted Jobs Section
    private var recentJobsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Recently Posted Jobs")
                        .font(.title2)
                        .foregroundColor(.primary)
                    
                    Text("Latest opportunities")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                NavigationLink("View All", destination: AllJobsView(jobs: Array(recentJobs), onJobDeleted: {
                    Task { await loadJobs() }
                }))
                .font(.subheadline)
                .foregroundColor(.blue)
            }
            .padding(.horizontal, 24)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(recentJobs) { job in
                        JobCardView(
                            job: job,
                            onJobDeleted: { Task { await loadJobs() } }
                        )
                        .frame(width: 300)
                    }
                }
                .padding(.horizontal, 24)
            }
        }
    }
    
    // Search Results Section
    private var searchResultsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Search Results")
                    .font(.title2)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(filteredJobs.count) jobs")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 24)
            
            LazyVStack(spacing: 16) {
                ForEach(filteredJobs) { job in
                    JobCardView(
                        job: job,
                        onJobDeleted: { Task { await loadJobs() } }
                    )
                }
            }
            .padding(.horizontal, 24)
        }
        .padding(.top, 24)
    }
    
    // Categories horizontal scroll view
    private var categoriesScrollView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                homeButton
                
                ForEach(serviceCategories.prefix(10)) { category in
                    CategoryButtonView(
                        name: category.name,
                        isSelected: categorySheetToShow == category.name,
                        action: {
                            categorySheetToShow = category.name
                            showingAllCategories = true
                        }
                    )
                }
                
                if serviceCategories.count > 10 {
                    showAllButton
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background with theme support
                Color(.systemBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Sticky Categories Section
                    if !serviceCategories.isEmpty {
                        categoriesScrollView
                            .background(Color(.systemBackground))
                            .zIndex(1)
                    }
                    
                    // Scrollable Content
                    ScrollView {
                        VStack(spacing: 0) {
                            // Main Content
                            if searchText.isEmpty {
                                VStack(spacing: 24) {
                                    // Favorite Categories Section
                                    favoriteCategoriesSection
                                    
                                    // Jobs Near You Section
                                    if !jobsNearYou.isEmpty {
                                        jobsNearYouSection
                                    }
                                    
                                    // Featured Jobs Section
                                    if !featuredJobs.isEmpty {
                                        featuredJobsSection
                                    }
                                    
                                    // Recently Posted Jobs Section
                                    recentJobsSection
                                }
                                .padding(.vertical, 16)
                            } else {
                                // Search Results
                                searchResultsSection
                            }
                        }
                    }
                }
                
                // Loading Overlay with improved animations
                if isLoading && !jobs.isEmpty {
                    VStack {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                                .foregroundColor(.blue)
                            Text("Refreshing...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color(.systemBackground).opacity(0.95))
                        .cornerRadius(20)
                        .shadow(color: .blue.opacity(0.2), radius: 8, x: 0, y: 4)
                        .scaleEffect(isLoading ? 1.0 : 0.8)
                        .animation(.easeInOut(duration: 0.2), value: isLoading)
                        
                        Spacer()
                    }
                    .padding(.top, 8)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
                
                // Empty state with better UX
                if !isLoading && jobs.isEmpty {
                    VStack(spacing: 24) {
                        Image(systemName: "briefcase.badge.plus")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                            .opacity(0.7)
                        
                        VStack(spacing: 8) {
                            Text("No Jobs Available")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            
                            Text("Be the first to post a job or check back later")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        
                        NavigationLink(destination: PostJobView()) {
                            HStack {
                                Image(systemName: "plus")
                                Text("Post Your First Job")
                            }
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(Color.blue)
                            .cornerRadius(12)
                        }
                        .padding(.top, 8)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, 32)
                    .background(Color(.systemGroupedBackground))
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Image("AppLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 28)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingSearchSheet = true
                    }) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.primary)
                    }
                }
            }
            .task {
                await loadJobs()
                await loadUserProfile()
                await setupRealtimeSubscription()
            }
            .refreshable {
                // Add haptic feedback for pull-to-refresh
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
                
                await loadJobs(forceRefresh: true)
            }
            .onDisappear {
                Task {
                    await cleanupRealtimeSubscription()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshJobs"))) { _ in
                Task {
                    await loadJobs(forceRefresh: true)
                }
            }
            .sheet(isPresented: $showingAllCategories) {
                if let categorySheetToShow = categorySheetToShow {
                    CategoryJobsView(
                        categoryName: categorySheetToShow,
                        jobs: categorySheetJobs,
                        onJobDeleted: {
                            Task {
                                await loadJobs()
                            }
                        },
                                            )
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                    .onDisappear {
                        // Category sheet to show will be reset when sheet is dismissed
                    }
                } else {
                    AllCategoriesView(categories: serviceCategories, jobs: jobs, selectedCategory: $selectedCategory)
                        .presentationDetents([.medium, .large])
                        .presentationDragIndicator(.visible)
                }
            }
            .sheet(isPresented: $showingEnhancedSearch) {
                EnhancedJobSearchView(isPresented: $showingEnhancedSearch)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(20)
            }
            .sheet(isPresented: $showingFavoriteCategoriesSelector) {
                FavoriteCategoriesSelector(
                    currentFavorites: userProfile?.favorite_categories ?? [],
                    onSave: { selectedCategories in
                        Task {
                            await updateFavoriteCategories(selectedCategories)
                        }
                    }
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showingSearchSheet) {
                SearchJobsView(
                    jobs: jobs,
                    searchText: $searchText,
                    onJobDeleted: { Task { await loadJobs() } },
                                    )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
        }
    }
    
    private func getJobCount(for category: String) -> Int {
        return jobs.filter { $0.category.localizedCaseInsensitiveContains(category) }.count
    }
    
    @MainActor
    func loadJobs(forceRefresh: Bool = false) async {
        // For real-time updates, don't block concurrent loads
        if jobs.isEmpty || forceRefresh {
            isLoading = true
        }
        error = nil
        
        do {
            // First test database connection
            try await Networking.shared.testDatabaseConnection()
            let newJobs = try await Networking.shared.fetchJobs(forceRefresh: forceRefresh)
            
            // Add smooth animation for updates
            withAnimation(.easeInOut(duration: 0.3)) {
                jobs = newJobs
            }
            
            // print("📋 Jobs data refreshed successfully - \(jobs.count) jobs")
        } catch {
            self.error = error
            // print("❌ Error in loadJobs: \(error)")
        }
        
        isLoading = false
    }
    
    @MainActor
    func loadUserProfile() async {
        do {
            userProfile = try await ProfileNetworking.shared.ensureUserProfile()
        } catch {
            print("❌ Error loading user profile: \(error)")
        }
    }
    
    @MainActor
    func updateFavoriteCategories(_ categories: [String]) async {
        do {
            let updatedProfile = try await ProfileNetworking.shared.updateFavoriteCategories(categories)
            userProfile = updatedProfile
            showingFavoriteCategoriesSelector = false
        } catch {
            print("❌ Error updating favorite categories: \(error)")
        }
    }
    
    // MARK: - Real-time Functions
    
    private func setupRealtimeSubscription() async {
        do {
            let _ = try await supabase.auth.user()
            
            // print("📋 Setting up real-time subscription for jobs")
            
            // Create a channel for jobs
            let channel = supabase.realtimeV2.channel("jobs:all")
            
            // Listen for job changes (INSERT, UPDATE, DELETE)
            let _ = await channel.onPostgresChange(
                AnyAction.self,
                schema: "public",
                table: "jobs"
            ) { action in
                Task { @MainActor in
                    // print("📋 Real-time job update received: \(action)")
                    
                    // Add haptic feedback for new jobs
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                    
                    await self.loadJobs(forceRefresh: true)
                }
            }
            
            // Subscribe to the channel
            await channel.subscribe()
            
            // Store the channel for cleanup
            await MainActor.run {
                self.realtimeChannel = channel
            }
            
            // print("✅ Real-time jobs subscription setup complete")
        } catch {
            // print("❌ Error setting up real-time jobs: \(error)")
        }
    }
    
    private func cleanupRealtimeSubscription() async {
        // print("📋 Cleaning up real-time jobs subscription")
        
        if let channel = realtimeChannel {
            await channel.unsubscribe()
            await MainActor.run {
                self.realtimeChannel = nil
            }
        }
    }
}

// MARK: - Category Button View (YouTube Style)
struct CategoryButtonView: View {
    let name: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(name)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? Color.white : Color.primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.blue : Color(.systemGray6))
                .cornerRadius(20)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Category Card View
struct CategoryCardView: View {
    let name: String
    let bengaliName: String
    let icon: String
    let jobCount: Int
    let isSelected: Bool
    let color: String
    let action: () -> Void
    
    private func getColor() -> Color {
        switch color {
        case "blue": return .blue
        case "green": return .green
        case "purple": return .purple
        case "indigo": return .indigo
        case "red": return .red
        case "pink": return .pink
        case "orange": return .orange
        case "yellow": return .yellow
        case "teal": return .teal
        case "cyan": return .cyan
        default: return .blue
        }
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(icon)
                    .font(.system(size: 32))
                    .foregroundColor(getColor())
                
                Text(name)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .foregroundColor(.primary)
                
                Text(bengaliName)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                
                Text("\(jobCount) jobs")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(getColor().opacity(0.1))
                    .foregroundColor(getColor())
                    .cornerRadius(8)
            }
            .padding()
            .frame(width: 120, height: 140)
            .background(isSelected ? getColor().opacity(0.1) : Color(.systemGray6))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? getColor() : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - All Categories View
struct AllCategoriesView: View {
    let categories: [HardcodedServiceCategory]
    let jobs: [Job]
    @Binding var selectedCategory: String?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    ForEach(categories) { category in
                        CategoryCardView(
                            name: category.name,
                            bengaliName: category.bengaliName,
                            icon: category.icon,
                            jobCount: getJobCount(for: category.name),
                            isSelected: selectedCategory == category.name,
                            color: category.color,
                            action: {
                                selectedCategory = selectedCategory == category.name ? nil : category.name
                                dismiss()
                            }
                        )
                    }
                }
                .padding()
            }
            .navigationTitle("All Categories")
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
    
    private func getJobCount(for category: String) -> Int {
        return jobs.filter { $0.category.localizedCaseInsensitiveContains(category) }.count
    }
}

// MARK: - Category Jobs View (Floating Window)
struct CategoryJobsView: View {
    let categoryName: String
    let jobs: [Job]
    var onJobDeleted: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    if jobs.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "briefcase.badge.questionmark")
                                .font(.system(size: 50))
                                .foregroundColor(.gray)
                                .opacity(0.7)
                            
                            Text("No jobs found in \(categoryName)")
                                .font(.title3)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.center)
                            
                            Text("Try selecting a different category or check back later")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 40)
                    } else {
                        ForEach(jobs) { job in
                            JobCardView(
                                job: job,
                                onJobDeleted: onJobDeleted,
                                                            )
                        }
                    }
                }
                .padding()
            }
            .navigationTitle(categoryName)
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

// MARK: - All Jobs View
struct AllJobsView: View {
    let jobs: [Job]
    var onJobDeleted: (() -> Void)?
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(jobs.filter { $0.status == "open" }) { job in
                    JobCardView(job: job, onJobDeleted: onJobDeleted)
                }
            }
            .padding()
        }
        .navigationTitle("All Jobs")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Favorite Categories Selector
struct FavoriteCategoriesSelector: View {
    let currentFavorites: [String]
    let onSave: ([String]) -> Void

    @State private var selectedCategories: Set<String> = []
    @Environment(\.dismiss) private var dismiss

    private let serviceCategories = HardcodedServiceCategory.categories
    private let maxSelection = 4

    // Mapping function to handle database vs hardcoded name differences
    private func mapDatabaseToHardcoded(_ databaseName: String) -> String? {
        // Create a mapping for common mismatches
        let mappings: [String: String] = [
            "Transportation": "Automotive",
            "Writing & Translation": "Education & Tutoring", // Best approximation
            "Home Repair": "Home Repair & Maintenance",
            "Tutoring": "Education & Tutoring",
            "Cleaning Services": "Home Services",
            "Food Delivery": "Food & Catering"
        ]

        // First try direct mapping
        if let mapped = mappings[databaseName] {
            return mapped
        }

        // Then try exact match
        if serviceCategories.contains(where: { $0.name == databaseName }) {
            return databaseName
        }

        // Finally try partial match
        return serviceCategories.first { $0.name.contains(databaseName) || databaseName.contains($0.name) }?.name
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Choose up to \(maxSelection) favorite categories")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text("\(selectedCategories.count)/\(maxSelection) selected")
                            .font(.caption)
                            .foregroundColor(selectedCategories.count == maxSelection ? .orange : .blue)
                    }
                    .padding(.horizontal, 20)
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        ForEach(serviceCategories) { category in
                            let isSelected = selectedCategories.contains(category.name)
                            let canSelect = selectedCategories.count < maxSelection || isSelected
                            let isDisabled = !canSelect

                            VStack(spacing: 12) {
                                Text(category.icon)
                                    .font(.system(size: 32))

                                Text(category.name)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                                    .foregroundColor(isSelected ? .white : (isDisabled ? .secondary : .primary))

                                Text(category.bengaliName)
                                    .font(.caption)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(1)
                                    .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                            }
                            .padding(16)
                            .frame(height: 120)
                            .background(
                                isSelected ? Color.blue : (isDisabled ? Color(.systemGray5) : Color(.systemGray6))
                            )
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(
                                        isSelected ? Color.blue : Color.clear,
                                        lineWidth: 2
                                    )
                            )
                            .scaleEffect(isSelected ? 1.05 : 1.0)
                            .animation(.easeInOut(duration: 0.2), value: isSelected)
                            .opacity(isDisabled ? 0.5 : 1.0)
                            .onTapGesture {
                                if isSelected {
                                    selectedCategories.remove(category.name)
                                } else if selectedCategories.count < maxSelection {
                                    selectedCategories.insert(category.name)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
            .navigationTitle("Favorite Categories")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave(Array(selectedCategories))
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(selectedCategories.isEmpty)
                }
            }
        }
        .onAppear {
            // Map database categories to hardcoded categories
            let mappedCategories = currentFavorites.compactMap { databaseName in
                mapDatabaseToHardcoded(databaseName)
            }
            selectedCategories = Set(mappedCategories)
            print("🔍 FavoriteCategoriesSelector - Current favorites from DB: \(currentFavorites)")
            print("🔍 Mapped to hardcoded categories: \(mappedCategories)")
            print("🔍 Selected count: \(selectedCategories.count)")
            print("🔍 Available hardcoded categories: \(serviceCategories.map { $0.name })")
        }
    }
}

// MARK: - Search Jobs View
struct SearchJobsView: View {
    let jobs: [Job]
    @Binding var searchText: String
    var onJobDeleted: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    
    var filteredJobs: [Job] {
        if searchText.isEmpty {
            return jobs.filter { $0.status == "open" }
        }
        return jobs.filter { job in
            job.status == "open" && (
                job.title.localizedCaseInsensitiveContains(searchText) ||
                job.description.localizedCaseInsensitiveContains(searchText) ||
                job.category.localizedCaseInsensitiveContains(searchText)
            )
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("Search jobs, categories, or descriptions...", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .submitLabel(.search)
                    
                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                // Results
                ScrollView {
                    LazyVStack(spacing: 16) {
                        if searchText.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 50))
                                    .foregroundColor(.gray)
                                    .opacity(0.7)
                                
                                Text("Search for Jobs")
                                    .font(.title3)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                
                                Text("Enter keywords to find jobs by title, category, or description")
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.top, 60)
                        } else if filteredJobs.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "magnifyingglass.circle")
                                    .font(.system(size: 50))
                                    .foregroundColor(.gray)
                                    .opacity(0.7)
                                
                                Text("No Results Found")
                                    .font(.title3)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                
                                Text("Try different keywords or check your spelling")
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.top, 60)
                        } else {
                            // Results header
                            HStack {
                                Text("Search Results")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                Text("\(filteredJobs.count) jobs")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 20)
                            
                            ForEach(filteredJobs) { job in
                                JobCardView(
                                    job: job,
                                    onJobDeleted: onJobDeleted
                                )
                                .padding(.horizontal, 20)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Search Jobs")
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
    JobsListView()
} 
