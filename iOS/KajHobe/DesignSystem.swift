import SwiftUI
import Foundation

// MARK: - KajHobe Design System
// A comprehensive design system for premium UI components and styling

struct KajHobeDesignSystem {
    
    // MARK: - Color Palette
    struct Colors {
        // Primary Brand Colors
        static let primaryBlue = Color(red: 0.0, green: 0.48, blue: 0.96)           // #007AFF
        static let primaryBlueDark = Color(red: 0.0, green: 0.4, blue: 0.8)        // #0066CC
        static let primaryBlueLight = Color(red: 0.4, green: 0.74, blue: 1.0)      // #66BDFF
        
        // Secondary Colors
        static let emeraldGreen = Color(red: 0.2, green: 0.73, blue: 0.49)         // #34C759
        static let emeraldGreenDark = Color(red: 0.15, green: 0.6, blue: 0.4)      // #26996B
        static let warmOrange = Color(red: 1.0, green: 0.62, blue: 0.04)           // #FF9F0A
        static let crimsonRed = Color(red: 0.96, green: 0.26, blue: 0.21)          // #FF4236
        
        // Neutral Colors
        static let neutralGray100 = Color(red: 0.98, green: 0.98, blue: 0.98)     // #FAFAFA
        static let neutralGray200 = Color(red: 0.96, green: 0.96, blue: 0.96)     // #F5F5F5
        static let neutralGray300 = Color(red: 0.9, green: 0.9, blue: 0.9)        // #E5E5E5
        static let neutralGray400 = Color(red: 0.8, green: 0.8, blue: 0.8)        // #CCCCCC
        static let neutralGray500 = Color(red: 0.6, green: 0.6, blue: 0.6)        // #999999
        static let neutralGray600 = Color(red: 0.4, green: 0.4, blue: 0.4)        // #666666
        static let neutralGray700 = Color(red: 0.3, green: 0.3, blue: 0.3)        // #4D4D4D
        static let neutralGray800 = Color(red: 0.2, green: 0.2, blue: 0.2)        // #333333
        static let neutralGray900 = Color(red: 0.1, green: 0.1, blue: 0.1)        // #1A1A1A
        
        // Semantic Colors
        static let success = emeraldGreen
        static let warning = warmOrange
        static let error = crimsonRed
        static let info = primaryBlue
        
        // Background Colors
        static let backgroundPrimary = Color(.systemBackground)
        static let backgroundSecondary = Color(.secondarySystemBackground)
        static let backgroundTertiary = Color(.tertiarySystemBackground)
        
        // Text Colors
        static let textPrimary = Color(.label)
        static let textSecondary = Color(.secondaryLabel)
        static let textTertiary = Color(.tertiaryLabel)
        static let textQuaternary = Color(.quaternaryLabel)
        
        // Interactive Colors
        static let interactivePrimary = primaryBlue
        static let interactiveSecondary = neutralGray600
        static let interactiveDisabled = neutralGray400
    }
    
    // MARK: - Typography
    struct Typography {
        // Bengali-optimized fonts
        static let bengaliFont = "Kalpurush" // Fallback to system if not available
        static let systemFont = Font.system(.body)
        
        // Display Styles
        static let displayLarge = Font.system(size: 32, weight: .bold, design: .rounded)
        static let displayMedium = Font.system(size: 28, weight: .bold, design: .rounded)
        static let displaySmall = Font.system(size: 24, weight: .semibold, design: .rounded)
        
        // Heading Styles
        static let headingXLarge = Font.system(size: 22, weight: .bold)
        static let headingLarge = Font.system(size: 20, weight: .bold)
        static let headingMedium = Font.system(size: 18, weight: .semibold)
        static let headingSmall = Font.system(size: 16, weight: .semibold)
        
        // Body Styles
        static let bodyLarge = Font.system(size: 16, weight: .regular)
        static let bodyMedium = Font.system(size: 14, weight: .regular)
        static let bodySmall = Font.system(size: 12, weight: .regular)
        
        // Label Styles
        static let labelLarge = Font.system(size: 14, weight: .medium)
        static let labelMedium = Font.system(size: 12, weight: .medium)
        static let labelSmall = Font.system(size: 10, weight: .medium)
        
        // Caption Styles
        static let captionLarge = Font.system(size: 12, weight: .regular)
        static let captionSmall = Font.system(size: 10, weight: .regular)
    }
    
    // MARK: - Spacing
    struct Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
        static let xxxl: CGFloat = 64
    }
    
    // MARK: - Border Radius
    struct Radius {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let pill: CGFloat = 9999
    }
    
    // MARK: - Shadows
    struct Shadows {
        static let small = Shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
        static let medium = Shadow(color: Color.black.opacity(0.15), radius: 4, x: 0, y: 2)
        static let large = Shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
        static let extraLarge = Shadow(color: Color.black.opacity(0.25), radius: 16, x: 0, y: 8)
    }
    
    struct Shadow {
        let color: Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat
    }
}

// MARK: - Custom Button Styles
struct PrimaryButtonStyle: ButtonStyle {
    let isEnabled: Bool
    
    init(isEnabled: Bool = true) {
        self.isEnabled = isEnabled
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(KajHobeDesignSystem.Typography.labelLarge)
            .foregroundColor(.white)
            .padding(.horizontal, KajHobeDesignSystem.Spacing.lg)
            .padding(.vertical, KajHobeDesignSystem.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: KajHobeDesignSystem.Radius.md)
                    .fill(isEnabled ? KajHobeDesignSystem.Colors.primaryBlue : KajHobeDesignSystem.Colors.interactiveDisabled)
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
            .shadow(
                color: KajHobeDesignSystem.Colors.primaryBlue.opacity(0.3),
                radius: configuration.isPressed ? 2 : 4,
                x: 0,
                y: configuration.isPressed ? 1 : 2
            )
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    let isEnabled: Bool
    
    init(isEnabled: Bool = true) {
        self.isEnabled = isEnabled
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(KajHobeDesignSystem.Typography.labelLarge)
            .foregroundColor(isEnabled ? KajHobeDesignSystem.Colors.primaryBlue : KajHobeDesignSystem.Colors.interactiveDisabled)
            .padding(.horizontal, KajHobeDesignSystem.Spacing.lg)
            .padding(.vertical, KajHobeDesignSystem.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: KajHobeDesignSystem.Radius.md)
                    .fill(KajHobeDesignSystem.Colors.backgroundSecondary)
                    .overlay(
                        RoundedRectangle(cornerRadius: KajHobeDesignSystem.Radius.md)
                            .stroke(isEnabled ? KajHobeDesignSystem.Colors.primaryBlue : KajHobeDesignSystem.Colors.interactiveDisabled, lineWidth: 1.5)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct TertiaryButtonStyle: ButtonStyle {
    let isEnabled: Bool
    
    init(isEnabled: Bool = true) {
        self.isEnabled = isEnabled
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(KajHobeDesignSystem.Typography.labelLarge)
            .foregroundColor(isEnabled ? KajHobeDesignSystem.Colors.primaryBlue : KajHobeDesignSystem.Colors.interactiveDisabled)
            .padding(.horizontal, KajHobeDesignSystem.Spacing.md)
            .padding(.vertical, KajHobeDesignSystem.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: KajHobeDesignSystem.Radius.sm)
                    .fill(configuration.isPressed ? KajHobeDesignSystem.Colors.primaryBlue.opacity(0.1) : Color.clear)
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Custom Card Style
struct PremiumCardStyle: ViewModifier {
    let shadowIntensity: KajHobeDesignSystem.Shadow
    
    init(shadow: KajHobeDesignSystem.Shadow = KajHobeDesignSystem.Shadows.medium) {
        self.shadowIntensity = shadow
    }
    
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: KajHobeDesignSystem.Radius.lg)
                    .fill(KajHobeDesignSystem.Colors.backgroundPrimary)
                    .shadow(
                        color: shadowIntensity.color,
                        radius: shadowIntensity.radius,
                        x: shadowIntensity.x,
                        y: shadowIntensity.y
                    )
            )
            .padding(KajHobeDesignSystem.Spacing.xs)
    }
}

// MARK: - Custom Input Field Style
struct PremiumInputFieldStyle: ViewModifier {
    let isFocused: Bool
    let hasError: Bool
    
    init(isFocused: Bool = false, hasError: Bool = false) {
        self.isFocused = isFocused
        self.hasError = hasError
    }
    
    func body(content: Content) -> some View {
        content
            .font(KajHobeDesignSystem.Typography.bodyMedium)
            .padding(KajHobeDesignSystem.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: KajHobeDesignSystem.Radius.md)
                    .fill(KajHobeDesignSystem.Colors.backgroundSecondary)
                    .overlay(
                        RoundedRectangle(cornerRadius: KajHobeDesignSystem.Radius.md)
                            .stroke(
                                hasError ? KajHobeDesignSystem.Colors.error :
                                isFocused ? KajHobeDesignSystem.Colors.primaryBlue :
                                KajHobeDesignSystem.Colors.neutralGray300,
                                lineWidth: hasError || isFocused ? 2 : 1
                            )
                    )
            )
            .animation(.easeInOut(duration: 0.2), value: isFocused)
            .animation(.easeInOut(duration: 0.2), value: hasError)
    }
}

// MARK: - Badge Style
struct BadgeStyle: ViewModifier {
    let color: Color
    let textColor: Color
    
    init(color: Color = KajHobeDesignSystem.Colors.primaryBlue, textColor: Color = .white) {
        self.color = color
        self.textColor = textColor
    }
    
    func body(content: Content) -> some View {
        content
            .font(KajHobeDesignSystem.Typography.captionSmall)
            .fontWeight(.semibold)
            .foregroundColor(textColor)
            .padding(.horizontal, KajHobeDesignSystem.Spacing.sm)
            .padding(.vertical, KajHobeDesignSystem.Spacing.xs)
            .background(
                RoundedRectangle(cornerRadius: KajHobeDesignSystem.Radius.pill)
                    .fill(color)
            )
    }
}

// MARK: - View Extensions for Easy Usage
extension View {
    func premiumCard(shadow: KajHobeDesignSystem.Shadow = KajHobeDesignSystem.Shadows.medium) -> some View {
        self.modifier(PremiumCardStyle(shadow: shadow))
    }
    
    func premiumInput(isFocused: Bool = false, hasError: Bool = false) -> some View {
        self.modifier(PremiumInputFieldStyle(isFocused: isFocused, hasError: hasError))
    }
    
    func badge(color: Color = KajHobeDesignSystem.Colors.primaryBlue, textColor: Color = .white) -> some View {
        self.modifier(BadgeStyle(color: color, textColor: textColor))
    }
    
    func primaryButton(isEnabled: Bool = true) -> some View {
        self.buttonStyle(PrimaryButtonStyle(isEnabled: isEnabled))
    }
    
    func secondaryButton(isEnabled: Bool = true) -> some View {
        self.buttonStyle(SecondaryButtonStyle(isEnabled: isEnabled))
    }
    
    func tertiaryButton(isEnabled: Bool = true) -> some View {
        self.buttonStyle(TertiaryButtonStyle(isEnabled: isEnabled))
    }
}

// MARK: - Premium Loading View
struct PremiumLoadingView: View {
    @State private var rotation: Double = 0
    
    var body: some View {
        VStack(spacing: KajHobeDesignSystem.Spacing.md) {
            Circle()
                .trim(from: 0, to: 0.8)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            KajHobeDesignSystem.Colors.primaryBlue,
                            KajHobeDesignSystem.Colors.primaryBlueLight,
                            KajHobeDesignSystem.Colors.primaryBlue.opacity(0.3)
                        ]),
                        center: .center,
                        startAngle: .degrees(0),
                        endAngle: .degrees(360)
                    ),
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .frame(width: 40, height: 40)
                .rotationEffect(.degrees(rotation))
                .animation(
                    .linear(duration: 1.2).repeatForever(autoreverses: false),
                    value: rotation
                )
                .onAppear {
                    rotation = 360
                }
            
            Text("Loading...")
                .font(KajHobeDesignSystem.Typography.labelMedium)
                .foregroundColor(KajHobeDesignSystem.Colors.textSecondary)
        }
        .padding(KajHobeDesignSystem.Spacing.xl)
        .background(
            RoundedRectangle(cornerRadius: KajHobeDesignSystem.Radius.md)
                .fill(KajHobeDesignSystem.Colors.backgroundPrimary)
                .shadow(
                    color: Color.black.opacity(0.1),
                    radius: 8,
                    x: 0,
                    y: 4
                )
        )
    }
}

// MARK: - Preview
#if DEBUG
struct DesignSystemPreviews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            VStack(spacing: KajHobeDesignSystem.Spacing.lg) {
                // Button Examples
                Group {
                    Button("Primary Button") {}
                        .primaryButton()
                    
                    Button("Secondary Button") {}
                        .secondaryButton()
                    
                    Button("Tertiary Button") {}
                        .tertiaryButton()
                }
                
                // Card Example
                VStack(alignment: .leading, spacing: KajHobeDesignSystem.Spacing.md) {
                    Text("Premium Card")
                        .font(KajHobeDesignSystem.Typography.headingMedium)
                    
                    Text("This is an example of our premium card styling with custom shadows and rounded corners.")
                        .font(KajHobeDesignSystem.Typography.bodyMedium)
                        .foregroundColor(KajHobeDesignSystem.Colors.textSecondary)
                }
                .padding(KajHobeDesignSystem.Spacing.lg)
                .premiumCard()
                
                // Badge Examples
                HStack(spacing: KajHobeDesignSystem.Spacing.sm) {
                    Text("Success")
                        .badge(color: KajHobeDesignSystem.Colors.success)
                    
                    Text("Warning")
                        .badge(color: KajHobeDesignSystem.Colors.warning)
                    
                    Text("Error")
                        .badge(color: KajHobeDesignSystem.Colors.error)
                }
                
                // Loading Example
                PremiumLoadingView()
            }
            .padding(KajHobeDesignSystem.Spacing.lg)
        }
        .background(KajHobeDesignSystem.Colors.backgroundSecondary)
    }
}
#endif