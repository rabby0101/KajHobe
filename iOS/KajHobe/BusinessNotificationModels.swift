import Foundation

// Simple notification structure for business notifications
struct BusinessNotification: Identifiable, Codable {
    let id: String
    let user_id: String?
    let title: String?
    let message: String?
    let type: String?
    let read: Bool?
    let related_job_id: String?
    let related_proposal_id: String?
    let created_at: String
    let job_id: String?
    let from_user_id: String?
    let to_user_id: String?
    let status: String?
    let offer_data: String? // JSONB as string
    let actioned_at: String?
    let deal_offer_id: String?
    let completion_request_id: String?
    let notification_state: String?
    let interaction_type: String?
    let action_data: String? // JSONB as string
    let grouped_date: String?
    let priority: String?
    let avatar_url: String?
    let read_at: String?
    let archived_at: String?

    // Computed properties
    var isUnread: Bool {
        return notification_state == "unread" || (notification_state == nil && read == false)
    }

    var displayTitle: String {
        return title ?? "Notification"
    }

    var displayMessage: String {
        return message ?? ""
    }

    var typeIcon: String {
        guard let type = type else { return "bell" }

        switch type {
        case let t where t.contains("deal"):
            return "handshake"
        case let t where t.contains("message"):
            return "message"
        case let t where t.contains("interest"):
            return "heart"
        case let t where t.contains("completion"):
            return "checkmark.circle"
        case let t where t.contains("offer"):
            return "doc.text"
        default:
            return "bell"
        }
    }

    var typeColor: String {
        guard let type = type else { return "gray" }

        switch type {
        case let t where t.contains("deal"):
            return "green"
        case let t where t.contains("message"):
            return "blue"
        case let t where t.contains("interest"):
            return "pink"
        case let t where t.contains("completion"):
            return "orange"
        case let t where t.contains("offer"):
            return "purple"
        default:
            return "gray"
        }
    }
}