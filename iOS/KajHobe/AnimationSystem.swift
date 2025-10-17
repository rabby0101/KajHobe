import SwiftUI
import Combine

// MARK: - Animation System
struct AnimationSystem {
    
    // MARK: - Animation Presets
    struct Presets {
        static let spring = Animation.spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0.3)
        static let bouncy = Animation.spring(response: 0.5, dampingFraction: 0.6, blendDuration: 0.2)
        static let smooth = Animation.easeInOut(duration: 0.4)
        static let quick = Animation.easeInOut(duration: 0.2)
        static let gentle = Animation.easeInOut(duration: 0.8)
        static let slideIn = Animation.spring(response: 0.7, dampingFraction: 0.9)
        static let fadeIn = Animation.easeOut(duration: 0.5)
        static let scaleIn = Animation.spring(response: 0.4, dampingFraction: 0.7)
    }
    
    // MARK: - Transition Presets
    struct Transitions {
        static let slideFromBottom = AnyTransition.move(edge: .bottom).combined(with: .opacity)
        static let slideFromTop = AnyTransition.move(edge: .top).combined(with: .opacity)
        static let slideFromLeading = AnyTransition.move(edge: .leading).combined(with: .opacity)
        static let slideFromTrailing = AnyTransition.move(edge: .trailing).combined(with: .opacity)
        static let scaleAndFade = AnyTransition.scale.combined(with: .opacity)
        static let pushFromBottom = AnyTransition.asymmetric(
            insertion: .move(edge: .bottom),
            removal: .move(edge: .top)
        )
    }
}

// MARK: - Animated Container
struct AnimatedContainer<Content: View>: View {
    let content: () -> Content
    let animation: Animation
    let delay: Double
    
    @State private var isVisible = false
    
    init(
        animation: Animation = AnimationSystem.Presets.spring,
        delay: Double = 0,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.content = content
        self.animation = animation
        self.delay = delay
    }
    
    var body: some View {
        content()
            .opacity(isVisible ? 1 : 0)
            .scaleEffect(isVisible ? 1 : 0.9)
            .onAppear {
                withAnimation(animation.delay(delay)) {
                    isVisible = true
                }
            }
    }
}

// MARK: - Staggered Animation Container
struct StaggeredAnimationContainer<Content: View>: View {
    let items: [AnyView]
    let staggerDelay: Double
    let animation: Animation
    
    @State private var visibleItems: Set<Int> = []
    
    init<Items: RandomAccessCollection>(
        items: Items,
        staggerDelay: Double = 0.1,
        animation: Animation = AnimationSystem.Presets.spring,
        @ViewBuilder content: @escaping (Items.Element) -> Content
    ) where Items.Index == Int {
        self.items = items.enumerated().map { index, item in
            AnyView(content(item))
        }
        self.staggerDelay = staggerDelay
        self.animation = animation
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<items.count, id: \.self) { index in
                items[index]
                    .opacity(visibleItems.contains(index) ? 1 : 0)
                    .offset(y: visibleItems.contains(index) ? 0 : 20)
                    .animation(animation.delay(Double(index) * staggerDelay), value: visibleItems)
            }
        }
        .onAppear {
            for index in 0..<items.count {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * staggerDelay) {
                    visibleItems.insert(index)
                }
            }
        }
    }
}

// MARK: - Floating Action Button with Animation
struct FloatingActionButton: View {
    let icon: String
    let action: () -> Void
    
    @State private var isPressed = false
    @State private var isVisible = true
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        Button(action: {
            // Haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            
            withAnimation(AnimationSystem.Presets.bouncy) {
                isPressed = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(AnimationSystem.Presets.spring) {
                    isPressed = false
                }
                action()
            }
        }) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    ThemedDesignSystem.colors(for: colorScheme).primaryBlue,
                                    ThemedDesignSystem.colors(for: colorScheme).primaryBlueDark
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .scaleEffect(isPressed ? 0.9 : 1.0)
                .shadow(
                    color: ThemedDesignSystem.colors(for: colorScheme).primaryBlue.opacity(0.4),
                    radius: isPressed ? 8 : 12,
                    x: 0,
                    y: isPressed ? 4 : 6
                )
        }
        .scaleEffect(isVisible ? 1 : 0)
        .opacity(isVisible ? 1 : 0)
        .onAppear {
            withAnimation(AnimationSystem.Presets.bouncy.delay(0.5)) {
                isVisible = true
            }
        }
    }
}

// MARK: - Animated Progress Bar
struct AnimatedProgressBar: View {
    let progress: Double
    let height: CGFloat
    let cornerRadius: CGFloat
    
    @State private var animatedProgress: Double = 0
    @Environment(\.colorScheme) private var colorScheme
    
    init(progress: Double, height: CGFloat = 8, cornerRadius: CGFloat = 4) {
        self.progress = progress
        self.height = height
        self.cornerRadius = cornerRadius
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(ThemedDesignSystem.colors(for: colorScheme).backgroundTertiary)
                    .frame(height: height)
                
                // Progress fill with gradient
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                ThemedDesignSystem.colors(for: colorScheme).primaryBlue,
                                ThemedDesignSystem.colors(for: colorScheme).primaryBlueLight
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geometry.size.width * animatedProgress, height: height)
                    .overlay(
                        // Shimmer effect
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.clear,
                                        Color.white.opacity(0.3),
                                        Color.clear
                                    ]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * animatedProgress, height: height)
                            .animation(
                                Animation.linear(duration: 1.5).repeatForever(autoreverses: false),
                                value: animatedProgress
                            )
                    )
            }
        }
        .frame(height: height)
        .onAppear {
            withAnimation(AnimationSystem.Presets.smooth.delay(0.2)) {
                animatedProgress = progress
            }
        }
        .onChange(of: progress) { _, newValue in
            withAnimation(AnimationSystem.Presets.smooth) {
                animatedProgress = newValue
            }
        }
    }
}

// MARK: - Pulsing View
struct PulsingView<Content: View>: View {
    let content: () -> Content
    let pulseColor: Color
    let duration: Double
    
    @State private var isPulsing = false
    
    init(
        pulseColor: Color = .blue,
        duration: Double = 1.5,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.content = content
        self.pulseColor = pulseColor
        self.duration = duration
    }
    
    var body: some View {
        ZStack {
            content()
            
            content()
                .opacity(isPulsing ? 0 : 0.8)
                .scaleEffect(isPulsing ? 1.2 : 1.0)
                .foregroundColor(pulseColor)
                .animation(
                    Animation.easeInOut(duration: duration).repeatForever(autoreverses: true),
                    value: isPulsing
                )
        }
        .onAppear {
            isPulsing = true
        }
    }
}

// MARK: - Sliding Alert
struct SlidingAlert: View {
    let title: String
    let message: String
    let type: AlertType
    let onDismiss: () -> Void
    
    @State private var isVisible = false
    @State private var dragOffset: CGFloat = 0
    @Environment(\.colorScheme) private var colorScheme
    
    enum AlertType {
        case success
        case warning
        case error
        case info
        
        var icon: String {
            switch self {
            case .success: return "checkmark.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .error: return "xmark.circle.fill"
            case .info: return "info.circle.fill"
            }
        }
        
        func color(for colorScheme: ColorScheme) -> Color {
            let colors = ThemedDesignSystem.colors(for: colorScheme)
            switch self {
            case .success: return colors.success
            case .warning: return colors.warning
            case .error: return colors.error
            case .info: return colors.info
            }
        }
    }
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: type.icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(type.color(for: colorScheme))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(ThemedDesignSystem.colors(for: colorScheme).textPrimary)
                
                Text(message)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(ThemedDesignSystem.colors(for: colorScheme).textSecondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            Button(action: {
                withAnimation(AnimationSystem.Presets.quick) {
                    isVisible = false
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    onDismiss()
                }
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(ThemedDesignSystem.colors(for: colorScheme).textTertiary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ThemedDesignSystem.colors(for: colorScheme).backgroundElevated)
                .shadow(
                    color: Color.black.opacity(colorScheme == .dark ? 0.4 : 0.2),
                    radius: 8,
                    x: 0,
                    y: 4
                )
        )
        .offset(x: dragOffset, y: isVisible ? 0 : -100)
        .opacity(isVisible ? 1 : 0)
        .gesture(
            DragGesture()
                .onChanged { value in
                    dragOffset = value.translation.width > 0 ? 0 : value.translation.width
                }
                .onEnded { value in
                    if value.translation.width < -100 {
                        withAnimation(AnimationSystem.Presets.quick) {
                            isVisible = false
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            onDismiss()
                        }
                    } else {
                        withAnimation(AnimationSystem.Presets.spring) {
                            dragOffset = 0
                        }
                    }
                }
        )
        .onAppear {
            withAnimation(AnimationSystem.Presets.slideIn) {
                isVisible = true
            }
            
            // Auto dismiss after 5 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                if isVisible {
                    withAnimation(AnimationSystem.Presets.quick) {
                        isVisible = false
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        onDismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Animated Number Counter
struct AnimatedCounter: View {
    let value: Int
    let font: Font
    let color: Color
    
    @State private var animatedValue: Int = 0
    @State private var displayValue: String = "0"
    
    init(value: Int, font: Font = .system(size: 20, weight: .bold), color: Color = .primary) {
        self.value = value
        self.font = font
        self.color = color
    }
    
    var body: some View {
        Text(displayValue)
            .font(font)
            .fontWeight(.bold)
            .foregroundColor(color)
            .onAppear {
                animateToValue()
            }
            .onChange(of: value) { _, newValue in
                animateToValue()
            }
    }
    
    private func animateToValue() {
        let duration: Double = 1.0
        let steps = 30
        let increment = max(1, (value - animatedValue) / steps)
        
        Timer.scheduledTimer(withTimeInterval: duration / Double(steps), repeats: true) { timer in
            if animatedValue < value {
                animatedValue = min(value, animatedValue + increment)
                displayValue = formatNumber(animatedValue)
            } else {
                timer.invalidate()
            }
        }
    }
    
    private func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }
}

// MARK: - Loading Shimmer Effect
struct ShimmerEffect: ViewModifier {
    @State private var phase: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .overlay(
                Rectangle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.clear,
                                Color.white.opacity(0.6),
                                Color.clear
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .rotationEffect(.degrees(30))
                    .offset(x: phase)
                    .animation(
                        Animation.linear(duration: 1.5).repeatForever(autoreverses: false),
                        value: phase
                    )
            )
            .onAppear {
                phase = 300
            }
    }
}

// MARK: - View Extensions
extension View {
    func animatedContainer(
        animation: Animation = AnimationSystem.Presets.spring,
        delay: Double = 0
    ) -> some View {
        AnimatedContainer(animation: animation, delay: delay) {
            self
        }
    }
    
    func shimmer() -> some View {
        self.modifier(ShimmerEffect())
    }
    
    func pulse(color: Color = .blue, duration: Double = 1.5) -> some View {
        PulsingView(pulseColor: color, duration: duration) {
            self
        }
    }
}

// MARK: - Preview
#if DEBUG
struct AnimationSystemPreviews: PreviewProvider {
    @State static var progress: Double = 0.7
    
    static var previews: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Animated Progress Bar
                VStack(alignment: .leading, spacing: 8) {
                    Text("Progress Bar Animation")
                        .font(.system(size: 18, weight: .semibold))
                    
                    AnimatedProgressBar(progress: progress)
                        .frame(height: 8)
                }
                
                // Animated Counter
                VStack(alignment: .leading, spacing: 8) {
                    Text("Counter Animation")
                        .font(.system(size: 18, weight: .semibold))
                    
                    AnimatedCounter(value: 1250)
                }
                
                // Floating Action Button
                HStack {
                    Spacer()
                    FloatingActionButton(icon: "plus") {
                        print("FAB tapped")
                    }
                }
                
                // Pulsing view example
                Circle()
                    .frame(width: 50, height: 50)
                    .pulse(color: .blue)
                
                // Shimmer effect example
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 60)
                    .shimmer()
            }
            .padding(24)
        }
    }
}
#endif