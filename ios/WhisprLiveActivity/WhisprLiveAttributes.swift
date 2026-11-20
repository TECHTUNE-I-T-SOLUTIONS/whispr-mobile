import ActivityKit
import Foundation

/// Shared between the app and the WidgetKit extension so both compile the
/// same Live Activity schema.
@available(iOS 16.1, *)
struct WhisprLiveAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var unreadCount: Int
        var postCount: Int
        var streakDays: Int
        var latestTitle: String
        var latestBody: String
        var countsLine: String
        var updatedAt: String
    }

    var appName: String
}
