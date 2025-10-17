import SwiftUI

// MARK: - Accessibility Extensions

extension View {
    /// Adds comprehensive accessibility support to any view
    func accessibilityEnhanced(
        label: String? = nil,
        hint: String? = nil,
        value: String? = nil,
        traits: AccessibilityTraits = [],
        identifier: String? = nil
    ) -> some View {
        self
            .accessibilityLabel(label ?? "")
            .accessibilityHint(hint ?? "")
            .accessibilityValue(value ?? "")
            .accessibilityAddTraits(traits)
            .accessibilityIdentifier(identifier ?? "")
    }
    
    /// Adds dynamic type support with custom scaling
    func customDynamicTypeSize(_ range: ClosedRange<DynamicTypeSize>) -> some View {
        return self.dynamicTypeSize(range)
    }
    
    /// Reduces motion when user has reduce motion enabled
    func reduceMotionSensitive<T: Equatable>(
        _ animation: Animation? = .default,
        value: T
    ) -> some View {
        self.animation(
            AccessibilitySettings.isReduceMotionEnabled ? nil : animation,
            value: value
        )
    }
    
    /// Adds high contrast support
    func highContrastAdaptive(
        normalColor: Color,
        highContrastColor: Color
    ) -> some View {
        self.foregroundColor(
            AccessibilitySettings.isHighContrastEnabled ? highContrastColor : normalColor
        )
    }
}

// MARK: - Accessibility Settings Helper
struct AccessibilitySettings {
    static var isReduceMotionEnabled: Bool {
        UIAccessibility.isReduceMotionEnabled
    }
    
    static var isHighContrastEnabled: Bool {
        UIAccessibility.isDarkerSystemColorsEnabled || UIAccessibility.isInvertColorsEnabled
    }
    
    static var isVoiceOverRunning: Bool {
        UIAccessibility.isVoiceOverRunning
    }
    
    static var currentDynamicTypeSize: DynamicTypeSize {
        DynamicTypeSize(UIApplication.shared.preferredContentSizeCategory) ?? .medium
    }
    
    static var isLargeTextEnabled: Bool {
        let currentSize = currentDynamicTypeSize
        return currentSize.isAccessibilitySize || [.xLarge, .xxLarge, .xxxLarge].contains(currentSize)
    }
}

// MARK: - Accessible Job Card
struct AccessibleJobCard: View {
    let job: Job
    let onTap: () -> Void
    let onBookmark: () -> Void
    let onShare: () -> Void
    
    @State private var isBookmarked = false
    
    var accessibilityLabel: String {
        var label = "Job: \(job.title). "
        label += "Category: \(job.category). "
        label += "Budget: \(job.budget) Taka. "
        label += "Location: \(job.location). "
        
        if job.urgent == true {
            label += "This is an urgent job. "
        }
        
        label += "Posted \(formatDate(job.created_at ?? "")). "
        
        return label
    }
    
    var accessibilityHint: String {
        "Double tap to view job details. Use rotor to access bookmark and share actions."
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text(job.category)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(6)
                    .accessibilityLabel("Category: \(job.category)")
                
                Spacer()
                
                if job.urgent == true {
                    Text("URGENT")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.red)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(4)
                        .accessibilityLabel("Urgent job")
                        .accessibilityAddTraits(.isStaticText)
                }
            }
            
            // Title
            Text(job.title)
                .font(.headline)
                .fontWeight(.semibold)
                .lineLimit(AccessibilitySettings.isLargeTextEnabled ? nil : 2)
                .accessibilityAddTraits(.isHeader)
            
            // Description
            Text(job.description)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(AccessibilitySettings.isLargeTextEnabled ? nil : 3)
            
            // Budget and Location
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "dollarsign.circle.fill")
                        .foregroundColor(.blue)
                        .accessibilityHidden(true)
                    
                    Text("৳\(job.budget)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .accessibilityLabel("\(job.budget) Taka")
                }
                
                Spacer()
                
                HStack(spacing: 4) {
                    Image(systemName: "location")
                        .foregroundColor(.gray)
                        .accessibilityHidden(true)
                    
                    Text(job.location)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Location: \(job.location)")
            }
            
            // Footer
            HStack {
                Text("Posted \(formatDate(job.created_at ?? ""))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                // Action buttons for VoiceOver users
                if AccessibilitySettings.isVoiceOverRunning {
                    HStack(spacing: 8) {
                        Button(action: onBookmark) {
                            Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                        .accessibilityLabel(isBookmarked ? "Remove bookmark" : "Bookmark job")
                        .accessibilityAddTraits(.isButton)
                        
                        Button(action: onShare) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                        .accessibilityLabel("Share job")
                        .accessibilityAddTraits(.isButton)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(
                    color: AccessibilitySettings.isHighContrastEnabled ? .clear : .black.opacity(0.05),
                    radius: 2,
                    x: 0,
                    y: 1
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            AccessibilitySettings.isHighContrastEnabled ? Color.primary : Color.clear,
                            lineWidth: AccessibilitySettings.isHighContrastEnabled ? 1 : 0
                        )
                )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .accessibilityElement(children: AccessibilitySettings.isVoiceOverRunning ? .contain : .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("JobCard_\(job.id)")
        .accessibilityActions {
            Button("Bookmark") {
                onBookmark()
            }
            
            Button("Share") {
                onShare()
            }
        }
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .none
            displayFormatter.timeStyle = .none
            displayFormatter.doesRelativeDateFormatting = true
            
            let calendar = Calendar.current
            if calendar.isDateInToday(date) {
                return "today"
            } else if calendar.isDateInYesterday(date) {
                return "yesterday"
            } else {
                displayFormatter.dateStyle = .short
                return displayFormatter.string(from: date)
            }
        }
        return "recently"
    }
}

// MARK: - Accessible Search Bar
struct AccessibleSearchBar: View {
    @Binding var text: String
    let placeholder: String
    let onSearchSubmit: () -> Void
    let onClear: () -> Void
    
    @FocusState private var isSearchFocused: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                    .font(.system(size: 16))
                    .accessibilityHidden(true)
                
                TextField(placeholder, text: $text)
                    .textFieldStyle(.plain)
                    .submitLabel(.search)
                    .focused($isSearchFocused)
                    .onSubmit {
                        onSearchSubmit()
                    }
                    .accessibilityLabel("Search field")
                    .accessibilityHint("Enter keywords to search for jobs")
                
                if !text.isEmpty {
                    Button(action: {
                        text = ""
                        onClear()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                            .font(.system(size: 16))
                    }
                    .accessibilityLabel("Clear search")
                    .accessibilityAddTraits(.isButton)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isSearchFocused ? Color.blue : (AccessibilitySettings.isHighContrastEnabled ? Color.primary : Color.clear),
                        lineWidth: isSearchFocused ? 2 : (AccessibilitySettings.isHighContrastEnabled ? 1 : 0)
                    )
            )
        }
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Accessible Loading View
struct AccessibleLoadingView: View {
    let message: String
    
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
                .accessibilityHidden(true)
            
            Text(message)
                .font(.headline)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.updatesFrequently)
                .accessibilityLabel("Loading. \(message)")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Loading. \(message)")
        .accessibilityAddTraits([.updatesFrequently])
    }
}

// MARK: - Accessible Button
struct AccessibleButton: View {
    let title: String
    let systemImage: String?
    let style: ButtonStyle
    let action: () -> Void
    
    enum ButtonStyle {
        case primary
        case secondary
        case destructive
        
        var backgroundColor: Color {
            switch self {
            case .primary: return .blue
            case .secondary: return Color(.systemGray6)
            case .destructive: return .red
            }
        }
        
        var foregroundColor: Color {
            switch self {
            case .primary: return .white
            case .secondary: return .primary
            case .destructive: return .white
            }
        }
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage = systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 16, weight: .medium))
                        .accessibilityHidden(true)
                }
                
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
            }
            .foregroundColor(
                AccessibilitySettings.isHighContrastEnabled ? 
                (style == .primary ? .white : .primary) : 
                style.foregroundColor
            )
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        AccessibilitySettings.isHighContrastEnabled ? 
                        (style == .primary ? .blue : Color(.systemGray5)) : 
                        style.backgroundColor
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                AccessibilitySettings.isHighContrastEnabled ? Color.primary : Color.clear,
                                lineWidth: AccessibilitySettings.isHighContrastEnabled ? 2 : 0
                            )
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityAddTraits(.isButton)
        .dynamicTypeSize(.medium ... .accessibility5)
    }
}

#Preview("Accessible Job Card") {
    AccessibleJobCard(
        job: Job(
            id: "1",
            title: "iOS App Development",
            description: "Looking for an experienced iOS developer to build a modern SwiftUI application with clean architecture.",
            category: "Technology",
            location: "Remote",
            status: "open",
            urgent: true,
            created_at: "2024-01-01T00:00:00Z",
            updated_at: "2024-01-01T00:00:00Z",
            client_id: "client123",
            budget: 75000,
            media_urls: nil
        ),
        onTap: {},
        onBookmark: {},
        onShare: {}
    )
    .padding()
    .background(Color(.systemGroupedBackground))
}