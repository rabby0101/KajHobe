import SwiftUI

struct GradientBackground: View {
    var body: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                Color.black,
                Color.purple.opacity(0.8),
                Color.purple.opacity(0.6),
                Color.black.opacity(0.9)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea(.all)
    }
}

struct AnimatedGradientBackground: View {
    @State private var animateGradient = false
    
    var body: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                animateGradient ? Color.purple.opacity(0.8) : Color.black,
                animateGradient ? Color.black : Color.purple.opacity(0.7),
                animateGradient ? Color.purple.opacity(0.6) : Color.black.opacity(0.8),
                animateGradient ? Color.black.opacity(0.9) : Color.purple.opacity(0.5)
            ]),
            startPoint: animateGradient ? .topTrailing : .topLeading,
            endPoint: animateGradient ? .bottomLeading : .bottomTrailing
        )
        .ignoresSafeArea(.all)
        .onAppear {
            withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
                animateGradient.toggle()
            }
        }
    }
}

// MARK: - View Modifier for consistent gradient backgrounds
struct GradientBackgroundModifier: ViewModifier {
    let animated: Bool
    
    func body(content: Content) -> some View {
        ZStack {
            if animated {
                AnimatedGradientBackground()
            } else {
                GradientBackground()
            }
            content
        }
    }
}

extension View {
    func gradientBackground(animated: Bool = false) -> some View {
        self.modifier(GradientBackgroundModifier(animated: animated))
    }
}

// MARK: - Card background for better readability on gradient
struct CardBackground: View {
    let opacity: Double
    
    init(opacity: Double = 0.1) {
        self.opacity = opacity
    }
    
    var body: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(opacity))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
    }
}

#Preview {
    VStack(spacing: 20) {
        Text("KajHobe")
            .font(.largeTitle)
            .fontWeight(.bold)
            .foregroundColor(.white)
        
        VStack(spacing: 16) {
            Text("Sample Card Content")
                .foregroundColor(.white)
            Button("Sample Button") {}
                .padding()
                .background(Color.blue.opacity(0.8))
                .foregroundColor(.white)
                .cornerRadius(8)
        }
        .padding()
        .background(CardBackground())
        .padding(.horizontal)
    }
    .gradientBackground(animated: true)
}