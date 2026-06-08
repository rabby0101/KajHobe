// DatabaseModels.swift
// This file is the single source of truth for all database models. Do not duplicate models elsewhere.

import Foundation

// MARK: - Custom notification type to avoid system conflicts
/// Custom notification type enum that avoids conflicts with system NotificationType
/// Used throughout the app for categorizing different notification types
public enum DatabaseNotificationType: String, Sendable, CaseIterable {
    // Job Interest types
    case interestReceived = "interest_received"
    case interestAccepted = "interest_accepted"
    case interestRejected = "interest_rejected"
    case interestRequest = "interest_request"
    
    // Deal Offer types
    case dealOfferReceived = "deal_offer_received"
    case dealOfferAccepted = "deal_offer_accepted"
    case dealOfferRejected = "deal_offer_rejected"
    case offerReceived = "offer_received"
    
    // Completion Request types
    case completionRequested = "completion_requested"
    case completionApproved = "completion_approved"
    case completionRejected = "completion_rejected"
    
    // Deal types
    case dealCreated = "deal_created"
    case dealCompleted = "deal_completed"
    
    // Message types
    case messageReceived = "message_received"
    case newMessage = "new_message"
    
    // Profile and Application types
    case profileView = "profile_view"
    case jobApplication = "job_application"
}

// MARK: - Helper struct for encoding Any values
struct AnyEncodable: Encodable, Sendable {
    let value: Any
    
    nonisolated init(_ value: Any) {
        self.value = value
    }
    
    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyEncodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyEncodable($0) })
        case is NSNull:
            try container.encodeNil()
        default:
            try container.encodeNil()
        }
    }
}

// MARK: - Helper struct for handling JSON fields
enum AnyCodable: Codable, Sendable {
    case null
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case array([AnyCodable])
    case dictionary([String: AnyCodable])
    
    init(_ value: Any) {
        if value is NSNull {
            self = .null
        } else if let bool = value as? Bool {
            self = .bool(bool)
        } else if let int = value as? Int {
            self = .int(int)
        } else if let double = value as? Double {
            self = .double(double)
        } else if let string = value as? String {
            self = .string(string)
        } else if let array = value as? [Any] {
            self = .array(array.map { AnyCodable($0) })
        } else if let dictionary = value as? [String: Any] {
            self = .dictionary(dictionary.mapValues { AnyCodable($0) })
        } else {
            self = .null
        }
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if container.decodeNil() {
            self = .null
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if let int = try? container.decode(Int.self) {
            self = .int(int)
        } else if let double = try? container.decode(Double.self) {
            self = .double(double)
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let array = try? container.decode([AnyCodable].self) {
            self = .array(array)
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            self = .dictionary(dictionary)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "AnyCodable value cannot be decoded")
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch self {
        case .null:
            try container.encodeNil()
        case .bool(let bool):
            try container.encode(bool)
        case .int(let int):
            try container.encode(int)
        case .double(let double):
            try container.encode(double)
        case .string(let string):
            try container.encode(string)
        case .array(let array):
            try container.encode(array)
        case .dictionary(let dictionary):
            try container.encode(dictionary)
        }
    }
}

// MARK: - AnyCodable Helper Extensions
extension AnyCodable {
    nonisolated var stringValue: String? {
        switch self {
        case .string(let string):
            return string
        default:
            return nil
        }
    }
    
    var intValue: Int? {
        switch self {
        case .int(let int):
            return int
        default:
            return nil
        }
    }
    
    var doubleValue: Double? {
        switch self {
        case .double(let double):
            return double
        default:
            return nil
        }
    }
    
    var boolValue: Bool? {
        switch self {
        case .bool(let bool):
            return bool
        default:
            return nil
        }
    }
    
    var arrayValue: [AnyCodable]? {
        switch self {
        case .array(let array):
            return array
        default:
            return nil
        }
    }
    
    var dictionaryValue: [String: AnyCodable]? {
        switch self {
        case .dictionary(let dictionary):
            return dictionary
        default:
            return nil
        }
    }
}

// MARK: - Jobs
struct Job: Identifiable, Codable, Sendable {
    let id: String  // Changed from Int to String (uuid)
    let title: String
    let description: String
    let category: String
    let location: String
    var status: String?
    let urgent: Bool?
    let created_at: String?
    let updated_at: String?
    let client_id: String  // This is uuid, keep as String
    let budget: Int
    let media_urls: [MediaItem]?

    // Media item structure for photos and videos
    struct MediaItem: Codable, Sendable, Identifiable {
        let id: String
        let url: String
        let type: MediaType
        let thumbnail_url: String?

        enum MediaType: String, Codable, Sendable {
            case image = "image"
            case video = "video"
        }

        init(id: String = UUID().uuidString, url: String, type: MediaType, thumbnail_url: String? = nil) {
            self.id = id
            self.url = url
            self.type = type
            self.thumbnail_url = thumbnail_url
        }
    }
}

struct JobInsert: Codable, Sendable {
    let title: String
    let description: String
    let category: String
    let location: String
    let status: String?
    let urgent: Bool?
    let client_id: String  // This is uuid, keep as String
    let budget: Int
    let media_urls: [Job.MediaItem]?
}

// MARK: - Bids
struct Bid: Identifiable, Codable, Sendable {
    let id: String  // uuid
    let job_id: String  // Changed from Int to String (uuid)
    let provider_id: String  // uuid
    let amount: Int
    let message: String?
    let status: String?
    let created_at: String?
}

struct BidInsert: Codable, Sendable {
    let job_id: String  // Changed from Int to String (uuid)
    let provider_id: String  // uuid
    let amount: Int
    let message: String?
    let status: String?
}

// MARK: - Unified Notification System
public enum NotificationSource: String, CaseIterable, Sendable {
    case jobInterest = "job_interest"
    case dealOffer = "deal_offer"
    case completionRequest = "completion_request"
    case deal = "deal"
    case message = "message"
}

enum NotificationPriority: String, Codable, CaseIterable, Sendable {
    case high = "high"
    case normal = "normal"
    case low = "low"
}

// NotificationPriority consolidated with Enhanced Notification System

struct UnifiedNotification: Identifiable, Sendable {
    let id: String
    let source: NotificationSource
    let type: DatabaseNotificationType
    let title: String
    let message: String
    let created_at: String
    let status: String?
    let isInteractive: Bool
    let priority: NotificationPriority
    
    // Related data
    let job_id: String?
    let job_title: String?
    let from_user_id: String?
    let from_user_name: String?
    let avatar_url: String?
    
    // Raw source data for actions
    let sourceData: [String: Any]
    
    // Action handlers (will be set by the view)
    var onAccept: (() -> Void)?
    var onReject: (() -> Void)?
    var onView: (() -> Void)?
    
    // Helper computed properties
    var isUnread: Bool { status?.lowercased() == "pending" }
    var statusColor: NotificationColor {
        switch status?.lowercased() {
        case "pending":
            return .brown
        case "accepted":
            return .green
        case "rejected":
            return .red
        default:
            return .gray
        }
    }
    
    enum NotificationColor {
        case brown, green, red, gray
    }
    
    // Custom initializer
    init(id: String, source: NotificationSource, type: DatabaseNotificationType, title: String, message: String, created_at: String, status: String? = nil, isInteractive: Bool = false, priority: NotificationPriority = .normal, job_id: String? = nil, job_title: String? = nil, from_user_id: String? = nil, from_user_name: String? = nil, avatar_url: String? = nil, sourceData: [String: Any] = [:]) {
        self.id = id
        self.source = source
        self.type = type
        self.title = title
        self.message = message
        self.created_at = created_at
        self.status = status
        self.isInteractive = isInteractive
        self.priority = priority
        self.job_id = job_id
        self.job_title = job_title
        self.from_user_id = from_user_id
        self.from_user_name = from_user_name
        self.avatar_url = avatar_url
        self.sourceData = sourceData
    }
}

// MARK: - Deals
struct DealOffer: Codable, Sendable {
    let id: String
    let conversation_id: String
    let provider_id: String
    let client_id: String
    let job_id: String
    let amount: Int
    let terms: String?
    let timeline: String?
    let status: String // "pending", "accepted", "rejected"
    let created_at: String
    let responded_at: String?
    
    // Related data
    var job: Job?
    var provider_profile: SimpleProfile?
    var client_profile: SimpleProfile?
}

struct DealOfferInsert: Codable, Sendable {
    let conversation_id: String
    let provider_id: String
    let client_id: String
    let job_id: String
    let amount: Int
    let terms: String?
    let timeline: String?
    let status: String  // Explicitly include status field
}

struct DealResponse: Codable, Sendable {
    let deal_offer_id: String
    let response: String // "accepted" or "rejected"
    let message: String?
}

// MARK: - Deal Count Tracking
struct DealCount: Codable, Sendable {
    let job_id: String
    let provider_id: String
    let deal_count: Int
}

// MARK: - Updated Deal Model
struct Deal: Identifiable, Codable, Sendable {
    let id: String  // uuid
    let job_id: String  // Changed from Int to String (uuid)
    let client_id: String  // uuid
    let provider_id: String  // uuid
    let proposal_id: String?  // uuid
    let conversation_id: String?  // uuid - added for chat-based deals
    let agreed_amount: Int
    let agreed_terms: String?  // Added for deal terms
    let timeline: String?  // Added for deal timeline
    let status: String
    let completion_status: String? // Added for completion tracking
    let client_completion_requested: Bool? // Added for completion tracking
    let provider_completion_requested: Bool? // Added for completion tracking
    let client_completion_requested_at: String? // Added for completion tracking
    let provider_completion_requested_at: String? // Added for completion tracking
    let created_at: String?
    let completed_at: String?
    
    // Related data from joins
    var job: Job?  // Job relationship data (renamed from jobs to match query)
    var client_profile: SimpleProfile?  // Client profile data
    var provider_profile: SimpleProfile?  // Provider profile data
}

// MARK: - Escrow (deal payment ledger)

/// Lifecycle of the money held against a deal. Mirrors the Postgres `escrow_state` enum.
enum EscrowState: String, Codable, Sendable, CaseIterable {
    case pending   = "pending"    // deal exists, buyer hasn't paid yet
    case held      = "held"       // buyer paid into the merchant account; funds held
    case released  = "released"   // deal completed; owed to provider, not yet paid
    case paid_out  = "paid_out"   // provider has received the money
    case refunded  = "refunded"   // returned to the buyer
    case failed    = "failed"     // a collect/payout attempt failed

    /// Short human label for badges.
    var label: String {
        switch self {
        case .pending:  return "Awaiting payment"
        case .held:     return "In escrow"
        case .released: return "Released"
        case .paid_out: return "Paid out"
        case .refunded: return "Refunded"
        case .failed:   return "Payment failed"
        }
    }

    /// SF Symbol name for the badge (UI maps this to an Image).
    var systemImage: String {
        switch self {
        case .pending:  return "clock.badge.exclamationmark"
        case .held:     return "lock.shield.fill"
        case .released: return "checkmark.seal.fill"
        case .paid_out: return "checkmark.circle.fill"
        case .refunded: return "arrow.uturn.backward.circle.fill"
        case .failed:   return "xmark.octagon.fill"
        }
    }
}

/// One escrow row per deal (Postgres `public.escrow_transactions`). The app reads this;
/// all state changes happen server-side via DB triggers and SECURITY DEFINER RPCs.
struct EscrowTransaction: Identifiable, Codable, Sendable {
    let id: String
    let deal_id: String
    let client_id: String
    let provider_id: String
    let amount: Int
    let platform_fee: Int
    let provider_amount: Int
    let state: EscrowState
    let currency: String
    let collection_payment_id: String?
    let collection_trx_id: String?
    let payout_trx_id: String?
    let provider_msisdn: String?
    let held_at: String?
    let released_at: String?
    let paid_out_at: String?
    let refunded_at: String?
    let paid_out_by: String?
    let notes: String?
    let created_at: String?
    let updated_at: String?

    var formattedAmount: String { "৳\(amount)" }
    var formattedProviderAmount: String { "৳\(provider_amount)" }
}

struct DealInsert: Codable, Sendable {
    let deal_offer_id: String
    let conversation_id: String  // Added to match database schema
    let provider_id: String
    let client_id: String
    let job_id: String
    let agreed_amount: Int  // Changed from 'amount' to 'agreed_amount' to match database schema
    let agreed_terms: String?  // Changed from 'terms' to 'agreed_terms' to match database schema
    let timeline: String?
    let status: String
}

// MARK: - Profiles
struct Profile: Identifiable, Codable, Sendable {
    let id: String
    let email: String?
    var full_name: String?
    let phone: String?
    let avatar_url: String?
    let user_type: String?
    let location: String?
    var bio: String?
    var website: String?
    var is_service_provider: Bool?
    let role: String?
    let average_rating: Double?
    let ratings_count: Int?
    let created_at: String?
    let updated_at: String?
    
    // Favorite categories (max 4)
    var favorite_categories: [String]?

    // Provider detail fields (editable; power the public provider profile)
    var profession: String?
    var tagline: String?
    var experience_years: Int?
    var hourly_rate: Double?
    var team_rate: Double?
    var team_hours_label: String?

    // Presence fields
    let is_online: Bool?
    let last_seen_at: String?
    let average_response_time_minutes: Int?

    // Push notification fields
    let device_token: String?
    let push_enabled: Bool?
    let last_push_sent_at: String?
}

struct ProfileInsert: Codable, Sendable {
    let id: String
    let email: String?
    let full_name: String?
    let phone: String?
    let avatar_url: String?
    let user_type: String?
    let location: String?
    let bio: String?
    let website: String?
    let is_service_provider: Bool?
    let favorite_categories: [String]?
    let device_token: String?
    let push_enabled: Bool?
}

struct SimpleProfile: Identifiable, Codable, Sendable {
    let id: String
    let full_name: String?
    let avatar_url: String?
    
    // Presence fields
    let is_online: Bool?
    let last_seen_at: String?
    let average_response_time_minutes: Int?
    
    // Helper computed properties for presence
    var isOnline: Bool {
        return is_online ?? false
    }
    
    var formattedLastSeen: String {
        guard let lastSeenAt = last_seen_at else { return "Never" }
        
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: lastSeenAt) else { return "Unknown" }
        
        let now = Date()
        let interval = now.timeIntervalSince(date)
        
        if interval < 60 {
            return "Just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes) min ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours) hour\(hours == 1 ? "" : "s") ago"
        } else {
            let days = Int(interval / 86400)
            return "\(days) day\(days == 1 ? "" : "s") ago"
        }
    }
    
    var averageResponseTimeText: String {
        guard let responseTime = average_response_time_minutes else { return "Unknown" }
        
        if responseTime < 60 {
            return "\(responseTime) min"
        } else if responseTime < 1440 {
            let hours = responseTime / 60
            let remainingMinutes = responseTime % 60
            if remainingMinutes == 0 {
                return "\(hours) hour\(hours == 1 ? "" : "s")"
            } else {
                return "\(hours)h \(remainingMinutes)m"
            }
        } else {
            let days = responseTime / 1440
            return "\(days) day\(days == 1 ? "" : "s")"
        }
    }
}

// MARK: - Public Profiles
/// Trust level enumeration based on completed jobs and ratings
enum TrustLevel: String, Codable, CaseIterable, Sendable {
    case unverified = "unverified"
    case newcomer = "newcomer"
    case established = "established"
    case experienced = "experienced"
    case expert = "expert"

    var displayName: String {
        switch self {
        case .unverified: return "Unverified"
        case .newcomer: return "Newcomer"
        case .established: return "Established"
        case .experienced: return "Experienced"
        case .expert: return "Expert"
        }
    }

    var badgeColor: String {
        switch self {
        case .unverified: return "gray"
        case .newcomer: return "blue"
        case .established: return "green"
        case .experienced: return "orange"
        case .expert: return "purple"
        }
    }

    var icon: String {
        switch self {
        case .unverified: return "questionmark.circle"
        case .newcomer: return "star.circle"
        case .established: return "checkmark.seal"
        case .experienced: return "crown"
        case .expert: return "star.circle.fill"
        }
    }
}

/// Optimized public profile model with pre-computed statistics
struct PublicProfile: Identifiable, Codable, Sendable {
    // Basic Profile Info
    let id: String
    let full_name: String?
    let avatar_url: String?
    let bio: String?
    let location: String?
    let website: String?
    let is_service_provider: Bool?
    let created_at: String?

    // Computed Statistics (pre-calculated for performance)
    let completed_jobs: Int
    let avg_job_value: Double
    let total_earnings: Double
    let avg_rating: Double
    let review_count: Int

    // Activity Indicators
    let is_online: Bool?
    let last_seen_at: String?
    let average_response_time_minutes: Int?

    // Service Information
    let service_categories: [String]
    let trust_level: String
    let last_updated: String?

    // Provider detail fields (editable in own ProfileView; optional for safe decoding)
    let profession: String?
    let tagline: String?
    let experience_years: Int?
    let hourly_rate: Double?
    let team_rate: Double?
    let team_hours_label: String?

    // MARK: - Computed Properties

    var trustLevelEnum: TrustLevel {
        return TrustLevel(rawValue: trust_level) ?? .unverified
    }

    /// "৳159/hr" — nil when no hourly rate set.
    var formattedHourlyRate: String? {
        guard let rate = hourly_rate, rate > 0 else { return nil }
        return "৳\(formatAmount(rate))/hr"
    }

    /// "৳1059" — nil when no team rate set.
    var formattedTeamRate: String? {
        guard let rate = team_rate, rate > 0 else { return nil }
        return "৳\(formatAmount(rate))"
    }

    /// "8 years of experience" / "1 year of experience" / "New provider" when unset.
    var experienceText: String {
        guard let years = experience_years, years > 0 else { return "New provider" }
        return "\(years) year\(years == 1 ? "" : "s") of experience"
    }

    /// Derived from completed jobs, e.g. "150+", "12", or "New".
    var formattedCustomers: String {
        switch completed_jobs {
        case 0: return "New"
        case 1..<10: return "\(completed_jobs)"
        case 10..<100: return "\((completed_jobs / 10) * 10)+"
        default: return "\((completed_jobs / 50) * 50)+"
        }
    }

    /// Whole-number when integral (৳159), else two decimals (৳159.50).
    private func formatAmount(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", value)
        }
        return String(format: "%.2f", value)
    }

    var isOnline: Bool {
        return is_online ?? false
    }

    var formattedRating: String {
        return avg_rating > 0 ? String(format: "%.1f", avg_rating) : "No ratings"
    }

    var formattedJobCount: String {
        switch completed_jobs {
        case 0: return "No completed jobs"
        case 1: return "1 completed job"
        default: return "\(completed_jobs) completed jobs"
        }
    }

    var formattedEarnings: String {
        if total_earnings == 0 { return "৳0" }

        if total_earnings >= 100000 {
            return "৳\(String(format: "%.0f", total_earnings / 1000))K"
        } else {
            return "৳\(String(format: "%.0f", total_earnings))"
        }
    }

    var formattedLastSeen: String {
        guard let lastSeenAt = last_seen_at else { return "Never" }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: lastSeenAt) else { return "Unknown" }

        let now = Date()
        let interval = now.timeIntervalSince(date)

        if interval < 60 {
            return "Just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes) min ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours) hour\(hours == 1 ? "" : "s") ago"
        } else {
            let days = Int(interval / 86400)
            return "\(days) day\(days == 1 ? "" : "s") ago"
        }
    }

    var responseTimeText: String {
        guard let responseTime = average_response_time_minutes else { return "Unknown" }

        if responseTime < 60 {
            return "\(responseTime) min"
        } else if responseTime < 1440 {
            let hours = responseTime / 60
            return "\(hours) hour\(hours == 1 ? "" : "s")"
        } else {
            let days = responseTime / 1440
            return "\(days) day\(days == 1 ? "" : "s")"
        }
    }

    var topServiceCategories: [String] {
        return Array(service_categories.prefix(3))
    }

    var hasExperience: Bool {
        return completed_jobs > 0 || avg_rating > 0
    }
}

/// Service highlight showing provider's expertise in specific categories
struct ServiceHighlight: Identifiable, Codable, Sendable {
    let id = UUID().uuidString
    let category: String
    let job_count: Int
    let avg_rating: Double?
    let recent_completion: String?
    let avg_job_value: Double?

    var formattedJobCount: String {
        return job_count == 1 ? "1 job" : "\(job_count) jobs"
    }

    var formattedRating: String {
        guard let rating = avg_rating, rating > 0 else { return "No ratings" }
        return String(format: "%.1f ⭐", rating)
    }

    var formattedRecentCompletion: String {
        guard let completion = recent_completion else { return "No recent work" }

        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: completion) else { return "Unknown" }

        let interval = Date().timeIntervalSince(date)
        let days = Int(interval / 86400)

        if days == 0 {
            return "Today"
        } else if days == 1 {
            return "Yesterday"
        } else if days < 30 {
            return "\(days) days ago"
        } else {
            return "Over a month ago"
        }
    }
}

/// Minimal profile data for efficient batch loading in lists
struct PublicProfileSummary: Identifiable, Codable, Sendable {
    let id: String
    let full_name: String?
    let avatar_url: String?
    let trust_level: String
    let completed_jobs: Int
    let avg_rating: Double
    let is_online: Bool?

    var trustLevelEnum: TrustLevel {
        return TrustLevel(rawValue: trust_level) ?? .unverified
    }

    var shortRating: String {
        return avg_rating > 0 ? String(format: "%.1f", avg_rating) : "New"
    }

    var isOnline: Bool {
        return is_online ?? false
    }
}

// MARK: - Proposals
struct Proposal: Identifiable, Codable, Sendable {
    let id: String  // uuid
    let job_id: String  // Changed from Int to String (uuid)
    let provider_id: String  // uuid
    let amount: Int
    let message: String?
    let status: String
    let created_at: String?
    let updated_at: String?
}

struct ProposalInsert: Codable, Sendable {
    let job_id: String  // Changed from Int to String (uuid)
    let provider_id: String  // uuid
    let amount: Int
    let message: String?
    let status: String
}

// MARK: - Reviews
struct Review: Identifiable, Codable, Sendable {
    let id: String  // uuid
    let job_id: String  // Changed from Int to String (uuid)
    let reviewer_id: String  // uuid
    let reviewed_id: String  // uuid
    let rating: Int
    let comment: String?
    let created_at: String?
}

struct ReviewInsert: Codable, Sendable {
    let job_id: String  // Changed from Int to String (uuid)
    let reviewer_id: String  // uuid
    let reviewed_id: String  // uuid
    let rating: Int
    let comment: String?
}

/// Review enriched with the reviewer's name/avatar, for display in the
/// provider profile Reviews tab. Assembled in PublicProfileNetworking.fetchReviews.
struct ProviderReview: Identifiable, Sendable {
    let id: String
    let rating: Int
    let comment: String?
    let created_at: String?
    let reviewer_name: String?
    let reviewer_avatar: String?

    var displayName: String { reviewer_name ?? "Anonymous" }

    var formattedDate: String {
        guard let created_at else { return "" }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var date = formatter.date(from: created_at)
        if date == nil {
            formatter.formatOptions = [.withInternetDateTime]
            date = formatter.date(from: created_at)
        }
        guard let date else { return "" }
        let f = DateFormatter()
        f.dateStyle = .medium
        return f.string(from: date)
    }
}

/// Raw review row used internally for decoding before enrichment.
struct ReviewRow: Codable, Sendable {
    let id: String
    let rating: Int
    let comment: String?
    let created_at: String?
    let reviewer_id: String?
}

// MARK: - Service Categories
struct ServiceCategory: Identifiable, Codable, Sendable {
    let id: String
    let name: String
    let description: String?
    let icon: String?
    let created_at: String?
    
    // For UI display
    var displayIcon: String {
        return icon ?? "🔧"
    }
}

// MARK: - Hardcoded Service Categories (for better performance)
struct HardcodedServiceCategory: Identifiable {
    let id: String
    let name: String
    let bengaliName: String
    let icon: String
    let color: String
    
    static let categories: [HardcodedServiceCategory] = [
        HardcodedServiceCategory(
            id: "1",
            name: "Home Repair & Maintenance",
            bengaliName: "ঘর মেরামত ও রক্ষণাবেক্ষণ",
            icon: "🔧",
            color: "blue"
        ),
        HardcodedServiceCategory(
            id: "2",
            name: "Home Services",
            bengaliName: "ঘরোয়া সেবা",
            icon: "🏠",
            color: "green"
        ),
        HardcodedServiceCategory(
            id: "3",
            name: "Education & Tutoring",
            bengaliName: "শিক্ষা ও গৃহশিক্ষকতা",
            icon: "📚",
            color: "purple"
        ),
        HardcodedServiceCategory(
            id: "4",
            name: "Technology & IT",
            bengaliName: "প্রযুক্তি ও আইটি",
            icon: "💻",
            color: "indigo"
        ),
        HardcodedServiceCategory(
            id: "5",
            name: "Automotive",
            bengaliName: "গাড়ি ও যানবাহন",
            icon: "🚗",
            color: "red"
        ),
        HardcodedServiceCategory(
            id: "6",
            name: "Personal Services",
            bengaliName: "ব্যক্তিগত সেবা",
            icon: "✂️",
            color: "pink"
        ),
        HardcodedServiceCategory(
            id: "7",
            name: "Construction & Renovation",
            bengaliName: "নির্মাণ ও সংস্কার",
            icon: "🔨",
            color: "orange"
        ),
        HardcodedServiceCategory(
            id: "8",
            name: "Food & Catering",
            bengaliName: "খাদ্য ও ক্যাটারিং",
            icon: "🍽️",
            color: "yellow"
        ),
        HardcodedServiceCategory(
            id: "9",
            name: "Mobile & Electronics",
            bengaliName: "মোবাইল ও ইলেকট্রনিক্স",
            icon: "📱",
            color: "teal"
        ),
        HardcodedServiceCategory(
            id: "10",
            name: "Events & Entertainment",
            bengaliName: "অনুষ্ঠান ও বিনোদন",
            icon: "🎉",
            color: "cyan"
        )
    ]
    
    static func getCategoryNames() -> [String] {
        return categories.map { $0.name }
    }
    
    static func getCategory(by name: String) -> HardcodedServiceCategory? {
        return categories.first { $0.name == name }
    }
}

struct ServiceCategoryInsert: Codable, Sendable {
    let name: String
    let description: String?
    let icon: String?
}

// MARK: - Request/Response Models

struct CreateBidRequest: Codable {
    let job_id: String
    let amount: Int
    let proposal: String
    let comments: String?
    let timeline: String
}

struct ProposalRequest: Sendable {
    let job_id: String  // Changed from Int to String (uuid)
    let proposal_text: String
    let estimated_budget: Int
    let estimated_timeline: String
}

// MARK: - Notification Models
// MARK: - Enhanced Notification System

// Notification state enum
enum NotificationState: String, Codable, CaseIterable {
    case unread
    case read
    case archived
}

// Interaction type enum
enum InteractionType: String, Codable, CaseIterable {
    case interactive
    case informational
}

// NotificationPriority is defined above in the Unified Notification System section

// Notification action
struct NotificationAction: Identifiable, Codable, Sendable {
    let id = UUID().uuidString
    let type: String // "accept", "reject", "view", etc.
    let label: String
    let style: String // "primary", "secondary", "destructive"

    // Additional properties referenced in the UI components
    let title: String
    let systemIcon: String?

    init(type: String, label: String, style: String, title: String? = nil, systemIcon: String? = nil) {
        self.type = type
        self.label = label
        self.style = style
        self.title = title ?? label
        self.systemIcon = systemIcon
    }
}

// Action data structure
struct ActionData: Codable, Sendable {
    let interest_id: String?
    let provider_name: String?
    let job_title: String?
    let interest_message: String?
    let actions: [NotificationAction]?
}

// Temporary test model to isolate decoding issues
struct SimpleTestNotification: Identifiable, Codable, Sendable {
    let id: String
    let type: String?
    let title: String?
    let message: String?
    let created_at: String
}

// Enhanced notification model matching the new database schema
struct EnhancedNotification: Identifiable, Codable, Sendable {
    let id: String
    let type: String // "interest_request", "deal_created", "completion_request"
    let title: String
    let message: String
    let job_id: String?
    let from_user_id: String?
    let to_user_id: String
    let notification_state: NotificationState
    let interaction_type: InteractionType
    let action_data: ActionData?
    let priority: NotificationPriority
    let avatar_url: String?
    let grouped_date: String // ISO date string
    let read_at: String?
    let archived_at: String?
    let completion_request_id: String?
    let created_at: String
    
    // Related data (populated separately) - immutable for Sendable conformance
    let job: Job?
    let from_profile: Profile?
    
    // Helper computed properties
    var isUnread: Bool { notification_state == .unread }
    var isRead: Bool { notification_state == .read }
    var isArchived: Bool { notification_state == .archived }
    var isInteractive: Bool { interaction_type == .interactive }
    var isHighPriority: Bool { priority == .high }
    
    var hasActions: Bool {
        return action_data?.actions?.isEmpty == false
    }
    
    var timeAgo: String {
        guard let date = ISO8601DateFormatter().date(from: created_at) else {
            return "Unknown time"
        }
        return RelativeDateTimeFormatter().localizedString(for: date, relativeTo: Date())
    }
    
    // MARK: - Custom Codable Implementation
    
    // Custom decoding to handle database schema differences
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Handle UUID to String conversion for id - simplified approach
        do {
            // Try String first
            self.id = try container.decode(String.self, forKey: .id)
        } catch {
            // If that fails, try UUID
            do {
                let uuid = try container.decode(UUID.self, forKey: .id)
                self.id = uuid.uuidString
            } catch {
                throw DecodingError.keyNotFound(CodingKeys.id, DecodingError.Context(codingPath: [CodingKeys.id], debugDescription: "Missing id field"))
            }
        }
        
        self.type = try container.decodeIfPresent(String.self, forKey: .type) ?? "unknown"
        self.title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        self.message = try container.decodeIfPresent(String.self, forKey: .message) ?? ""
        
        // Handle UUID fields with flexible conversion
        self.job_id = Self.decodeUUIDAsString(container, key: .job_id)
        self.from_user_id = Self.decodeUUIDAsString(container, key: .from_user_id)
        
        // Handle to_user_id vs user_id fallback
        if let toUserId = Self.decodeUUIDAsString(container, key: .to_user_id) {
            self.to_user_id = toUserId
        } else if let userId = Self.decodeUUIDAsString(container, key: .user_id) {
            self.to_user_id = userId
        } else {
            self.to_user_id = ""
        }
        
        // Handle notification state with fallback to read boolean
        if let stateString = try? container.decodeIfPresent(String.self, forKey: .notification_state),
           let state = NotificationState(rawValue: stateString) {
            self.notification_state = state
        } else if let readBool = try? container.decodeIfPresent(Bool.self, forKey: .read) {
            self.notification_state = readBool ? .read : .unread
        } else {
            self.notification_state = .unread
        }
        
        // Handle interaction type with fallback
        if let interactionString = try? container.decodeIfPresent(String.self, forKey: .interaction_type),
           let interaction = InteractionType(rawValue: interactionString) {
            self.interaction_type = interaction
        } else {
            self.interaction_type = .informational
        }
        
        // Handle action_data - can be null, empty object {}, or valid ActionData
        if container.contains(.action_data) {
            do {
                self.action_data = try container.decodeIfPresent(ActionData.self, forKey: .action_data)
            } catch {
                // If decoding fails (e.g., empty object {}), set to nil
                print("⚠️ Warning: Failed to decode action_data, setting to nil: \(error)")
                self.action_data = nil
            }
        } else {
            self.action_data = nil
        }
        
        // Handle priority with fallback
        if let priorityString = try? container.decodeIfPresent(String.self, forKey: .priority),
           let priorityEnum = NotificationPriority(rawValue: priorityString) {
            self.priority = priorityEnum
        } else {
            self.priority = .normal
        }
        
        self.avatar_url = try? container.decodeIfPresent(String.self, forKey: .avatar_url)
        
        // Handle grouped_date with fallback to created_at date
        if let groupedDateString = try? container.decodeIfPresent(String.self, forKey: .grouped_date) {
            self.grouped_date = groupedDateString
        } else {
            let createdAtString = try container.decode(String.self, forKey: .created_at)
            self.grouped_date = String(createdAtString.prefix(10))
        }
        
        self.read_at = try? container.decodeIfPresent(String.self, forKey: .read_at)
        self.archived_at = try? container.decodeIfPresent(String.self, forKey: .archived_at)
        self.completion_request_id = Self.decodeUUIDAsString(container, key: .completion_request_id)
        self.created_at = try container.decode(String.self, forKey: .created_at)
        
        // Initialize related data as nil
        self.job = nil
        self.from_profile = nil
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encode(type, forKey: .type)
        try container.encode(title, forKey: .title)
        try container.encode(message, forKey: .message)
        try container.encodeIfPresent(job_id, forKey: .job_id)
        try container.encodeIfPresent(from_user_id, forKey: .from_user_id)
        try container.encode(to_user_id, forKey: .to_user_id)
        try container.encode(notification_state.rawValue, forKey: .notification_state)
        try container.encode(interaction_type.rawValue, forKey: .interaction_type)
        try container.encodeIfPresent(action_data, forKey: .action_data)
        try container.encode(priority.rawValue, forKey: .priority)
        try container.encodeIfPresent(avatar_url, forKey: .avatar_url)
        try container.encode(grouped_date, forKey: .grouped_date)
        try container.encodeIfPresent(read_at, forKey: .read_at)
        try container.encodeIfPresent(archived_at, forKey: .archived_at)
        try container.encodeIfPresent(completion_request_id, forKey: .completion_request_id)
        try container.encode(created_at, forKey: .created_at)
    }
    
    private static func decodeUUIDAsString<T: CodingKey>(_ container: KeyedDecodingContainer<T>, key: T) -> String? {
        // Try String first
        if let stringValue = try? container.decodeIfPresent(String.self, forKey: key) {
            return stringValue
        }
        
        // Try UUID if String fails
        if let uuidValue = try? container.decodeIfPresent(UUID.self, forKey: key) {
            return uuidValue.uuidString
        }
        
        return nil
    }
    
    private enum CodingKeys: String, CodingKey {
        case id, type, title, message, job_id, from_user_id, to_user_id, user_id
        case notification_state, interaction_type, action_data, priority, avatar_url
        case grouped_date, read_at, archived_at, completion_request_id, created_at, read
    }
}

// Grouped notifications for time-based display
struct NotificationGroup: Identifiable {
    let id: String
    let title: String // "Today", "Yesterday", etc.
    let count: Int
    let notifications: [EnhancedNotification]
    let date: Date
}

// Legacy Notification model (for backward compatibility)
struct Notification: Identifiable, Codable, Sendable {
    let id: String
    let type: String // "interest_request", "interest_rejected", "offer_received", "completion_request", "completion_approved", "completion_rejected"
    let job_id: String
    let from_user_id: String?
    let to_user_id: String
    let status: String // "pending", "accepted", "rejected"
    let message: String?
    let offer_data: OfferData?
    let completion_request_id: String?
    let actioned_at: String?
    let created_at: String
    
    // Related data (populated separately)
    var job: Job?
    var from_profile: Profile?
    
    // Helper properties
    var isPending: Bool {
        return status == "pending"
    }
    
    var isInterestRequest: Bool {
        return type == "interest_request" || type == "show_interest"
    }
    
    var isOfferReceived: Bool {
        return type == "offer_received"
    }
    
    var isCompletionRequest: Bool {
        return type == "completion_request"
    }
    
    var isCompletionApproved: Bool {
        return type == "completion_approved"
    }
    
    var isCompletionRejected: Bool {
        return type == "completion_rejected"
    }
    
    var isInterestRejected: Bool {
        return type == "interest_rejected"
    }
}

// MARK: - Offer Data
struct OfferData: Codable, Sendable {
    let amount: Int
    let terms: String?
    let timeline: String?
}

// MARK: - Job Interest
struct JobInterest: Identifiable, Codable, Sendable {
    let id: String
    let job_id: String
    let provider_id: String
    let status: String
    let message: String?
    let created_at: String
    let actioned_at: String?
}

// MARK: - Enriched Job Interest (for real-time notifications)
struct EnrichedJobInterest: Identifiable, Codable, Sendable {
    let id: String
    let job_id: String
    let provider_id: String
    let status: String
    let message: String?
    let created_at: String
    let actioned_at: String?
    
    // Job information
    let job_title: String
    let job_client_id: String
    let job_budget: Int?
    let job_location: String?
    
    // Provider information  
    let provider_name: String?
    let provider_avatar_url: String?
    let provider_rating: Double?
    
    // Computed properties
    var isForCurrentUser: Bool {
        // This will be set based on current user context
        return true // Placeholder - will be filtered in query
    }
}

// MARK: - NotificationItem (Legacy - for compatibility)
struct NotificationItem: Identifiable, Codable, Sendable {
    let id: String
    let user_id: String
    let title: String
    let message: String
    let type: String
    let read: Bool
    let related_job_id: String?
    let created_at: String?
}

// MARK: - Proposal/Bid Models for Application Status
struct BidResponse: Codable, Identifiable {
    let id: String
    let job_id: String
    let provider_id: String
    let amount: Int
    let message: String?
    let status: String
    let created_at: String
}


// MARK: - Additional Networking Data Structures

struct UpdateData: Codable, Sendable {
    let status: String
    let responded_at: String
}

struct DealNotificationData: Codable, Sendable {
    let type: String
    let job_id: String
    let from_user_id: String
    let to_user_id: String
    let status: String
    let message: String
    // Removed conversation_id field - notifications table doesn't have this column
    let deal_offer_id: String
}

struct BidData: Codable, Sendable {
    let job_id: String
    let provider_id: String
    let amount: Int
    let proposal: String
    let comments: String?
    let timeline: String
}

// Enhanced notification update structures
struct NotificationStateUpdate: Codable, Sendable {
    let notification_state: NotificationState
    let read_at: String?
    let archived_at: String?
}

struct EnhancedNotificationInsert: Codable, Sendable {
    let type: String
    let title: String
    let message: String
    let job_id: String?
    let from_user_id: String?
    let to_user_id: String
    let notification_state: NotificationState
    let interaction_type: InteractionType
    let action_data: ActionData?
    let priority: NotificationPriority
    let avatar_url: String?
    let grouped_date: String
}

// Legacy structures (for backward compatibility)
struct NotificationUpdate: Codable, Sendable {
    let status: String
    let actioned_at: String
}

struct NotificationInsert: Codable, Sendable {
    let type: String
    let job_id: String
    let from_user_id: String
    let to_user_id: String
    let message: String
    let offer_data: OfferData?
}

struct ConversationData: Codable, Sendable {
    let job_id: String
    let client_id: String
    let provider_id: String
    let status: String
}


// Removed InterestUpdateData - using local structs in Networking.swift instead

struct RPCParams: Codable, Sendable {
    let user_id: String
}

struct UnreadCountsRPCParams: Encodable, Sendable {
    let conversation_ids: [String]
    let user_id: String
}

// Enhanced notification data for creation
struct EnhancedNotificationData: Codable, Sendable {
    let type: String
    let title: String
    let message: String
    let job_id: String?
    let from_user_id: String?
    let to_user_id: String
    let interaction_type: InteractionType
    let action_data: ActionData?
    let priority: NotificationPriority
    let avatar_url: String?
    
    init(type: String, title: String, message: String, job_id: String? = nil, from_user_id: String? = nil, to_user_id: String, interaction_type: InteractionType = .informational, action_data: ActionData? = nil, priority: NotificationPriority = .normal, avatar_url: String? = nil) {
        self.type = type
        self.title = title
        self.message = message
        self.job_id = job_id
        self.from_user_id = from_user_id
        self.to_user_id = to_user_id
        self.interaction_type = interaction_type
        self.action_data = action_data
        self.priority = priority
        self.avatar_url = avatar_url
    }
}

// Legacy notification data (for backward compatibility)
struct NotificationData: Codable, Sendable {
    let type: String
    let job_id: String
    let from_user_id: String
    let to_user_id: String
    let message: String
    let offer_data: OfferData?
    
    init(type: String, job_id: String, from_user_id: String, to_user_id: String, message: String, offer_data: OfferData? = nil) {
        self.type = type
        self.job_id = job_id
        self.from_user_id = from_user_id
        self.to_user_id = to_user_id
        self.message = message
        self.offer_data = offer_data
    }
}

// MARK: - Deal Update Structures
struct DealCompletionUpdate: Codable, Sendable {
    let completion_status: String
    let client_completion_requested: Bool?
    let provider_completion_requested: Bool?
    let client_completion_requested_at: String?
    let provider_completion_requested_at: String?
    
    nonisolated init(isClient: Bool) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        self.completion_status = "pending_approval"
        if isClient {
            self.client_completion_requested = true
            self.client_completion_requested_at = timestamp
            self.provider_completion_requested = nil
            self.provider_completion_requested_at = nil
        } else {
            self.provider_completion_requested = true
            self.provider_completion_requested_at = timestamp
            self.client_completion_requested = nil
            self.client_completion_requested_at = nil
        }
    }
}

struct DealStatusUpdate: Codable, Sendable {
    let status: String
    let completion_status: String
    let completed_at: String
    
    nonisolated init() {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        self.status = "completed"
        self.completion_status = "completed"
        self.completed_at = timestamp
    }
}

struct DealResetUpdate: Codable, Sendable {
    let completion_status: String
    let client_completion_requested: Bool
    let provider_completion_requested: Bool
    let client_completion_requested_at: String?
    let provider_completion_requested_at: String?
    
    nonisolated init() {
        self.completion_status = "in_progress"
        self.client_completion_requested = false
        self.provider_completion_requested = false
        self.client_completion_requested_at = nil
        self.provider_completion_requested_at = nil
    }
}

struct InterestData: Codable, Sendable {
    let job_id: String
    let provider_id: String
}

// MARK: - Presence & Typing Indicators

struct TypingIndicator: Codable, Sendable {
    let conversation_id: String
    let user_id: String
    let user_name: String
    let is_typing: Bool
    let timestamp: String
}

struct PresenceUpdate: Codable, Sendable {
    let user_id: String
    let is_online: Bool
    let last_seen_at: String?
}

struct ReadReceipt: Codable, Sendable {
    let message_id: String
    let user_id: String
    let read_at: String
}

// MARK: - Dashboard & Completion Models

struct DashboardData: Codable, Sendable {
    let user_type: String
    let active_deals_count: Int
    let completed_deals_count: Int
    let pending_completion_requests: Int
    let total_earnings: Double
    let total_spent: Double
    let average_rating: Double
    let recent_deals: [DashboardDeal]?
}

struct DashboardDeal: Identifiable, Codable, Sendable {
    let id: String
    let job_title: String
    let agreed_amount: Int
    let completion_status: String
    let created_at: String
    let other_party_name: String?
}

struct CompletionRequest: Identifiable, Codable, Sendable {
    let id: String
    let deal_id: String
    let requester_id: String
    let requester_type: String // "client" or "provider"
    let request_message: String?
    let status: String // "pending", "approved", "rejected"
    let responded_by: String?
    let responded_at: String?
    let response_message: String?
    let created_at: String
    let updated_at: String
    
    // Related data
    var deals: Deal?  // Note: singular 'deal' but query uses 'deals' - Supabase naming
    var requester_profile: SimpleProfile?
    var responder_profile: SimpleProfile?
}

struct CompletionRequestInsert: Codable, Sendable {
    let deal_id: String
    let requester_id: String
    let requester_type: String
    let request_message: String?
}

struct CompletionRequestResponse: Codable, Sendable {
    let status: String // "approved" or "rejected"
    let response_message: String?
    let responded_by: String
    let responded_at: String
}

struct DealWithCompletion: Identifiable, Codable, Sendable {
    let id: String
    let job_id: String
    let client_id: String
    let provider_id: String
    let agreed_amount: Int
    let agreed_terms: String?
    let timeline: String?
    let status: String
    let completion_status: String
    let client_completion_requested: Bool
    let provider_completion_requested: Bool
    let client_completion_requested_at: String?
    let provider_completion_requested_at: String?
    let created_at: String?
    let completed_at: String?
    
    // Related data
    var job: Job?
    var client_profile: SimpleProfile?
    var provider_profile: SimpleProfile?
    var pending_completion_requests: [CompletionRequest]?
}

// MARK: - Chat Models
// Core messaging data structures

struct Conversation: Codable, Sendable, Identifiable {
    let id: String
    let job_id: String
    let client_id: String
    let provider_id: String
    let status: String
    let client_unread_count: Int
    let provider_unread_count: Int
    let created_at: String
    let updated_at: String
}

// ConversationWithDetails moved to MessagesNetworking.swift to resolve compilation order issues

struct ChatMessage: Codable, Sendable, Identifiable {
    let id: String
    let conversation_id: String
    let sender_id: String
    let content: String
    let message_type: String // "text", "image", "negotiation", etc.
    let attachment_url: String?
    let negotiation_data: [String: Any]?
    let read_at: String?
    let created_at: String
    let updated_at: String?
    
    // Manual initializer for dictionary-based creation
    init(id: String, conversation_id: String, sender_id: String, content: String, 
         message_type: String, attachment_url: String? = nil, negotiation_data: [String: Any]? = nil, 
         read_at: String? = nil, created_at: String, updated_at: String? = nil) {
        self.id = id
        self.conversation_id = conversation_id
        self.sender_id = sender_id
        self.content = content
        self.message_type = message_type
        self.attachment_url = attachment_url
        self.negotiation_data = negotiation_data
        self.read_at = read_at
        self.created_at = created_at
        self.updated_at = updated_at
    }
    
    // Custom coding keys to handle the negotiation_data JSON field
    enum CodingKeys: String, CodingKey {
        case id, conversation_id, sender_id, content, message_type, attachment_url, read_at, created_at, updated_at
        case negotiation_data
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(String.self, forKey: .id)
        conversation_id = try container.decode(String.self, forKey: .conversation_id)
        sender_id = try container.decode(String.self, forKey: .sender_id)
        content = try container.decode(String.self, forKey: .content)
        message_type = try container.decode(String.self, forKey: .message_type)
        attachment_url = try container.decodeIfPresent(String.self, forKey: .attachment_url)
        read_at = try container.decodeIfPresent(String.self, forKey: .read_at)
        created_at = try container.decode(String.self, forKey: .created_at)
        updated_at = try container.decodeIfPresent(String.self, forKey: .updated_at)
        
        // Handle negotiation_data as flexible JSON
        if let negotiationDataString = try container.decodeIfPresent(String.self, forKey: .negotiation_data),
           let data = negotiationDataString.data(using: .utf8),
           let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            negotiation_data = jsonObject
        } else {
            negotiation_data = nil
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encode(conversation_id, forKey: .conversation_id)
        try container.encode(sender_id, forKey: .sender_id)
        try container.encode(content, forKey: .content)
        try container.encode(message_type, forKey: .message_type)
        try container.encodeIfPresent(attachment_url, forKey: .attachment_url)
        try container.encodeIfPresent(read_at, forKey: .read_at)
        try container.encode(created_at, forKey: .created_at)
        try container.encodeIfPresent(updated_at, forKey: .updated_at)
        
        // Encode negotiation_data as JSON string
        if let negotiationData = negotiation_data,
           let jsonData = try? JSONSerialization.data(withJSONObject: negotiationData),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            try container.encode(jsonString, forKey: .negotiation_data)
        }
    }
}

// MARK: - Type Aliases for NotificationsView
typealias NotificationPriorityLevel = NotificationPriority

// MARK: - Usage Notes
/*
 This file contains all database models to avoid duplication.

 Key Points:
 - DatabaseNotificationType is used instead of NotificationType to avoid system conflicts
 - All UUID fields are handled as String types for consistency
 - Custom Codable implementations handle database schema differences
 - Use explicit self. in property assignments to avoid shadowing issues
 */