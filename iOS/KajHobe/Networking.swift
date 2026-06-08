import Foundation
import UIKit
import Supabase
import Auth
import PostgREST
import Combine

// MARK: - Main Networking Coordinator
// This class coordinates between the specialized networking classes
class Networking: ObservableObject {
    static let shared = Networking()
    private init() {}
    
    @Published var objectWillChange = ObservableObjectPublisher()
    
    // MARK: - Specialized Networking Classes
    private let baseNetworking = BaseNetworking()
    private let jobsNetworking = JobsNetworking.shared
    private let dealsNetworking = DealsNetworking.shared
    private let profileNetworking = ProfileNetworking.shared
    private let notificationsNetworking = NotificationsNetworking.shared
    private let messagesNetworking = MessagesNetworking.shared
    
    // MARK: - Connection Testing
    func testConnection() async throws -> Bool {
        return try await baseNetworking.testConnection()
    }
    
    func testDatabaseConnection() async throws {
        try await baseNetworking.testDatabaseConnection()
    }
    
    // MARK: - Cache Management (Removed)
    // Cache functionality has been removed from the application
    
    // MARK: - Jobs (Delegated to JobsNetworking)
    func fetchJobs(forceRefresh: Bool = false) async throws -> [Job] {
        return try await jobsNetworking.fetchJobs(forceRefresh: forceRefresh)
    }
    
    func fetchMyJobs() async throws -> [Job] {
        return try await jobsNetworking.fetchMyJobs()
    }
    
    func deleteJob(jobId: String) async throws {
        try await jobsNetworking.deleteJob(jobId: jobId)
    }
    
    func fetchBids(for jobId: String) async throws -> [Bid] {
        return try await jobsNetworking.fetchBids(for: jobId)
    }
    
    func createBid(_ request: CreateBidRequest) async throws -> Bid {
        return try await jobsNetworking.createBid(request)
    }
    
    func fetchProposalStatus(for jobId: String, providerId: String) async throws -> String? {
        return try await jobsNetworking.fetchProposalStatus(for: jobId, providerId: providerId)
    }
    
    func checkApplicationStatus(jobId: String, userId: String) async throws -> String? {
        return try await jobsNetworking.checkApplicationStatus(jobId: jobId, userId: userId)
    }
    
    func getJobCountForCategory(_ categoryName: String, from jobs: [Job]) -> Int {
        return jobsNetworking.getJobCountForCategory(categoryName, from: jobs)
    }
    
    
    // MARK: - Deals (Delegated to DealsNetworking)
    func createDealOffer(conversationId: String, amount: Int, terms: String?, timeline: String?) async throws -> DealOffer {
        return try await dealsNetworking.createDealOffer(conversationId: conversationId, amount: amount, terms: terms, timeline: timeline)
    }
    
    func respondToDealOffer(dealOfferId: String, response: String, message: String?) async throws -> DealOffer {
        return try await dealsNetworking.respondToDealOffer(dealOfferId: dealOfferId, response: response, message: message)
    }
    
    func getDealCount(providerId: String, jobId: String) async throws -> Int {
        return try await dealsNetworking.getDealCount(providerId: providerId, jobId: jobId)
    }
    
    func getAllDealsForJob(providerId: String, jobId: String) async throws -> [DealOffer] {
        return try await dealsNetworking.getAllDealsForJob(providerId: providerId, jobId: jobId)
    }
    
    func hasPendingDeal(providerId: String, jobId: String) async throws -> Bool {
        return try await dealsNetworking.hasPendingDeal(providerId: providerId, jobId: jobId)
    }
    
    func hasAcceptedDeal(providerId: String, jobId: String) async throws -> Bool {
        return try await dealsNetworking.hasAcceptedDeal(providerId: providerId, jobId: jobId)
    }
    
    func fetchDealOffers(conversationId: String) async throws -> [DealOffer] {
        return try await dealsNetworking.fetchDealOffers(conversationId: conversationId)
    }
    
    func fetchMyDeals() async throws -> [Deal] {
        return try await dealsNetworking.fetchMyDeals()
    }
    
    func requestTaskCompletion(dealId: String, message: String?) async throws -> CompletionRequest {
        return try await dealsNetworking.requestTaskCompletion(dealId: dealId, message: message)
    }
    
    func respondToCompletionRequest(requestId: String, approve: Bool, message: String?) async throws {
        try await dealsNetworking.respondToCompletionRequest(requestId: requestId, approve: approve, message: message)
    }
    
    func fetchDashboardData(forceRefresh: Bool = false) async throws -> DashboardData {
        return try await dealsNetworking.fetchDashboardData(forceRefresh: forceRefresh)
    }
    
    func fetchActiveDeals(forceRefresh: Bool = false) async throws -> [Deal] {
        return try await dealsNetworking.fetchActiveDeals(forceRefresh: forceRefresh)
    }
    
    func fetchPendingCompletionRequests(forceRefresh: Bool = false) async throws -> [CompletionRequest] {
        return try await dealsNetworking.fetchPendingCompletionRequests(forceRefresh: forceRefresh)
    }
    
    // MARK: - Profile (Delegated to ProfileNetworking)
    func ensureUserProfile() async throws -> Profile {
        return try await profileNetworking.ensureUserProfile()
    }
    
    func getCurrentUserProfile() async throws -> Profile {
        return try await profileNetworking.getCurrentUserProfile()
    }
    
    func fetchProfile(userId: String) async throws -> Profile {
        return try await profileNetworking.fetchProfile(userId: userId)
    }
    
    func updateProfile(_ profile: Profile) async throws -> Profile {
        return try await profileNetworking.updateProfile(profile)
    }
    
    func updateUserPresence(isOnline: Bool) async throws {
        try await profileNetworking.updateUserPresence(isOnline: isOnline)
    }
    
    func calculateAverageResponseTime(userId: String) async throws -> Int? {
        return try await profileNetworking.calculateAverageResponseTime(userId: userId)
    }
    
    // MARK: - Notifications (Delegated to NotificationsNetworking)
    func fetchNotifications() async throws -> [NotificationItem] {
        return try await notificationsNetworking.fetchNotifications()
    }
    
    func markNotificationAsRead(notificationId: String) async throws {
        try await notificationsNetworking.markNotificationAsRead(notificationId: notificationId)
    }
    
    func createNotification(type: String, jobId: String, fromUserId: String, toUserId: String, message: String, offerData: OfferData? = nil) async throws {
        try await notificationsNetworking.createNotification(type: type, jobId: jobId, fromUserId: fromUserId, toUserId: toUserId, message: message, offerData: offerData)
    }
    
    func fetchPendingNotificationCount() async throws -> Int {
        return try await notificationsNetworking.fetchPendingNotificationCount()
    }
    
    func fetchInterestNotifications(forceRefresh: Bool = false) async throws -> [Notification] {
        return try await notificationsNetworking.fetchInterestNotifications(forceRefresh: forceRefresh)
    }
    
    // MARK: - Real-time Job Interest Notifications
    func fetchEnrichedJobInterests() async throws -> [EnrichedJobInterest] {
        return try await notificationsNetworking.fetchEnrichedJobInterests()
    }
    
    func subscribeToJobInterests(onNewInterest: @escaping (EnrichedJobInterest) -> Void) async throws -> RealtimeChannelV2 {
        return try await notificationsNetworking.subscribeToJobInterests(onNewInterest: onNewInterest)
    }
    
    func getInterestStatus(jobId: String) async throws -> String? {
        return try await notificationsNetworking.getInterestStatus(jobId: jobId)
    }
    
    func hasShownInterest(jobId: String) async throws -> Bool {
        return try await notificationsNetworking.hasShownInterest(jobId: jobId)
    }
    
    func getInterestCooldownInfo(jobId: String) async throws -> (canShowInterest: Bool, remainingCooldown: TimeInterval?, interestCount: Int, lastStatus: String?) {
        return try await notificationsNetworking.getInterestCooldownInfo(jobId: jobId)
    }
    
    func showInterest(jobId: String) async throws {
        try await notificationsNetworking.showInterest(jobId: jobId)
    }
    
    func respondToInterest(notificationId: String, accept: Bool) async throws {
        try await notificationsNetworking.respondToInterest(notificationId: notificationId, accept: accept)
    }
    
    func clearNotification(notificationId: String) async throws {
        try await notificationsNetworking.clearNotification(notificationId: notificationId)
    }
    
    func clearAllNotifications() async throws {
        try await notificationsNetworking.clearAllNotifications()
    }
    
    // MARK: - Messages (Disabled)
    // All messaging functionality has been disabled
    
    func fetchConversations(userId: String, forceRefresh: Bool = false) async throws -> [ConversationWithDetails] {
        return try await MessagesNetworking.shared.fetchConversations(userId: userId, forceRefresh: forceRefresh)
    }

    func setConversationArchived(conversationId: String, userId: String, isClient: Bool, archived: Bool) async throws {
        try await MessagesNetworking.shared.setConversationArchived(
            conversationId: conversationId, userId: userId, isClient: isClient, archived: archived
        )
    }

    func createConversation(jobId: String, clientId: String, providerId: String) async throws -> Any? {
        throw NSError(domain: "MessagingDisabled", code: 0, userInfo: [NSLocalizedDescriptionKey: "Messaging functionality is disabled"])
    }
    
    func fetchMessages(conversationId: String, offset: Int = 0, limit: Int = 50) async throws -> [Any] {
        return []
    }
    
    func sendMessage(
        conversationId: String,
        senderId: String,
        content: String,
        messageType: String = "text",
        attachmentUrl: String? = nil,
        negotiationData: [String: Any]? = nil
    ) async throws -> Any? {
        throw NSError(domain: "MessagingDisabled", code: 0, userInfo: [NSLocalizedDescriptionKey: "Messaging functionality is disabled"])
    }
    
    func markMessagesAsRead(conversationId: String, userId: String) async throws {
        // No-op
    }
    
    func subscribeToConversation(
        conversationId: String,
        onNewMessage: @escaping (Any) -> Void,
        onMessageUpdate: @escaping (Any) -> Void,
        onTypingChange: @escaping ([Any]) -> Void
    ) async {
        // No-op
    }
    
    func unsubscribeFromConversation(conversationId: String) async {
        // No-op
    }
    
    func updateTypingStatus(conversationId: String, userId: String, userName: String, isTyping: Bool) async throws {
        // No-op
    }
    
    func sendDealOfferMessage(
        conversationId: String,
        senderId: String,
        amount: Int,
        terms: String?,
        timeline: String?,
        dealOfferId: String
    ) async throws -> Any? {
        throw NSError(domain: "MessagingDisabled", code: 0, userInfo: [NSLocalizedDescriptionKey: "Messaging functionality is disabled"])
    }
    
    func sendDealResponseMessage(
        conversationId: String,
        senderId: String,
        response: String,
        message: String?,
        dealOfferId: String
    ) async throws -> Any? {
        throw NSError(domain: "MessagingDisabled", code: 0, userInfo: [NSLocalizedDescriptionKey: "Messaging functionality is disabled"])
    }
    
    func searchMessages(query: String, userId: String) async throws -> [Any] {
        return []
    }
    
    func getUnreadMessageCount(userId: String) async throws -> Int {
        return 0
    }
    
    func cleanupMessagesSubscriptions() async {
        // No-op
    }
}
