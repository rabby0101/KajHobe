import SwiftUI
import Supabase

struct EnhancedJobSearchView: View {
    @Binding var isPresented: Bool
    @State private var searchText = ""
    @State private var selectedCategory: String? = nil
    @State private var budgetRange: ClosedRange<Double> = 0...100000
    @State private var isUrgentOnly = false
    @State private var selectedLocation = ""
    @State private var sortBy: SortOption = .newest
    @State private var jobs: [Job] = []
    @State private var isLoading = false
    @State private var searchResults: [Job] = []
    
    enum SortOption: String, CaseIterable {
        case newest = "Newest"
        case oldest = "Oldest"
        case budgetHigh = "Budget: High to Low"
        case budgetLow = "Budget: Low to High"
        case urgent = "Urgent First"
        
        var systemImage: String {
            switch self {
            case .newest: return "clock.arrow.circlepath"
            case .oldest: return "clock"
            case .budgetHigh: return "arrow.down.circle.fill"
            case .budgetLow: return "arrow.up.circle.fill"
            case .urgent: return "exclamationmark.triangle.fill"
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBarSection
                filtersAndResultsSection
            }
            .navigationTitle("Enhanced Search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Clear All") {
                        clearAllFilters()
                    }
                    .disabled(isAllFiltersCleared)
                }
            }
            .task {
                await loadJobs()
                performSearch()
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
    
    private var searchBarSection: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            TextField("Search jobs, skills, keywords...", text: $searchText)
                .textFieldStyle(.plain)
                .submitLabel(.search)
                .onSubmit {
                    performSearch()
                }
            
            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                    searchResults = []
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
        .padding(.top)
    }
    
    private var filtersAndResultsSection: some View {
        ScrollView {
            VStack(spacing: 16) {
                quickFiltersSection
                categoryFiltersSection
                budgetRangeSection
                searchResultsSection
            }
        }
    }
    
    private var quickFiltersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Filters")
                .font(.headline)
                .fontWeight(.semibold)
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    FilterChip(
                        title: "Urgent Jobs",
                        isSelected: isUrgentOnly,
                        icon: "exclamationmark.triangle.fill"
                    ) {
                        isUrgentOnly.toggle()
                        performSearch()
                    }
                    
                    FilterChip(
                        title: "High Budget",
                        isSelected: budgetRange.lowerBound > 50000,
                        icon: "dollarsign.circle.fill"
                    ) {
                        budgetRange = budgetRange.lowerBound > 50000 ? 0...100000 : 50000...100000
                        performSearch()
                    }
                    
                    FilterChip(
                        title: "Remote",
                        isSelected: selectedLocation.lowercased().contains("remote"),
                        icon: "laptopcomputer"
                    ) {
                        selectedLocation = selectedLocation.lowercased().contains("remote") ? "" : "Remote"
                        performSearch()
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    private var categoryFiltersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Categories")
                .font(.headline)
                .fontWeight(.semibold)
                .padding(.horizontal)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                ForEach(HardcodedServiceCategory.categories.prefix(6), id: \.id) { category in
                    CategoryFilterCard(
                        category: category,
                        isSelected: selectedCategory == category.name
                    ) {
                        selectedCategory = selectedCategory == category.name ? nil : category.name
                        performSearch()
                    }
                }
            }
            .padding(.horizontal)
        }
    }
    
    private var budgetRangeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Budget Range")
                .font(.headline)
                .fontWeight(.semibold)
                .padding(.horizontal)
            
            VStack(spacing: 8) {
                HStack {
                    Text("৳\(Int(budgetRange.lowerBound))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("৳\(Int(budgetRange.upperBound))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack(spacing: 8) {
                    BudgetRangeButton(title: "Any", range: 0...100000, currentRange: $budgetRange)
                    BudgetRangeButton(title: "Under ৳10K", range: 0...10000, currentRange: $budgetRange)
                    BudgetRangeButton(title: "৳10K-50K", range: 10000...50000, currentRange: $budgetRange)
                    BudgetRangeButton(title: "Over ৳50K", range: 50000...100000, currentRange: $budgetRange)
                }
            }
            .padding(.horizontal)
        }
    }
    
    private var searchResultsSection: some View {
        VStack(spacing: 16) {
            sortOptionsSection
            
            if !searchResults.isEmpty {
                resultsListSection
            }
        }
    }
    
    private var sortOptionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sort By")
                .font(.headline)
                .fontWeight(.semibold)
                .padding(.horizontal)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                ForEach(SortOption.allCases, id: \.self) { option in
                    SortOptionCard(
                        option: option,
                        isSelected: sortBy == option
                    ) {
                        sortBy = option
                        performSearch()
                    }
                }
            }
            .padding(.horizontal)
        }
    }
    
    private var resultsListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Search Results")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("\(searchResults.count) jobs")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            
            LazyVStack(spacing: 12) {
                ForEach(searchResults.prefix(20)) { job in
                    JobCardView(job: job)
                        .padding(.horizontal)
                }
            }
        }
        .background(Color(.systemGroupedBackground))
    }
    
    private var isAllFiltersCleared: Bool {
        searchText.isEmpty && 
        selectedCategory == nil && 
        budgetRange == 0...100000 && 
        !isUrgentOnly && 
        selectedLocation.isEmpty && 
        sortBy == .newest
    }
    
    private func clearAllFilters() {
        searchText = ""
        selectedCategory = nil
        budgetRange = 0...100000
        isUrgentOnly = false
        selectedLocation = ""
        sortBy = .newest
        performSearch()
    }
    
    private func loadJobs() async {
        isLoading = true
        do {
            jobs = try await Networking.shared.fetchJobs()
        } catch {
            print("Error loading jobs: \(error)")
        }
        isLoading = false
    }
    
    private func performSearch() {
        var filtered = jobs
        
        // Apply search text filter
        if !searchText.isEmpty {
            filtered = filtered.filter { job in
                job.title.localizedCaseInsensitiveContains(searchText) ||
                job.description.localizedCaseInsensitiveContains(searchText) ||
                job.category.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Apply category filter
        if let category = selectedCategory {
            filtered = filtered.filter { job in
                job.category.localizedCaseInsensitiveContains(category)
            }
        }
        
        // Apply budget filter
        filtered = filtered.filter { job in
            Double(job.budget) >= budgetRange.lowerBound && Double(job.budget) <= budgetRange.upperBound
        }
        
        // Apply urgent filter
        if isUrgentOnly {
            filtered = filtered.filter { $0.urgent == true }
        }
        
        // Apply location filter
        if !selectedLocation.isEmpty {
            filtered = filtered.filter { job in
                job.location.localizedCaseInsensitiveContains(selectedLocation)
            }
        }
        
        // Apply sorting
        switch sortBy {
        case .newest:
            filtered.sort { ($0.created_at ?? "") > ($1.created_at ?? "") }
        case .oldest:
            filtered.sort { ($0.created_at ?? "") < ($1.created_at ?? "") }
        case .budgetHigh:
            filtered.sort { $0.budget > $1.budget }
        case .budgetLow:
            filtered.sort { $0.budget < $1.budget }
        case .urgent:
            filtered.sort { ($0.urgent ?? false) && !($1.urgent ?? false) }
        }
        
        searchResults = filtered
    }
}

// MARK: - Supporting Views

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.blue : Color(.systemGray6))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(20)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct CategoryFilterCard: View {
    let category: HardcodedServiceCategory
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(category.icon)
                    .font(.title2)
                
                Text(category.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(height: 80)
            .frame(maxWidth: .infinity)
            .background(isSelected ? Color.blue.opacity(0.1) : Color(.systemGray6))
            .foregroundColor(isSelected ? .blue : .primary)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct BudgetRangeButton: View {
    let title: String
    let range: ClosedRange<Double>
    @Binding var currentRange: ClosedRange<Double>
    
    var isSelected: Bool {
        currentRange == range
    }
    
    var body: some View {
        Button(action: {
            currentRange = range
        }) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.blue : Color(.systemGray6))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct SortOptionCard: View {
    let option: EnhancedJobSearchView.SortOption
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: option.systemImage)
                    .font(.caption)
                
                Text(option.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(isSelected ? Color.blue.opacity(0.1) : Color(.systemGray6))
            .foregroundColor(isSelected ? .blue : .primary)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}