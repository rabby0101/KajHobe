import SwiftUI
import Combine

// MARK: - Theme Manager
class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    
    @Published var currentTheme: AppTheme = .system
    @Published var isDarkMode: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        loadThemePreference()
        setupThemeObserver()
    }
    
    private func setupThemeObserver() {
        // Listen for system theme changes
        NotificationCenter.default.publisher(for: .systemColorSchemeChanged)
            .sink { [weak self] _ in
                self?.updateThemeAppearance()
            }
            .store(in: &cancellables)
    }
    
    private func loadThemePreference() {
        let savedTheme = UserDefaults.standard.string(forKey: "selectedTheme") ?? "system"
        currentTheme = AppTheme(rawValue: savedTheme) ?? .system
        updateThemeAppearance()
    }
    
    private func updateThemeAppearance() {
        DispatchQueue.main.async {
            switch self.currentTheme {
            case .light:
                self.isDarkMode = false
            case .dark:
                self.isDarkMode = true
            case .system:
                self.isDarkMode = UITraitCollection.current.userInterfaceStyle == .dark
            }
        }
    }
    
    func setTheme(_ theme: AppTheme) {
        currentTheme = theme
        UserDefaults.standard.set(theme.rawValue, forKey: "selectedTheme")
        updateThemeAppearance()
    }
}

// MARK: - App Theme Enum
enum AppTheme: String, CaseIterable {
    case light = "light"
    case dark = "dark"
    case system = "system"
    
    var displayName: String {
        switch self {
        case .light:
            return "Light"
        case .dark:
            return "Dark"
        case .system:
            return "System"
        }
    }
    
    var icon: String {
        switch self {
        case .light:
            return "sun.max.fill"
        case .dark:
            return "moon.fill"
        case .system:
            return "circle.lefthalf.filled"
        }
    }
}

// MARK: - Theme-Aware Design System
struct ThemedDesignSystem {
    static func colors(for colorScheme: ColorScheme) -> ThemeColors {
        return colorScheme == .dark ? ThemeColors.dark : ThemeColors.light
    }
}

struct ThemeColors {
    // Primary Colors
    let primaryBlue: Color
    let primaryBlueDark: Color
    let primaryBlueLight: Color
    
    // Secondary Colors
    let emeraldGreen: Color
    let warmOrange: Color
    let crimsonRed: Color
    
    // Background Colors
    let backgroundPrimary: Color
    let backgroundSecondary: Color
    let backgroundTertiary: Color
    let backgroundElevated: Color
    
    // Text Colors
    let textPrimary: Color
    let textSecondary: Color
    let textTertiary: Color
    let textInverse: Color
    
    // Border Colors
    let borderPrimary: Color
    let borderSecondary: Color
    
    // Surface Colors
    let surfacePrimary: Color
    let surfaceSecondary: Color
    let surfaceElevated: Color
    
    // Interactive Colors
    let interactivePrimary: Color
    let interactiveSecondary: Color
    let interactiveDisabled: Color
    
    // Status Colors
    let success: Color
    let warning: Color
    let error: Color
    let info: Color
    
    static let light = ThemeColors(
        // Primary Colors
        primaryBlue: Color(red: 0.0, green: 0.48, blue: 0.96),
        primaryBlueDark: Color(red: 0.0, green: 0.4, blue: 0.8),
        primaryBlueLight: Color(red: 0.4, green: 0.74, blue: 1.0),
        
        // Secondary Colors
        emeraldGreen: Color(red: 0.2, green: 0.73, blue: 0.49),
        warmOrange: Color(red: 1.0, green: 0.62, blue: 0.04),
        crimsonRed: Color(red: 0.96, green: 0.26, blue: 0.21),
        
        // Background Colors
        backgroundPrimary: Color(.systemBackground),
        backgroundSecondary: Color(.secondarySystemBackground),
        backgroundTertiary: Color(.tertiarySystemBackground),
        backgroundElevated: Color.white,
        
        // Text Colors
        textPrimary: Color(.label),
        textSecondary: Color(.secondaryLabel),
        textTertiary: Color(.tertiaryLabel),
        textInverse: Color.white,
        
        // Border Colors
        borderPrimary: Color(.separator),
        borderSecondary: Color(.opaqueSeparator),
        
        // Surface Colors
        surfacePrimary: Color.white,
        surfaceSecondary: Color(.systemGray6),
        surfaceElevated: Color.white,
        
        // Interactive Colors
        interactivePrimary: Color(red: 0.0, green: 0.48, blue: 0.96),
        interactiveSecondary: Color(.systemGray),
        interactiveDisabled: Color(.systemGray4),
        
        // Status Colors
        success: Color(red: 0.2, green: 0.73, blue: 0.49),
        warning: Color(red: 1.0, green: 0.62, blue: 0.04),
        error: Color(red: 0.96, green: 0.26, blue: 0.21),
        info: Color(red: 0.0, green: 0.48, blue: 0.96)
    )
    
    static let dark = ThemeColors(
        // Primary Colors
        primaryBlue: Color(red: 0.4, green: 0.74, blue: 1.0),
        primaryBlueDark: Color(red: 0.2, green: 0.6, blue: 0.9),
        primaryBlueLight: Color(red: 0.6, green: 0.8, blue: 1.0),
        
        // Secondary Colors
        emeraldGreen: Color(red: 0.3, green: 0.8, blue: 0.6),
        warmOrange: Color(red: 1.0, green: 0.7, blue: 0.2),
        crimsonRed: Color(red: 1.0, green: 0.4, blue: 0.4),
        
        // Background Colors
        backgroundPrimary: Color(.systemBackground),
        backgroundSecondary: Color(.secondarySystemBackground),
        backgroundTertiary: Color(.tertiarySystemBackground),
        backgroundElevated: Color(.systemGray6),
        
        // Text Colors
        textPrimary: Color(.label),
        textSecondary: Color(.secondaryLabel),
        textTertiary: Color(.tertiaryLabel),
        textInverse: Color.black,
        
        // Border Colors
        borderPrimary: Color(.separator),
        borderSecondary: Color(.opaqueSeparator),
        
        // Surface Colors
        surfacePrimary: Color(.systemGray6),
        surfaceSecondary: Color(.systemGray5),
        surfaceElevated: Color(.systemGray5),
        
        // Interactive Colors
        interactivePrimary: Color(red: 0.4, green: 0.74, blue: 1.0),
        interactiveSecondary: Color(.systemGray2),
        interactiveDisabled: Color(.systemGray4),
        
        // Status Colors
        success: Color(red: 0.3, green: 0.8, blue: 0.6),
        warning: Color(red: 1.0, green: 0.7, blue: 0.2),
        error: Color(red: 1.0, green: 0.4, blue: 0.4),
        info: Color(red: 0.4, green: 0.74, blue: 1.0)
    )
}

// MARK: - Theme-Aware Button Styles
struct ThemedPrimaryButtonStyle: ButtonStyle {
    let isEnabled: Bool
    @Environment(\.colorScheme) private var colorScheme
    
    init(isEnabled: Bool = true) {
        self.isEnabled = isEnabled
    }
    
    func makeBody(configuration: Configuration) -> some View {
        let colors = ThemedDesignSystem.colors(for: colorScheme)
        
        configuration.label
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(colors.textInverse)
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isEnabled ? colors.interactivePrimary : colors.interactiveDisabled)
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
            .shadow(
                color: colors.primaryBlue.opacity(colorScheme == .dark ? 0.4 : 0.3),
                radius: configuration.isPressed ? 2 : 4,
                x: 0,
                y: configuration.isPressed ? 1 : 2
            )
    }
}

struct ThemedSecondaryButtonStyle: ButtonStyle {
    let isEnabled: Bool
    @Environment(\.colorScheme) private var colorScheme
    
    init(isEnabled: Bool = true) {
        self.isEnabled = isEnabled
    }
    
    func makeBody(configuration: Configuration) -> some View {
        let colors = ThemedDesignSystem.colors(for: colorScheme)
        
        configuration.label
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(isEnabled ? colors.interactivePrimary : colors.interactiveDisabled)
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(colors.backgroundSecondary)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isEnabled ? colors.interactivePrimary : colors.interactiveDisabled, lineWidth: 1.5)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Theme-Aware Card Style
struct ThemedPremiumCardStyle: ViewModifier {
    let shadowIntensity: CGFloat
    @Environment(\.colorScheme) private var colorScheme
    
    init(shadowIntensity: CGFloat = 4) {
        self.shadowIntensity = shadowIntensity
    }
    
    func body(content: Content) -> some View {
        let colors = ThemedDesignSystem.colors(for: colorScheme)
        
        content
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(colors.surfaceElevated)
                    .shadow(
                        color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.15),
                        radius: shadowIntensity,
                        x: 0,
                        y: shadowIntensity / 2
                    )
            )
            .padding(4)
    }
}

// MARK: - Theme Toggle Component
struct ThemeToggleView: View {
    @StateObject private var themeManager = ThemeManager.shared
    @State private var showingThemeSheet = false
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        Button(action: {
            showingThemeSheet = true
        }) {
            Image(systemName: themeManager.currentTheme.icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(ThemedDesignSystem.colors(for: colorScheme).textPrimary)
                .padding(12)
                .background(
                    Circle()
                        .fill(ThemedDesignSystem.colors(for: colorScheme).backgroundSecondary)
                        .overlay(
                            Circle()
                                .stroke(ThemedDesignSystem.colors(for: colorScheme).borderPrimary, lineWidth: 1)
                        )
                )
        }
        .sheet(isPresented: $showingThemeSheet) {
            ThemeSelectionSheet()
        }
    }
}

struct ThemeSelectionSheet: View {
    @StateObject private var themeManager = ThemeManager.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("Choose Theme")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(ThemedDesignSystem.colors(for: colorScheme).textPrimary)
                    
                    Text("Select your preferred appearance")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(ThemedDesignSystem.colors(for: colorScheme).textSecondary)
                }
                .padding(.top, 24)
                
                VStack(spacing: 16) {
                    ForEach(AppTheme.allCases, id: \.self) { theme in
                        ThemeOptionRow(
                            theme: theme,
                            isSelected: themeManager.currentTheme == theme
                        ) {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                themeManager.setTheme(theme)
                            }
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                dismiss()
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                
                Spacer()
            }
            .navigationTitle("Theme")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Done") { dismiss() })
        }
    }
}

struct ThemeOptionRow: View {
    let theme: AppTheme
    let isSelected: Bool
    let onTap: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                Image(systemName: theme.icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(isSelected ? 
                                   ThemedDesignSystem.colors(for: colorScheme).interactivePrimary : 
                                   ThemedDesignSystem.colors(for: colorScheme).textSecondary)
                    .frame(width: 30)
                
                Text(theme.displayName)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(ThemedDesignSystem.colors(for: colorScheme).textPrimary)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(ThemedDesignSystem.colors(for: colorScheme).interactivePrimary)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? 
                          ThemedDesignSystem.colors(for: colorScheme).interactivePrimary.opacity(0.1) : 
                          ThemedDesignSystem.colors(for: colorScheme).backgroundSecondary)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? 
                                   ThemedDesignSystem.colors(for: colorScheme).interactivePrimary : 
                                   Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - View Extensions for Themed Components
extension View {
    func themedPremiumCard(shadowIntensity: CGFloat = 4) -> some View {
        self.modifier(ThemedPremiumCardStyle(shadowIntensity: shadowIntensity))
    }
    
    func themedPrimaryButton(isEnabled: Bool = true) -> some View {
        self.buttonStyle(ThemedPrimaryButtonStyle(isEnabled: isEnabled))
    }
    
    func themedSecondaryButton(isEnabled: Bool = true) -> some View {
        self.buttonStyle(ThemedSecondaryButtonStyle(isEnabled: isEnabled))
    }
}

// MARK: - System Color Scheme Change Notification
extension Foundation.Notification.Name {
    static let systemColorSchemeChanged = Foundation.Notification.Name("systemColorSchemeChanged")
}

// MARK: - Preview
#if DEBUG
struct ThemeManagerPreviews: PreviewProvider {
    static var previews: some View {
        Group {
            VStack(spacing: 24) {
                ThemeToggleView()
                
                VStack(spacing: 16) {
                    Button("Themed Primary Button") {}
                        .themedPrimaryButton()
                    
                    Button("Themed Secondary Button") {}
                        .themedSecondaryButton()
                }
                
                VStack(alignment: .leading, spacing: 16) {
                    Text("Themed Card")
                        .font(.system(size: 18, weight: .semibold))
                    
                    Text("This card adapts to light and dark themes automatically.")
                        .font(.system(size: 14, weight: .regular))
                }
                .padding(24)
                .themedPremiumCard()
            }
            .padding()
            .preferredColorScheme(.light)
            .previewDisplayName("Light Theme")
            
            VStack(spacing: 24) {
                ThemeToggleView()
                
                VStack(spacing: 16) {
                    Button("Themed Primary Button") {}
                        .themedPrimaryButton()
                    
                    Button("Themed Secondary Button") {}
                        .themedSecondaryButton()
                }
                
                VStack(alignment: .leading, spacing: 16) {
                    Text("Themed Card")
                        .font(.system(size: 18, weight: .semibold))
                    
                    Text("This card adapts to light and dark themes automatically.")
                        .font(.system(size: 14, weight: .regular))
                }
                .padding(24)
                .themedPremiumCard()
            }
            .padding()
            .preferredColorScheme(.dark)
            .previewDisplayName("Dark Theme")
        }
    }
}
#endif