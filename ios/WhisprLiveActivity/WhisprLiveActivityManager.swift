import ActivityKit
import Foundation
import UIKit

/// App-side bridge for the Dart method channel. Live Activities need no
/// notification permission; we still respect the OS "Live Activities" switch
/// and fail silently when the user has turned it off.
@available(iOS 16.1, *)
final class WhisprLiveActivityManager {
    static let shared = WhisprLiveActivityManager()

    private var current: Activity<WhisprLiveAttributes>?

    func startOrUpdate(payload: [String: Any]) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let state = contentState(from: payload)
        if let current {
            Task {
                await current.update(using: state)
            }
        } else {
            let attributes = WhisprLiveAttributes(appName: "Whispr")
            current = try? Activity.request(
                attributes: attributes,
                contentState: state,
                pushType: nil
            )
        }
    }

    func end() {
        guard let current else { return }
        self.current = nil
        Task {
            await current.end()
        }
    }

    private func contentState(from payload: [String: Any]) -> WhisprLiveAttributes.ContentState {
        let unread = Self.integer(payload["unreadCount"])
        let posts = Self.integer(payload["postCount"])
        let streak = Self.integer(payload["streakDays"])
        let signedIn = payload["signedIn"] as? Bool ?? false
        let counts = signedIn
            ? "\(unread) unread · \(posts) posts · \(streak)d streak"
            : "Live from Whispr"

        return WhisprLiveAttributes.ContentState(
            unreadCount: unread,
            postCount: posts,
            streakDays: streak,
            latestTitle: Self.text(payload["latestTitle"], fallback: "Whispr"),
            latestBody: Self.text(payload["latestBody"], fallback: "Open Whispr for updates."),
            countsLine: counts,
            updatedAt: Self.text(payload["updatedAt"], fallback: "")
        )
    }

    private static func integer(_ value: Any?) -> Int {
        if let number = value as? NSNumber { return number.intValue }
        if let text = value as? String { return Int(text) ?? 0 }
        return 0
    }

    private static func text(_ value: Any?, fallback: String) -> String {
        let text = (value as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return text.isEmpty ? fallback : text
    }
}
