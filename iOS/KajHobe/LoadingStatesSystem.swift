import SwiftUI
import Combine

// MARK: - Loading States System
struct LoadingStatesSystem {
    
    // MARK: - Loading State Enum
    enum LoadingState<T> {
        case idle
        case loading
        case success(T)
        case failure(Error)
        
        var isLoading: Bool {
            if case .loading = self { return true }
            return false
        }
        
        var isSuccess: Bool {
            if case .success = self { return true }
            return false
        }
        
        var isFailure: Bool {
            if case .failure = self { return true }
            return false
        }
        
        var value: T? {
            if case .success(let value) = self { return value }
            return nil
        }
        
        var error: Error? {
            if case .failure(let error) = self { return error }
            return nil
        }
    }
}

// MARK: - Premium Loading Views
struct PremiumSkeletonLoader: View {
    let rows: Int
    let animated: Bool
    
    @State private var isAnimating = false
    @Environment(\.colorScheme) private var colorScheme
    
    init(rows: Int = 3, animated: Bool = true) {
        self.rows = rows
        self.animated = animated
    }
    
    var body: some View {
        VStack(spacing: 16) {
            ForEach(0..<rows, id: \.self) { index in
                VStack(alignment: .leading, spacing: 8) {
                    // Title skeleton
                    RoundedRectangle(cornerRadius: 8)
                        .fill(skeletonGradient)
                        .frame(height: 20)
                        .frame(maxWidth: CGFloat.random(in: 200...300))
                    
                    // Subtitle skeletons
                    ForEach(0..<2) { _ in
                        RoundedRectangle(cornerRadius: 8)
                            .fill(skeletonGradient)
                            .frame(height: 16)
                            .frame(maxWidth: CGFloat.random(in: 150...250))
                    }
                }
                .padding(16)
                .themedPremiumCard()
            }
        }
        .onAppear {
            if animated {
                withAnimation(
                    Animation.linear(duration: 1.5).repeatForever(autoreverses: true)
                ) {
                    isAnimating = true
                }
            }
        }
    }
    
    private var skeletonGradient: LinearGradient {
        let colors = ThemedDesignSystem.colors(for: colorScheme)
        
        return LinearGradient(
            gradient: Gradient(colors: [
                colors.backgroundTertiary,
                colors.backgroundSecondary,
                colors.backgroundTertiary
            ]),
            startPoint: isAnimating ? .leading : .trailing,
            endPoint: isAnimating ? .trailing : .leading
        )
    }
}

struct PremiumSpinnerView: View {
    let size: CGFloat
    let lineWidth: CGFloat
    
    @State private var rotation: Double = 0
    @Environment(\.colorScheme) private var colorScheme
    
    init(size: CGFloat = 40, lineWidth: CGFloat = 4) {
        self.size = size
        self.lineWidth = lineWidth
    }
    
    var body: some View {
        Circle()
            .trim(from: 0, to: 0.8)
            .stroke(
                AngularGradient(
                    gradient: Gradient(colors: [
                        ThemedDesignSystem.colors(for: colorScheme).primaryBlue.opacity(0.2),
                        ThemedDesignSystem.colors(for: colorScheme).primaryBlue,
                        ThemedDesignSystem.colors(for: colorScheme).primaryBlueLight
                    ]),
                    center: .center,
                    startAngle: .degrees(0),
                    endAngle: .degrees(360)
                ),
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
            )
            .frame(width: size, height: size)
            .rotationEffect(.degrees(rotation))
            .animation(
                .linear(duration: 1.2).repeatForever(autoreverses: false),
                value: rotation
            )
            .onAppear {
                rotation = 360
            }
    }
}

struct PremiumLoadingOverlay: View {
    let title: String
    let subtitle: String?
    let showProgress: Bool
    let progress: Double
    
    @Environment(\.colorScheme) private var colorScheme
    
    init(
        title: String = "Loading...",
        subtitle: String? = nil,
        showProgress: Bool = false,
        progress: Double = 0.0
    ) {
        self.title = title
        self.subtitle = subtitle
        self.showProgress = showProgress
        self.progress = progress
    }
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                PremiumSpinnerView(size: 50, lineWidth: 5)
                
                VStack(spacing: 8) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(ThemedDesignSystem.colors(for: colorScheme).textPrimary)
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(ThemedDesignSystem.colors(for: colorScheme).textSecondary)
                            .multilineTextAlignment(.center)
                    }
                }
                
                if showProgress {
                    AnimatedProgressBar(progress: progress, height: 6)
                        .frame(width: 200)
                }
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(ThemedDesignSystem.colors(for: colorScheme).backgroundElevated)
                    .shadow(
                        color: Color.black.opacity(colorScheme == .dark ? 0.6 : 0.3),
                        radius: 20,
                        x: 0,
                        y: 10
                    )
            )
        }
        .transition(AnimationSystem.Transitions.scaleAndFade)
    }
}

// MARK: - Error Handling System
struct ErrorDisplaySystem {
    
    enum ErrorType {
        case network
        case server
        case parsing
        case authentication
        case notFound
        case generic
        
        var icon: String {
            switch self {
            case .network: return "wifi.slash"
            case .server: return "server.rack"
            case .parsing: return "doc.text.magnifyingglass"
            case .authentication: return "person.badge.key.fill"
            case .notFound: return "magnifyingglass"
            case .generic: return "exclamationmark.triangle"
            }
        }
        
        var title: String {
            switch self {
            case .network: return "No Internet Connection"
            case .server: return "Server Error"
            case .parsing: return "Data Error"
            case .authentication: return "Authentication Required"
            case .notFound: return "Not Found"
            case .generic: return "Something Went Wrong"
            }
        }
    }
}

struct PremiumErrorView: View {
    let errorType: ErrorDisplaySystem.ErrorType
    let title: String?
    let message: String
    let primaryAction: (() -> Void)?
    let secondaryAction: (() -> Void)?
    
    @Environment(\.colorScheme) private var colorScheme
    
    init(
        errorType: ErrorDisplaySystem.ErrorType = .generic,
        title: String? = nil,
        message: String,
        primaryAction: (() -> Void)? = nil,
        secondaryAction: (() -> Void)? = nil
    ) {
        self.errorType = errorType
        self.title = title
        self.message = message
        self.primaryAction = primaryAction
        self.secondaryAction = secondaryAction
    }
    
    var body: some View {
        VStack(spacing: 24) {
            // Error Icon
            Image(systemName: errorType.icon)
                .font(.system(size: 60, weight: .light))
                .foregroundColor(ThemedDesignSystem.colors(for: colorScheme).error)
                .padding(24)
                .background(
                    Circle()
                        .fill(ThemedDesignSystem.colors(for: colorScheme).error.opacity(0.1))
                )
            
            // Error Text
            VStack(spacing: 8) {
                Text(title ?? errorType.title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(ThemedDesignSystem.colors(for: colorScheme).textPrimary)
                    .multilineTextAlignment(.center)
                
                Text(message)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(ThemedDesignSystem.colors(for: colorScheme).textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            // Action Buttons
            VStack(spacing: 16) {
                if let primaryAction = primaryAction {
                    Button("Try Again") {
                        primaryAction()
                    }
                    .themedPrimaryButton()
                }
                
                if let secondaryAction = secondaryAction {
                    Button("Go Back") {
                        secondaryAction()
                    }
                    .themedSecondaryButton()
                }
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ThemedDesignSystem.colors(for: colorScheme).backgroundPrimary)
    }
}

struct InlineErrorView: View {
    let message: String
    let onRetry: (() -> Void)?
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(ThemedDesignSystem.colors(for: colorScheme).error)
            
            Text(message)
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(ThemedDesignSystem.colors(for: colorScheme).textPrimary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer()
            
            if let onRetry = onRetry {
                Button("Retry") {
                    onRetry()
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(ThemedDesignSystem.colors(for: colorScheme).primaryBlue)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ThemedDesignSystem.colors(for: colorScheme).error.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(ThemedDesignSystem.colors(for: colorScheme).error.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Empty State Views
struct PremiumEmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?
    
    @Environment(\.colorScheme) private var colorScheme
    
    init(
        icon: String,
        title: String,
        message: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }
    
    var body: some View {
        VStack(spacing: 32) {
            // Icon
            Image(systemName: icon)
                .font(.system(size: 80, weight: .ultraLight))
                .foregroundColor(ThemedDesignSystem.colors(for: colorScheme).textTertiary)
            
            // Text Content
            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(ThemedDesignSystem.colors(for: colorScheme).textPrimary)
                    .multilineTextAlignment(.center)
                
                Text(message)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(ThemedDesignSystem.colors(for: colorScheme).textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            // Action Button
            if let actionTitle = actionTitle, let action = action {
                Button(actionTitle) {
                    action()
                }
                .themedPrimaryButton()
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Loading State View Modifier
struct LoadingStateModifier<T, LoadingContent: View, ErrorContent: View, EmptyContent: View>: ViewModifier {
    let loadingState: LoadingStatesSystem.LoadingState<T>
    let loadingContent: () -> LoadingContent
    let errorContent: (Error) -> ErrorContent
    let emptyContent: () -> EmptyContent
    let isEmpty: (T) -> Bool
    
    init(
        loadingState: LoadingStatesSystem.LoadingState<T>,
        isEmpty: @escaping (T) -> Bool = { _ in false },
        @ViewBuilder loadingContent: @escaping () -> LoadingContent = { PremiumSpinnerView() },
        @ViewBuilder errorContent: @escaping (Error) -> ErrorContent = { error in
            PremiumErrorView(message: error.localizedDescription)
        },
        @ViewBuilder emptyContent: @escaping () -> EmptyContent = {
            PremiumEmptyStateView(
                icon: "tray",
                title: "No Data",
                message: "There's nothing to show here."
            )
        }
    ) {
        self.loadingState = loadingState
        self.isEmpty = isEmpty
        self.loadingContent = loadingContent
        self.errorContent = errorContent
        self.emptyContent = emptyContent
    }
    
    func body(content: Content) -> some View {
        ZStack {
            switch loadingState {
            case .idle:
                content
                
            case .loading:
                loadingContent()
                    .transition(AnimationSystem.Transitions.scaleAndFade)
                
            case .success(let data):
                if isEmpty(data) {
                    emptyContent()
                        .transition(AnimationSystem.Transitions.scaleAndFade)
                } else {
                    content
                        .transition(AnimationSystem.Transitions.scaleAndFade)
                }
                
            case .failure(let error):
                errorContent(error)
                    .transition(AnimationSystem.Transitions.scaleAndFade)
            }
        }
        .animation(AnimationSystem.Presets.smooth, value: loadingState.isLoading)
        .animation(AnimationSystem.Presets.smooth, value: loadingState.isSuccess)
        .animation(AnimationSystem.Presets.smooth, value: loadingState.isFailure)
    }
}

// MARK: - View Extensions
extension View {
    func loadingState<T, LoadingContent: View, ErrorContent: View, EmptyContent: View>(
        _ state: LoadingStatesSystem.LoadingState<T>,
        isEmpty: @escaping (T) -> Bool = { _ in false },
        @ViewBuilder loading: @escaping () -> LoadingContent = { PremiumSpinnerView() },
        @ViewBuilder error: @escaping (Error) -> ErrorContent = { error in
            PremiumErrorView(message: error.localizedDescription)
        },
        @ViewBuilder empty: @escaping () -> EmptyContent = {
            PremiumEmptyStateView(
                icon: "tray",
                title: "No Data",
                message: "There's nothing to show here."
            )
        }
    ) -> some View {
        self.modifier(
            LoadingStateModifier(
                loadingState: state,
                isEmpty: isEmpty,
                loadingContent: loading,
                errorContent: error,
                emptyContent: empty
            )
        )
    }
}

// MARK: - Toast Notification System
class ToastManager: ObservableObject {
    @Published var toasts: [Toast] = []
    
    func show(
        title: String,
        message: String,
        type: Toast.ToastType = .info,
        duration: TimeInterval = 3.0
    ) {
        let toast = Toast(
            id: UUID(),
            title: title,
            message: message,
            type: type,
            duration: duration
        )
        
        withAnimation(AnimationSystem.Presets.slideIn) {
            toasts.append(toast)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            self.dismissToast(toast)
        }
    }
    
    func dismissToast(_ toast: Toast) {
        withAnimation(AnimationSystem.Presets.quick) {
            toasts.removeAll { $0.id == toast.id }
        }
    }
}

struct Toast: Identifiable, Equatable {
    let id: UUID
    let title: String
    let message: String
    let type: ToastType
    let duration: TimeInterval
    
    enum ToastType {
        case success
        case warning
        case error
        case info
    }
}

struct ToastView: View {
    let toast: Toast
    let onDismiss: () -> Void
    
    var body: some View {
        SlidingAlert(
            title: toast.title,
            message: toast.message,
            type: alertType(from: toast.type),
            onDismiss: onDismiss
        )
    }
    
    private func alertType(from toastType: Toast.ToastType) -> SlidingAlert.AlertType {
        switch toastType {
        case .success: return .success
        case .warning: return .warning
        case .error: return .error
        case .info: return .info
        }
    }
}

struct ToastContainer: View {
    @StateObject private var toastManager = ToastManager()
    
    var body: some View {
        VStack {
            ForEach(toastManager.toasts) { toast in
                ToastView(toast: toast) {
                    toastManager.dismissToast(toast)
                }
            }
            Spacer()
        }
        .padding()
        .environmentObject(toastManager)
    }
}

// MARK: - Preview
#if DEBUG
struct LoadingStatesSystemPreviews: PreviewProvider {
    static var previews: some View {
        Group {
            // Loading States
            VStack(spacing: 24) {
                PremiumSpinnerView()
                PremiumSkeletonLoader(rows: 2)
            }
            .previewDisplayName("Loading States")
            
            // Error States
            PremiumErrorView(
                errorType: .network,
                message: "Unable to connect to the internet. Please check your connection and try again."
            )
            .previewDisplayName("Error State")
            
            // Empty State
            PremiumEmptyStateView(
                icon: "briefcase",
                title: "No Jobs Found",
                message: "There are no active jobs at the moment. Try checking back later or post a new job.",
                actionTitle: "Post a Job",
                action: { }
            )
            .previewDisplayName("Empty State")
        }
    }
}
#endif