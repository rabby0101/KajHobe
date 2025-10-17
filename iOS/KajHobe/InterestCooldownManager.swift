//
//  InterestCooldownManager.swift
//  KajHobe
//
//  Created by Claude on 2025-08-22.
//

import Foundation
import Supabase

/// Manages interest request cooldowns and attempt tracking
class InterestCooldownManager {
    
    // MARK: - Constants
    
    /// Cooldown duration in seconds (2 minutes)
    static let COOLDOWN_DURATION: TimeInterval = 120
    
    /// Maximum number of attempts before permanent block
    static let MAX_ATTEMPTS = 2
    
    /// Rate limit: minimum time between attempts (1 minute)
    static let RATE_LIMIT_DURATION: TimeInterval = 60
    
    // MARK: - Types
    
    struct CooldownStatus {
        let canShowInterest: Bool
        let attemptCount: Int
        let remainingCooldown: TimeInterval?
        let isPermanentlyBlocked: Bool
        let lastRejectionTime: Date?
        let nextAttemptTime: Date?
        let isRateLimited: Bool
        let rateLimitRemaining: TimeInterval?
        
        /// User-friendly status description
        var statusDescription: String {
            if isPermanentlyBlocked {
                return "You've reached the maximum attempts for this job"
            } else if isRateLimited {
                if let rateLimitRemaining = rateLimitRemaining {
                    let minutes = Int(rateLimitRemaining) / 60
                    let seconds = Int(rateLimitRemaining) % 60
                    return "Please wait \(minutes)m \(seconds)s before trying again"
                } else {
                    return "You have already shown interest in this job"
                }
            } else if let remainingCooldown = remainingCooldown {
                let minutes = Int(remainingCooldown) / 60
                let seconds = Int(remainingCooldown) % 60
                return "Please wait \(minutes)m \(seconds)s before showing interest again"
            } else {
                return "You can show interest in this job"
            }
        }
        
        /// Next available attempt time for UI countdown
        var nextAvailableTime: Date? {
            if let nextAttemptTime = nextAttemptTime {
                return nextAttemptTime
            } else if isRateLimited, let rateLimitRemaining = rateLimitRemaining {
                return Date().addingTimeInterval(rateLimitRemaining)
            }
            return nil
        }
    }
    
    enum CooldownError: LocalizedError {
        case permanentlyBlocked(attemptCount: Int)
        case cooldownActive(remainingTime: TimeInterval, nextAttemptTime: Date)
        case rateLimitExceeded(remainingTime: TimeInterval)
        case maxAttemptsReached
        case databaseError(String)
        
        var errorDescription: String? {
            switch self {
            case .permanentlyBlocked(let attemptCount):
                return "Maximum attempts (\(attemptCount)) reached for this job"
            case .cooldownActive(let remainingTime, _):
                let minutes = Int(remainingTime) / 60
                let seconds = Int(remainingTime) % 60
                return "Please wait \(minutes)m \(seconds)s before showing interest again"
            case .rateLimitExceeded(let remainingTime):
                let minutes = Int(remainingTime) / 60
                let seconds = Int(remainingTime) % 60
                return "Rate limit exceeded. Wait \(minutes)m \(seconds)s before trying again"
            case .maxAttemptsReached:
                return "Maximum interest attempts reached for this job"
            case .databaseError(let message):
                return "Database error: \(message)"
            }
        }
    }
    
    // MARK: - Core Logic
    
    /// Checks the current cooldown status for a provider showing interest in a job
    static func checkCooldownStatus(jobId: String, providerId: String) async throws -> CooldownStatus {
        print("🔍 Checking cooldown status - JobId: \(jobId), ProviderId: \(providerId)")
        
        do {
            // First check if there's an existing interest in job_interests table
            let existingInterestResponse = try await supabase
                .from("job_interests")
                .select("id, status, created_at")
                .eq("job_id", value: jobId)
                .eq("provider_id", value: providerId)
                .execute()
            
            if let existingInterestData = try? JSONSerialization.jsonObject(with: existingInterestResponse.data) as? [[String: Any]],
               !existingInterestData.isEmpty {
                let existingInterest = existingInterestData.first!
                let status = existingInterest["status"] as? String ?? "unknown"
                
                print("🔍 Found existing interest with status: \(status)")
                
                // If there's a pending or accepted interest, block further attempts
                if status == "pending" || status == "accepted" {
                    return CooldownStatus(
                        canShowInterest: false,
                        attemptCount: 1, // At least one attempt exists
                        remainingCooldown: nil,
                        isPermanentlyBlocked: false,
                        lastRejectionTime: nil,
                        nextAttemptTime: nil,
                        isRateLimited: true, // Use rate limit to indicate existing interest
                        rateLimitRemaining: nil
                    )
                }
            }
            
            // Get all interest attempts for this job/provider combination from notifications
            let response = try await supabase
                .from("notifications")
                .select("id, status, created_at, actioned_at")
                .eq("job_id", value: jobId)
                .eq("from_user_id", value: providerId)
                .eq("type", value: "show_interest")
                .order("created_at", ascending: false)
                .execute()
            
            guard let notificationData = try? JSONSerialization.jsonObject(with: response.data) as? [[String: Any]] else {
                print("✅ No previous attempts found - allowing interest")
                return CooldownStatus(
                    canShowInterest: true,
                    attemptCount: 0,
                    remainingCooldown: nil,
                    isPermanentlyBlocked: false,
                    lastRejectionTime: nil,
                    nextAttemptTime: nil,
                    isRateLimited: false,
                    rateLimitRemaining: nil
                )
            }
            
            print("📊 Found \(notificationData.count) previous attempt(s)")
            
            // Count rejected attempts
            let rejectedAttempts = notificationData.filter { notification in
                return notification["status"] as? String == "rejected"
            }
            
            let attemptCount = rejectedAttempts.count
            print("📊 Rejected attempts: \(attemptCount)")
            
            // Check for permanent block (2 or more rejections)
            if attemptCount >= MAX_ATTEMPTS {
                print("🚫 Permanently blocked - max attempts reached")
                return CooldownStatus(
                    canShowInterest: false,
                    attemptCount: attemptCount,
                    remainingCooldown: nil,
                    isPermanentlyBlocked: true,
                    lastRejectionTime: nil,
                    nextAttemptTime: nil,
                    isRateLimited: false,
                    rateLimitRemaining: nil
                )
            }
            
            // Check rate limiting (last attempt within 1 minute)
            if let lastAttempt = notificationData.first,
               let createdAtString = lastAttempt["created_at"] as? String,
               let lastAttemptTime = parseTimestamp(createdAtString) {
                
                let timeSinceLastAttempt = Date().timeIntervalSince(lastAttemptTime)
                if timeSinceLastAttempt < RATE_LIMIT_DURATION {
                    let rateLimitRemaining = RATE_LIMIT_DURATION - timeSinceLastAttempt
                    print("⏱️ Rate limited - \(Int(rateLimitRemaining))s remaining")
                    
                    return CooldownStatus(
                        canShowInterest: false,
                        attemptCount: attemptCount,
                        remainingCooldown: nil,
                        isPermanentlyBlocked: false,
                        lastRejectionTime: nil,
                        nextAttemptTime: nil,
                        isRateLimited: true,
                        rateLimitRemaining: rateLimitRemaining
                    )
                }
            }
            
            // Check cooldown for last rejection
            if let lastRejection = rejectedAttempts.first,
               let actionedAtString = lastRejection["actioned_at"] as? String,
               let lastRejectionTime = parseTimestamp(actionedAtString) {
                
                let timeSinceRejection = Date().timeIntervalSince(lastRejectionTime)
                let nextAttemptTime = lastRejectionTime.addingTimeInterval(COOLDOWN_DURATION)
                
                if timeSinceRejection < COOLDOWN_DURATION {
                    let remainingCooldown = COOLDOWN_DURATION - timeSinceRejection
                    print("⏰ Cooldown active - \(Int(remainingCooldown))s remaining")
                    
                    return CooldownStatus(
                        canShowInterest: false,
                        attemptCount: attemptCount,
                        remainingCooldown: remainingCooldown,
                        isPermanentlyBlocked: false,
                        lastRejectionTime: lastRejectionTime,
                        nextAttemptTime: nextAttemptTime,
                        isRateLimited: false,
                        rateLimitRemaining: nil
                    )
                }
            }
            
            // No restrictions - can show interest
            print("✅ No restrictions - allowing interest attempt \(attemptCount + 1)")
            return CooldownStatus(
                canShowInterest: true,
                attemptCount: attemptCount,
                remainingCooldown: nil,
                isPermanentlyBlocked: false,
                lastRejectionTime: nil,
                nextAttemptTime: nil,
                isRateLimited: false,
                rateLimitRemaining: nil
            )
            
        } catch {
            print("❌ Error checking cooldown status: \(error)")
            throw CooldownError.databaseError(error.localizedDescription)
        }
    }
    
    /// Validates if an interest attempt is allowed and throws appropriate error if not
    static func validateInterestAttempt(jobId: String, providerId: String) async throws {
        let status = try await checkCooldownStatus(jobId: jobId, providerId: providerId)
        
        guard status.canShowInterest else {
            if status.isPermanentlyBlocked {
                throw CooldownError.permanentlyBlocked(attemptCount: status.attemptCount)
            } else if let remainingCooldown = status.remainingCooldown,
                      let nextAttemptTime = status.nextAttemptTime {
                throw CooldownError.cooldownActive(remainingTime: remainingCooldown, nextAttemptTime: nextAttemptTime)
            } else if status.isRateLimited, let rateLimitRemaining = status.rateLimitRemaining {
                throw CooldownError.rateLimitExceeded(remainingTime: rateLimitRemaining)
            } else {
                throw CooldownError.maxAttemptsReached
            }
        }
    }
    
    /// Records a rejection and updates the cooldown state
    static func recordRejection(jobId: String, providerId: String, clientId: String) async throws {
        print("📝 Recording rejection - JobId: \(jobId), ProviderId: \(providerId)")
        
        do {
            // Update the notification status to rejected
            let currentTime = ISO8601DateFormatter().string(from: Date())
            
            let response = try await supabase
                .from("notifications")
                .update([
                    "status": AnyEncodable("rejected"),
                    "actioned_at": AnyEncodable(currentTime)
                ])
                .eq("job_id", value: jobId)
                .eq("from_user_id", value: providerId)
                .eq("to_user_id", value: clientId)
                .eq("type", value: "show_interest")
                .eq("status", value: "pending")
                .order("created_at", ascending: false)
                .limit(1)
                .execute()
            
            print("✅ Rejection recorded successfully")
            
            // Check if this was the second rejection (permanent block)
            let status = try await checkCooldownStatus(jobId: jobId, providerId: providerId)
            if status.isPermanentlyBlocked {
                print("🚫 Provider permanently blocked from job \(jobId)")
            }
            
        } catch {
            print("❌ Error recording rejection: \(error)")
            throw CooldownError.databaseError(error.localizedDescription)
        }
    }
    
    // MARK: - Helper Functions
    
    /// Parses ISO8601 timestamp string to Date
    private static func parseTimestamp(_ timestamp: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: timestamp) ?? {
            formatter.formatOptions = [.withInternetDateTime]
            return formatter.date(from: timestamp)
        }()
    }
    
    /// Formats time interval for user display
    static func formatTimeRemaining(_ timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }
    
    /// Calculates progress percentage for cooldown timer (0.0 to 1.0)
    static func calculateCooldownProgress(remainingTime: TimeInterval) -> Double {
        let progress = 1.0 - (remainingTime / COOLDOWN_DURATION)
        return max(0.0, min(1.0, progress))
    }
}

// MARK: - Extensions

extension InterestCooldownManager.CooldownStatus {
    /// Returns true if there's an active timer that should be displayed
    var hasActiveTimer: Bool {
        return remainingCooldown != nil || rateLimitRemaining != nil
    }
    
    /// Returns the active timer duration for UI purposes
    var activeTimerDuration: TimeInterval? {
        return remainingCooldown ?? rateLimitRemaining
    }
    
    /// Returns appropriate timer type for UI display
    var timerType: String {
        if remainingCooldown != nil {
            return "cooldown"
        } else if rateLimitRemaining != nil {
            return "rate_limit"
        } else {
            return "none"
        }
    }
}