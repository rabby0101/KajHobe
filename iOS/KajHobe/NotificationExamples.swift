//
//  NotificationExamples.swift
//  KajHobe
//
//  Example usage of interactive notifications
//

import Foundation

extension PushNotificationManager {
    
    // MARK: - Example Usage Methods
    
    /// Example: Send a notification when someone shows interest in a job
    func sendInterestNotification(fromUser: Profile, jobTitle: String) {
        scheduleInteractiveNotification(
            title: "New Interest Request",
            body: "\(fromUser.full_name ?? "Someone") is interested in your job: \(jobTitle)",
            type: .interestRequest,
            userId: fromUser.id,
            notificationId: UUID().uuidString
        )
    }
    
    /// Example: Send a notification when someone sends a message
    func sendMessageNotification(fromUser: Profile, message: String, conversationId: String) {
        let truncatedMessage = message.count > 50 ? String(message.prefix(50)) + "..." : message
        scheduleInteractiveNotification(
            title: "New Message from \(fromUser.full_name ?? "User")",
            body: truncatedMessage,
            type: .newMessage,
            userId: fromUser.id,
            conversationId: conversationId
        )
    }
    
    /// Example: Send a notification when someone makes an offer
    func sendOfferNotification(fromUser: Profile, amount: Double, jobTitle: String, offerId: String) {
        scheduleInteractiveNotification(
            title: "New Offer Received",
            body: "\(fromUser.full_name ?? "Someone") offered $\(amount) for \(jobTitle)",
            type: .offerReceived,
            userId: fromUser.id,
            offerId: offerId
        )
    }
    
    /// Example: Send a notification when someone applies for a job
    func sendJobApplicationNotification(fromUser: Profile, jobTitle: String) {
        scheduleInteractiveNotification(
            title: "New Job Application",
            body: "\(fromUser.full_name ?? "Someone") applied for: \(jobTitle)",
            type: .jobApplication,
            userId: fromUser.id
        )
    }
    
    /// Example: Send a notification when someone views your profile
    func sendProfileViewNotification(fromUser: Profile) {
        scheduleInteractiveNotification(
            title: "Profile Viewed",
            body: "\(fromUser.full_name ?? "Someone") viewed your profile",
            type: .profileView,
            userId: fromUser.id
        )
    }
}

/* 

USAGE EXAMPLES IN YOUR OTHER CODE:

// When someone shows interest in a job:
PushNotificationManager.shared.sendInterestNotification(
    fromUser: interestedUser, 
    jobTitle: "iOS Developer Position"
)

// When someone sends a message:
PushNotificationManager.shared.sendMessageNotification(
    fromUser: sender,
    message: "Hi, I'm interested in your job posting!",
    conversationId: "conv-123"
)

// When someone makes an offer:
PushNotificationManager.shared.sendOfferNotification(
    fromUser: bidder,
    amount: 500.0,
    jobTitle: "Website Design",
    offerId: "offer-456"
)

// When someone applies for a job:
PushNotificationManager.shared.sendJobApplicationNotification(
    fromUser: applicant,
    jobTitle: "Graphic Designer"
)

// When someone views your profile:
PushNotificationManager.shared.sendProfileViewNotification(
    fromUser: profileViewer
)

*/