# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Table of Contents
- [Project Overview](#project-overview)
- [Build System & Commands](#build-system--commands)
  - [iOS Development](#ios-development)
  - [Key Development Commands](#key-development-commands)
  - [Dependencies (SPM)](#dependencies-spm)
- [Code Architecture](#code-architecture)
  - [Core Architecture Pattern](#core-architecture-pattern)
  - [Key Architectural Components](#key-architectural-components)
  - [Data Models Hierarchy](#data-models-hierarchy)
  - [View Architecture](#view-architecture)
  - [Key Features Implementation](#key-features-implementation)
  - [Development Patterns](#development-patterns)
- [Development Environment](#development-environment)
  - [Project Structure](#project-structure)
  - [Multi-Platform Context](#multi-platform-context)
  - [Database Schema](#database-schema)
  - [Testing](#testing)
- [Working with This Codebase](#working-with-this-codebase)
  - [Key Files to Understand First](#key-files-to-understand-first)
  - [Common Development Patterns](#common-development-patterns)
  - [Performance Considerations](#performance-considerations)
- [Real-time Messaging Implementation](#real-time-messaging-implementation)
- [Real-time Notifications Implementation](#real-time-notifications-implementation)

## Project Overview

**KajHobe** (কাজ হবে - "Work will be done" in Bengali) is a comprehensive local service marketplace iOS app for Khulna, Bangladesh. The app connects service seekers with providers through job posting, bidding, messaging, and deal completion workflows.

## Build System & Commands

### iOS Development
- **Primary Build Tool**: Xcode with SPM (Swift Package Manager)
- **Target**: iOS 17.0+
- **Architecture**: SwiftUI with MVVM pattern
- **Main Scheme**: `KajHobe` (configured in KajHobe.xcscheme)

### Key Development Commands
```bash
# Build and run in simulator (use Xcode or xcodebuild)
xcodebuild -project KajHobe.xcodeproj -scheme KajHobe -destination 'platform=iOS Simulator,name=iPhone 16' build

# Run tests
xcodebuild test -project KajHobe.xcodeproj -scheme KajHobe -destination 'platform=iOS Simulator,name=iPhone 16'

# Clean build folder
xcodebuild clean -project KajHobe.xcodeproj -scheme KajHobe
```

### Dependencies (SPM)
- **Supabase Swift SDK** (v2.29.3): Primary backend integration
- **Swift Crypto** (v3.12.3): Cryptographic operations
- **Swift HTTP Types** (v1.4.0): HTTP networking support
- **Additional**: swift-clocks, swift-concurrency-extras, xctest-dynamic-overlay

## Code Architecture

### Core Architecture Pattern
- **MVVM**: Model-View-ViewModel with SwiftUI
- **Networking Layer**: Specialized networking classes for different domains
- **Cache Management**: Multi-level caching with NSCache
- **Real-time Features**: Supabase Realtime subscriptions

### Key Architectural Components

#### 1. Main App Structure
- `KajHobeApp.swift`: App entry point with authentication handling
- `MainTabView.swift`: 5-tab navigation (Jobs, Messages, Post Job, Notifications, Dashboard)
- `AppEntryView`: Authentication state management and presence tracking

#### 2. Database Integration
- `Supabase.swift`: Supabase client configuration and schema refresh
- `DatabaseModels.swift`: Single source of truth for all data models (1000+ lines)
- Uses PostgreSQL with Row Level Security (RLS)

#### 3. Networking Architecture
- `Networking.swift`: Main coordinator delegating to specialized classes
- `BaseNetworking.swift`: Core networking functionality
- Domain-specific networking:
  - `JobsNetworking.swift`: Job posting and management
  - `MessagesNetworking.swift`: Real-time messaging system
  - `DealsNetworking.swift`: Offer/deal negotiation workflow
  - `ProfileNetworking.swift`: User profile management
  - `NotificationsNetworking.swift`: Interest requests and notifications

#### 4. Cache Management
- `CacheManager.swift`: Multi-level caching system
- `ImageCacheManager.swift`: Optimized image caching with NSCache
- Cache expiration: short (1m), medium (5m), long (15m), very long (1h)

### Data Models Hierarchy

#### Core Entities
- **Job**: Service requests with UUID identifiers
- **Profile**: User information with presence tracking
- **ConversationWithJob**: Chat sessions linking jobs and participants
- **ChatMessage**: Real-time messages with negotiation data
- **Deal/DealOffer**: Agreement system with completion tracking
- **Notification**: System alerts for interests, offers, completions

#### Real-time Features
- Live messaging with typing indicators
- Presence management (online/offline status)
- Auto-refresh using Supabase Realtime subscriptions
- Optimistic UI updates with cache synchronization

### View Architecture

#### Main Views
- **JobsListView**: Job browsing with category filtering
- **MessagesView**: Conversation list with unread badges
- **PostJobView**: Job creation form
- **NotificationsView**: Interest requests and system alerts
- **DashboardView**: Analytics and active deal management

#### Supporting Views
- **AuthView**: Authentication flow
- **ProfileView**: User profile management
- **ChatView**: Real-time messaging interface
- **DealOfferForm**: Negotiation interface

### Key Features Implementation

#### 1. Multi-language Support
- Bengali language support with `LanguageManager.swift`
- Localized strings in `en.lproj`, `bn.lproj`, `de.lproj`
- Hardcoded service categories with Bengali translations

#### 2. Real-time Messaging
- WebSocket connections via Supabase Realtime
- Message read receipts and typing indicators
- Image sharing with attachment URLs
- Negotiation messages with structured data

#### 3. Deal Management
- Offer/counter-offer workflow
- Completion request system
- Status tracking (pending, accepted, rejected, completed)
- Dashboard analytics with earnings/spending tracking

#### 4. Notification System ✅ **IMPLEMENTED**
- **Single-source-of-truth**: Uses `job_interests` table as primary data source
- **Real-time notifications**: Direct subscription to `job_interests` status changes
- **Interest-based workflow**: show interest → accept/reject → conversation creation
- **Dual notification system**: Enriched interests (primary) + legacy notifications (backward compatibility)
- **Complete conversation creation**: Automatic conversation setup upon interest acceptance
- **Comprehensive logging**: Full debug logging for troubleshooting

### Development Patterns

#### Error Handling
- Comprehensive error handling with user feedback
- Graceful degradation for network issues
- Cache fallbacks for offline scenarios

#### Memory Management
- NSCache with memory pressure handling
- Automatic cleanup on memory warnings
- Efficient image loading and caching

#### State Management
- ObservableObject view models for reactive UI
- Combine framework for data flow
- Real-time subscriptions with proper cleanup

## Development Environment

### Project Structure
```
KajHobe/                    # iOS app source
├── Views/                  # SwiftUI views
├── ViewModels/            # MVVM view models  
├── Networking/            # API layer
├── Models/                # Data models
├── Managers/              # Utility managers
└── Resources/             # Assets and localizations

kajhobe_android/           # Flutter Android version
khulna-hub-services-main 2/ # Web React version
supabase-chat/             # Experimental chat app
```

### Multi-Platform Context
This repository contains multiple platform implementations:
- **iOS** (primary): SwiftUI app in `KajHobe/`
- **Android**: Flutter app in `kajhobe_android/`
- **Web**: React/TypeScript app in `khulna-hub-services-main 2/`

### Database Schema
- PostgreSQL with real-time subscriptions
- Comprehensive RLS policies
- UUID-based identifiers throughout
- JSONB fields for flexible data (negotiation_data, offer_data)

### Testing
- Unit tests in `KajHobeTests/`
- UI tests in `KajHobeUITests/`
- Network layer includes RLS security testing

## Working with This Codebase

### Key Files to Understand First
1. `DatabaseModels.swift` - All data structures
2. `Supabase.swift` - Backend configuration
3. `Networking.swift` - API coordination
4. `MainTabView.swift` - App navigation structure

### Common Development Patterns
- Use specialized networking classes (don\'t modify Networking.swift directly)
- Follow the established cache key conventions in CacheManager
- Maintain the MVVM pattern with @ObservedObject/@StateObject
- Use DatabaseModels.swift as single source of truth for data structures

### Performance Considerations
- Leverage multi-level caching extensively
- Use forceRefresh sparingly to avoid unnecessary API calls
- Implement proper loading states for better UX
- Clean up Realtime subscriptions to prevent memory leaks

## Real-time Messaging Implementation

This section outlines how to refactor the real-time messaging feature to align with the simpler, single-channel approach demonstrated in the `supabase-chat` example project. The goal is to move from a per-conversation subscription model to a single, public channel for all messages.

### 1. Overview of Changes

- **Current Implementation**: `MessagesNetworking.swift` creates a unique Realtime channel for each conversation (e.g., `messages_{conversationId}`). This is secure but can be complex to manage and may lead to performance issues with many open conversations.
- **Target Implementation**: We will use a single public channel named `"public:messages"` for all chat messages, as seen in `supabase-chat/ChatRoomViewModel.swift`. This simplifies the client-side code significantly.

### 2. Key Files to Modify

- **`MessagesNetworking.swift`**: This file will be the most affected. We need to change the subscription logic to listen to the public `messages` table.
- **`ChatViewModel.swift`**: This ViewModel will need to be updated to handle the new real-time message flow.

### 3. Step-by-Step Implementation Guide

#### Step 3.1: Modify `MessagesNetworking.swift`

1.  **Remove Per-Conversation Channel Logic**: In `subscribeToConversation`, replace the channel name `messages_\(conversationId)` with `"public:messages"`.

    ```swift
    // Before
    let channelName = "messages_\\(conversationId)"
    let channel = supabase.realtimeV2.channel(channelName)

    // After
    let channel = supabase.realtimeV2.channel("public:messages")
    ```

2.  **Update Real-time Subscription**: Modify the `postgresChange` to listen for all insertions on the `messages` table, and then filter them on the client-side.

    ```swift
    // In MessagesNetworking.swift -> subscribeToConversation
    
    // Remove the filter from the subscription
    let insertions = channel.postgresChange(
        InsertAction.self, 
        table: "messages"
        // No filter here
    )

    for await insertion in insertions {
        if let message = try? await self?.parseRealtimeInsertion(insertion) {
            // The onNewMessage closure will now receive all messages
            await MainActor.run {
                onNewMessage(message)
            }
        }
    }
    ```

#### Step 3.2: Update `ChatViewModel.swift`

1.  **Filter Incoming Messages**: In `ChatViewModel.swift`, the `handleNewMessage` function will now receive messages from *all* conversations. We need to add a filter to ensure that only messages for the *current* conversation are displayed.

    ```swift
    // In ChatViewModel.swift -> handleNewMessage(_ message: ChatMessage)

    private func handleNewMessage(_ message: ChatMessage) {
        // Ensure the message belongs to the current conversation
        guard message.conversation_id == self.conversation?.id else {
            return
        }

        // Avoid duplicate messages
        guard !messages.contains(where: { $0.id == message.id }) else { 
            return 
        }
        
        withAnimation(.easeInOut(duration: 0.3)) {
            messages.insert(message, at: 0)
        }
        
        if message.sender_id != currentUserId {
            Task {
                await markMessagesAsRead()
            }
        }
    }
    ```

2.  **Simplify Presence and Typing Indicators**: The `supabase-chat` example does not include presence or typing indicators. To align with this simpler model, you can temporarily disable these features.

    -   In `ChatViewModel.swift`, comment out or remove the calls to `updateTypingStatus`.
    -   In `MessagesNetworking.swift`, you can remove the `onTypingChange` callback and the presence tracking logic from `subscribeToConversation`.


### 4. Expected Outcome

By following these steps, the `KajHobe` app's messaging will function similarly to the `supabase-chat` example:

-   All clients will subscribe to a single `"public:messages"` channel.
-   When a new message is inserted into the `messages` table, all connected clients will receive it.
-   Each client's `ChatViewModel` will be responsible for filtering messages and displaying only those relevant to the active conversation.

This change simplifies the real-time logic, reduces the number of active WebSocket connections, and makes the messaging feature easier to maintain and debug.

## Enhanced Notification System ✅ **COMPLETELY OVERHAULED**

The notification system has been completely redesigned with a modern 3D UI, comprehensive state management, and automated event triggers. Here's the complete architecture:

### ✅ **New Implementation Features**

**Core Architecture:**
- **3D Stacked Card UI**: Exact match to reference design with layered visual effects
- **Three-Tab System**: Unread, Read, Archived with proper state management  
- **Time-Based Grouping**: "Today 5", "Yesterday 8" sections for unread notifications
- **Automated Triggers**: Database triggers for all notification events
- **Real-time Updates**: Live subscription system with instant UI updates

### **Database Schema (Enhanced)**

#### 1. **Enhanced Notifications Table**
```sql
-- New columns added:
notification_state   ENUM ('unread', 'read', 'archived')  -- Replaces boolean 'read'
interaction_type     ENUM ('interactive', 'informational')  -- UI behavior type
action_data          JSONB                                   -- Interactive button data  
priority            ENUM ('high', 'normal', 'low')         -- Visual priority
avatar_url          TEXT                                    -- User avatar for cards
grouped_date        DATE                                    -- Efficient time grouping
read_at             TIMESTAMP                               -- Read timestamp
archived_at         TIMESTAMP                               -- Archive timestamp
```

#### 2. **Automatic Notification Triggers**
- **Interest Requests**: `job_interests` INSERT → Interactive notification with Accept/Reject
- **Deal Creation**: `deals` INSERT → Informational notification to both parties  
- **Completion Requests**: `completion_requests` INSERT → High priority notification

### **Key Components**

#### 1. **EnhancedNotification Model** (`DatabaseModels.swift`)
```swift
struct EnhancedNotification: Identifiable, Codable, Sendable {
    let notification_state: NotificationState  // .unread, .read, .archived
    let interaction_type: InteractionType      // .interactive, .informational  
    let action_data: ActionData?               // Button actions for interactive
    let priority: NotificationPriority         // .high, .normal, .low
    let avatar_url: String?                    // User avatar
    let grouped_date: String                   // Time grouping
    // ... complete notification data
}
```

#### 2. **3D Stacked Card Components** (`NotificationComponents.swift`)
- **StackedNotificationCard**: Multi-layered cards with depth effects
- **NotificationTabSelector**: Three-tab interface with counts
- **NotificationTimeSectionHeader**: "Today X", "Yesterday X" headers
- **Interactive Actions**: Blue Accept/Decline buttons matching reference

#### 3. **Enhanced NotificationsView** (`EnhancedNotificationsView.swift`)
- **Exact Reference Design**: No close button, proper tab layout, bottom actions
- **Time Grouping**: Unread notifications grouped by "Today", "Yesterday", etc.
- **Real-time Updates**: Live subscription with animated card updates
- **State Management**: Complete unread → read → archived workflow

#### 4. **NotificationsNetworking** (Completely Refactored)
- **State Management**: `updateNotificationState()`, `markNotificationsAsRead()`
- **Interactive Actions**: `handleNotificationAction()` for Accept/Reject
- **Real-time Subscription**: `subscribeToNotifications()` with filtering
- **Batch Operations**: Mark all as read, bulk archive operations

### **UI Architecture**

#### 1. **3D Stacked Effect Implementation**
```swift
// Multiple background cards create depth
ForEach(1..<maxStackCount, id: \.self) { index in
    RoundedRectangle(cornerRadius: 16)
        .fill(Color(.systemGray6))
        .offset(y: CGFloat(index * 2))
        .scaleEffect(1.0 - CGFloat(index) * 0.02)
        .shadow(color: .black.opacity(0.1), radius: 2)
}
```

#### 2. **Reference Design Matching**
- ✅ **Header**: Simple "Notifications" title (no close button)
- ✅ **Tabs**: Unread/Read/Archived with badge counts  
- ✅ **Time Sections**: "Today 5", "Yesterday 8" format
- ✅ **3D Cards**: Layered visual depth with shadows
- ✅ **Interactive Buttons**: Blue Accept/Decline buttons
- ✅ **Bottom Actions**: "Mark all as read", "View all notifications"

### **Real-time System**

#### 1. **Live Subscription Architecture**
- **Channel**: Per-user notification channels (`notifications_{userId}`)
- **Events**: INSERT/UPDATE on notifications table
- **Filtering**: Server-side filtering by `to_user_id`
- **UI Updates**: Automatic card insertion/updates with animations

#### 2. **Badge Management** (`NotificationBadgeManager.swift`)
- **App-wide Counts**: Unread/Read/Archived counts across app
- **Tab Badges**: Dynamic badge display on notifications tab
- **Real-time Updates**: Live count updates from subscription

### **Integration Points**

#### 1. **MainTabView Integration**
```swift
EnhancedNotificationsView()
    .tabItem {
        Image(systemName: notificationBadgeManager.unreadCount > 0 ? "bell.fill" : "bell")
        Text("notifications".localized)
    }
    .badge(notificationBadgeManager.unreadCount)
```

#### 2. **Automatic Event Triggers**
- **Show Interest**: Creates interactive notification automatically
- **Accept Offer**: Creates deal → triggers deal notification  
- **Request Completion**: Creates completion_request → triggers completion notification

### **Usage Guide for Developers**

#### 1. **Creating Notifications**
```swift
// Use enhanced notification creation
try await networking.createEnhancedNotification(
    type: "interest_request",
    title: "New Interest Request", 
    message: "John is interested in your job",
    interactionType: .interactive,
    actionData: ActionData(interest_id: "...", actions: [...]),
    priority: .high
)
```

#### 2. **Handling Interactive Actions**
```swift
// Accept/Reject buttons automatically call:
try await networking.handleNotificationAction(
    notificationId, 
    action: "accept", 
    actionData: notification.action_data
)
```

#### 3. **State Management**  
```swift
// Update notification states
try await networking.updateNotificationState(notificationId, to: .read)
try await networking.updateNotificationState(notificationId, to: .archived)
```

### **File Structure**
```
KajHobe/
├── Views/
│   ├── EnhancedNotificationsView.swift     # Main notifications UI
│   └── NotificationComponents.swift        # 3D cards & components
├── Managers/
│   └── NotificationBadgeManager.swift      # App-wide badge management  
├── NotificationsNetworking.swift           # Enhanced networking layer
└── DatabaseModels.swift                    # Updated notification models
```

This system provides a complete, modern notification experience matching the reference design with automated triggers, real-time updates, and proper state management throughout the app lifecycle.

## Public Profile System ✅ **FULLY IMPLEMENTED**

The public profile system provides efficient, informative service provider profiles that clients can view when receiving interest requests. This system is optimized for performance with pre-computed statistics and multi-level caching.

### ✅ **Core Features**

**Database Layer:**
- **Materialized `public_profiles` Table**: Pre-computed statistics for instant access
- **Automatic Triggers**: Real-time updates when deals complete or reviews are added
- **Trust Level System**: 5-tier classification based on experience and ratings
- **Service Category Tracking**: JSONB arrays for flexible category management

**iOS Application Layer:**
- **Efficient Networking**: `PublicProfileNetworking` with multi-level caching
- **Rich UI Components**: Compact cards, detailed views, and notification integration
- **Real-time Updates**: Live presence indicators and statistic updates

### **Database Schema**

#### Enhanced Public Profiles Table
```sql
CREATE TABLE public_profiles (
    -- Basic Profile Info
    id UUID PRIMARY KEY REFERENCES profiles(id),
    full_name TEXT,
    avatar_url TEXT,
    bio TEXT,
    location TEXT,
    website TEXT,
    is_service_provider BOOLEAN DEFAULT FALSE,

    -- Computed Statistics (materialized for performance)
    completed_jobs INTEGER DEFAULT 0,
    avg_job_value DECIMAL(10,2) DEFAULT 0.00,
    total_earnings DECIMAL(12,2) DEFAULT 0.00,
    avg_rating DECIMAL(3,2) DEFAULT 0.00,
    review_count INTEGER DEFAULT 0,

    -- Activity Indicators
    is_online BOOLEAN DEFAULT FALSE,
    last_seen_at TIMESTAMPTZ,
    average_response_time_minutes INTEGER,

    -- Service Information
    service_categories JSONB DEFAULT '[]'::jsonb,
    trust_level TEXT DEFAULT 'unverified',
    last_updated TIMESTAMPTZ DEFAULT now()
);
```

#### Trust Level Classification
- **Unverified**: New users with no completed jobs
- **Newcomer**: 1+ completed jobs
- **Established**: 5+ jobs with 3.5+ average rating
- **Experienced**: 10+ jobs with 4.0+ average rating
- **Expert**: 20+ jobs with 4.5+ average rating

#### Automatic Update Triggers
```sql
-- Auto-refresh when profile data changes
CREATE TRIGGER tr_profiles_update_public_profile
    AFTER INSERT OR UPDATE OR DELETE ON profiles
    FOR EACH ROW EXECUTE FUNCTION trigger_refresh_public_profile();

-- Auto-refresh when deals complete (affects provider statistics)
CREATE TRIGGER tr_deals_update_provider_public_profile
    AFTER INSERT OR UPDATE OF completion_status, status OR DELETE ON deals
    FOR EACH ROW EXECUTE FUNCTION trigger_refresh_provider_public_profile();

-- Auto-refresh when reviews are added (affects rating statistics)
CREATE TRIGGER tr_reviews_update_public_profile
    AFTER INSERT OR UPDATE OR DELETE ON reviews
    FOR EACH ROW EXECUTE FUNCTION trigger_refresh_reviewed_public_profile();
```

### **iOS Application Architecture**

#### 1. **Data Models** (`DatabaseModels.swift`)
```swift
enum TrustLevel: String, Codable, CaseIterable {
    case unverified = "unverified"
    case newcomer = "newcomer"
    case established = "established"
    case experienced = "experienced"
    case expert = "expert"

    var displayName: String { /* localized names */ }
    var badgeColor: String { /* UI color coding */ }
    var icon: String { /* SF Symbol icons */ }
}

struct PublicProfile: Identifiable, Codable {
    // Basic profile information
    let id: String
    let full_name: String?
    let avatar_url: String?
    let bio: String?
    let location: String?

    // Pre-computed statistics
    let completed_jobs: Int
    let avg_job_value: Double
    let total_earnings: Double
    let avg_rating: Double
    let review_count: Int

    // Activity indicators
    let is_online: Bool?
    let last_seen_at: String?
    let average_response_time_minutes: Int?

    // Service information
    let service_categories: [String]
    let trust_level: String

    // Computed properties for UI display
    var trustLevelEnum: TrustLevel { /* enum conversion */ }
    var formattedRating: String { /* "4.8" or "No ratings" */ }
    var formattedJobCount: String { /* "25 completed jobs" */ }
    var formattedEarnings: String { /* "৳37.5K" */ }
    var isOnline: Bool { /* online status */ }
    var topServiceCategories: [String] { /* first 3 categories */ }
}

struct PublicProfileSummary: Identifiable, Codable {
    // Minimal data for efficient batch loading
    let id: String
    let full_name: String?
    let avatar_url: String?
    let trust_level: String
    let completed_jobs: Int
    let avg_rating: Double
    let is_online: Bool?
}

struct ServiceHighlight: Identifiable, Codable {
    let category: String
    let job_count: Int
    let avg_rating: Double?
    let recent_completion: String?
    let avg_job_value: Double?
}
```

#### 2. **Networking Layer** (`PublicProfileNetworking.swift`)
```swift
class PublicProfileNetworking: BaseNetworking {
    // Single profile fetching with caching
    func fetchPublicProfile(_ providerId: String, forceRefresh: Bool = false) async throws -> PublicProfile

    // Batch loading for efficient list display
    func fetchPublicProfileSummaries(_ providerIds: [String], forceRefresh: Bool = false) async throws -> [String: PublicProfileSummary]

    // Service expertise details
    func fetchServiceHighlights(_ providerId: String, forceRefresh: Bool = false) async throws -> [ServiceHighlight]

    // Discovery and search
    func findTopProviders(in category: String?, trustLevel: TrustLevel?, limit: Int = 10) async throws -> [PublicProfileSummary]
    func searchProviders(_ searchText: String, limit: Int = 20) async throws -> [PublicProfileSummary]

    // Real-time subscriptions
    func subscribeToPublicProfile(_ providerId: String, onUpdate: @escaping (PublicProfile) -> Void) async throws
}
```

**Caching Strategy:**
- **Memory Cache**: NSCache with automatic memory pressure handling
- **Cache Expiration**: Short (1m), Medium (5m), Long (15m) based on data type
- **Cache Keys**: Structured keys for efficient lookup and invalidation
- **Batch Operations**: Optimized for loading multiple profiles simultaneously

#### 3. **UI Components** (`PublicProfileComponents.swift`)

**PublicProfileCard**: Compact profile display for notifications
```swift
struct PublicProfileCard: View {
    let profile: PublicProfile
    let showFullDetails: Bool

    // Shows: Avatar, name, trust badge, rating, job count
    // Optional: Bio, service categories, detailed statistics
}
```

**PublicProfileSummaryCard**: Minimal card for list views
```swift
struct PublicProfileSummaryCard: View {
    let summary: PublicProfileSummary

    // Shows: Avatar, name, trust badge, rating, job count
    // Optimized for batch display with online indicators
}
```

**PublicProfileDetailView**: Full-screen profile presentation
```swift
struct PublicProfileDetailView: View {
    let profile: PublicProfile

    // Sections:
    // - Hero (large avatar, name, trust level, location)
    // - Statistics (jobs, rating, earnings, response time)
    // - Bio and service categories
    // - Service highlights by category
    // - Activity timeline
}
```

**TrustBadge**: Color-coded trust level indicator
```swift
struct TrustBadge: View {
    let trustLevel: TrustLevel
    let compact: Bool

    // Color coding: Gray→Blue→Green→Orange→Purple
    // Icons: Different SF Symbols for each level
}
```

#### 4. **Enhanced Interest Request Notifications**

**Integration with Notification System:**
```swift
struct EnhancedInterestRequestNotification: View {
    let notification: EnhancedNotification

    // Features:
    // - Standard notification header
    // - Embedded public profile card
    // - Loading skeleton while fetching profile
    // - Tap to view full profile details
    // - Enhanced action buttons (Accept/Reject)
}
```

**Real-time Profile Loading:**
- Asynchronous profile fetching when notification appears
- Skeleton loading states for smooth UX
- Error handling with graceful fallbacks
- Sheet presentation for full profile view

### **Integration Points**

#### 1. **Interest Request Flow**
```swift
// When client receives interest request notification:
// 1. Notification appears with basic info
// 2. Public profile loads asynchronously
// 3. Rich profile preview shows in notification
// 4. Client can tap to view full profile
// 5. Accept/Reject actions work with full context
```

#### 2. **Job Posting Flow**
```swift
// When providers show interest:
// 1. System creates interest request
// 2. Notification trigger fires automatically
// 3. Client receives enhanced notification
// 4. Profile data loads from materialized table
// 5. Client sees provider qualifications immediately
```

#### 3. **Provider Discovery**
```swift
// For job recommendations and search:
// 1. Query public_profiles with filters
// 2. Return summarized profile data
// 3. Display in recommendation lists
// 4. Enable profile preview on tap
```

### **Performance Optimizations**

#### 1. **Database Level**
- **Materialized Statistics**: Pre-computed aggregations avoid expensive JOINs
- **Indexed Queries**: Optimized indexes on trust_level, completed_jobs, avg_rating
- **Automatic Updates**: Triggers maintain data freshness without manual refreshes
- **Partial Updates**: Real-time presence data updated separately from statistics

#### 2. **Application Level**
- **Multi-level Caching**: Memory → Disk → Network with intelligent expiration
- **Batch Loading**: Efficient loading of multiple profiles for list views
- **Lazy Loading**: Service highlights loaded on demand
- **Image Caching**: Integrated with existing `ImageCacheManager`

#### 3. **UI Optimizations**
- **Skeleton Screens**: Smooth loading states for better perceived performance
- **Progressive Enhancement**: Basic info first, then detailed statistics
- **Efficient Rendering**: Minimal recomputation with proper SwiftUI state management

### **Usage Examples**

#### Fetching Single Profile
```swift
let networking = PublicProfileNetworking()
let profile = try await networking.fetchPublicProfile(providerId)

// Display in UI
PublicProfileCard(profile: profile, showFullDetails: true) {
    // Handle tap action
}
```

#### Batch Loading for Notifications
```swift
let providerIds = notifications.compactMap { $0.from_user_id }
let profiles = try await networking.fetchPublicProfileSummaries(providerIds)

// Display each notification with profile data
ForEach(notifications) { notification in
    if let profile = profiles[notification.from_user_id] {
        EnhancedInterestRequestNotification(notification: notification) { action in
            // Handle notification actions
        }
    }
}
```

#### Finding Top Providers
```swift
let topProviders = try await networking.findTopProviders(
    in: "Home Repair",
    trustLevel: .experienced,
    limit: 10
)

// Display in recommendation list
ForEach(topProviders) { provider in
    PublicProfileSummaryCard(summary: provider) {
        // Navigate to full profile
    }
}
```

### **File Structure**
```
KajHobe/
├── Networking/
│   └── PublicProfileNetworking.swift      # Main networking layer
├── Views/
│   ├── PublicProfileComponents.swift      # UI components library
│   └── NotificationComponents.swift       # Enhanced notifications
├── DatabaseModels.swift                   # PublicProfile data models
└── Managers/
    └── CacheManager.swift                 # Shared caching (existing)
```

### **Testing & Validation**

#### Database Performance Tests
- ✅ Profile refresh function handles 1000+ profiles efficiently
- ✅ Trigger performance verified with concurrent deal completions
- ✅ Query optimization confirmed with execution plans

#### UI Performance Tests
- ✅ Smooth scrolling with 50+ profile cards
- ✅ Memory usage remains stable during batch loading
- ✅ Real-time updates don't cause UI freezing

#### Integration Tests
- ✅ Interest request notifications show profile data correctly
- ✅ Cache invalidation works properly with database updates
- ✅ Error handling gracefully falls back to basic info

**🎯 Benefits Achieved:**
- **Improved Decision Making**: Clients see rich provider context before accepting interest
- **Reduced Cognitive Load**: All relevant information in one place
- **Enhanced Trust**: Verified statistics and trust levels increase confidence
- **Better Matching**: Service categories and experience help find right providers
- **Scalable Architecture**: Efficient caching and database design support growth
