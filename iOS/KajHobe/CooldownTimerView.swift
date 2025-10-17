//
//  CooldownTimerView.swift
//  KajHobe
//
//  Created by Claude on 2025-08-22.
//

import SwiftUI
import Combine
import Supabase

/// A reusable view component for displaying cooldown timers with progress indicators
struct CooldownTimerView: View {
    let endTime: Date
    let timerType: String // "cooldown" or "rate_limit"
    let onComplete: (() -> Void)?
    
    @State private var remainingTime: TimeInterval = 0
    @State private var isActive: Bool = true
    
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack(spacing: 12) {
            // Timer type indicator
            HStack {
                Image(systemName: timerType == "cooldown" ? "clock.badge.exclamationmark" : "hourglass.badge.plus")
                    .foregroundColor(timerType == "cooldown" ? .orange : .blue)
                
                Text(timerType == "cooldown" ? "Cooldown Active" : "Rate Limited")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }
            
            // Countdown display
            VStack(spacing: 4) {
                Text(formatTimeRemaining(remainingTime))
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .monospaced()
                
                Text("until next attempt")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            // Progress bar
            ProgressView(value: progressValue)
                .progressViewStyle(LinearProgressViewStyle(tint: progressColor))
                .frame(height: 4)
                .background(Color.secondary.opacity(0.2))
                .clipShape(Capsule())
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.secondarySystemBackground))
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
        .onReceive(timer) { _ in
            updateRemainingTime()
        }
        .onAppear {
            updateRemainingTime()
        }
    }
    
    private var progressValue: Double {
        let totalDuration: TimeInterval = timerType == "cooldown" ? 180 : 60 // 3 minutes or 1 minute
        return 1.0 - (remainingTime / totalDuration)
    }
    
    private var progressColor: Color {
        if remainingTime <= 10 {
            return .green
        } else if remainingTime <= 30 {
            return .yellow
        } else {
            return timerType == "cooldown" ? .orange : .blue
        }
    }
    
    private func updateRemainingTime() {
        let now = Date()
        remainingTime = max(0, endTime.timeIntervalSince(now))
        
        if remainingTime <= 0 && isActive {
            isActive = false
            onComplete?()
        }
    }
    
    /// Formats time interval for user display
    private func formatTimeRemaining(_ timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }
}


// MARK: - Preview

#Preview {
    CooldownTimerView(
        endTime: Date().addingTimeInterval(180), // 3 minutes
        timerType: "cooldown",
        onComplete: {
            print("Cooldown completed")
        }
    )
    .padding()
}