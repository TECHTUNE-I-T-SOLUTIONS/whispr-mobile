import ActivityKit
import SwiftUI
import WidgetKit

@main
struct WhisprLiveActivityBundle: WidgetBundle {
    var body: some Widget {
        WhisprLiveActivityWidget()
    }
}

struct WhisprLiveActivityWidget: Widget {
    private let deepLink = URL(string: "whispr://app/notifications")!

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WhisprLiveAttributes.self) { context in
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("LIVE WHISPR")
                        .font(.caption.bold())
                        .foregroundColor(Color(red: 0.95, green: 0.72, blue: 0.72))
                    Spacer()
                    Text(context.state.updatedAt)
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.65))
                        .lineLimit(1)
                }
                Text(context.state.countsLine)
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(1)
                Text(context.state.latestTitle)
                    .font(.headline)
                    .foregroundColor(.white)
                    .lineLimit(2)
                Text(context.state.latestBody)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                    .lineLimit(2)
                Link("Open alerts", destination: deepLink)
                    .font(.caption.bold())
                    .foregroundColor(Color(red: 0.95, green: 0.72, blue: 0.72))
            }
            .padding(14)
            .activityBackgroundTint(Color(red: 0.17, green: 0.10, blue: 0.10))
            .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text("Whispr")
                        .font(.caption.bold())
                        .foregroundColor(Color(red: 0.95, green: 0.72, blue: 0.72))
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.countsLine)
                        .font(.caption2)
                        .foregroundColor(.white)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.latestTitle)
                        .font(.headline)
                        .foregroundColor(.white)
                        .lineLimit(2)
                }
            } compactLeading: {
                Text("W")
                    .font(.caption.bold())
                    .foregroundColor(Color(red: 0.95, green: 0.72, blue: 0.72))
            } compactTrailing: {
                Text(String(context.state.unreadCount))
                    .font(.caption.bold())
                    .foregroundColor(.white)
            } minimal: {
                Text("W")
                    .font(.caption2.bold())
                    .foregroundColor(.white)
            }
            .widgetURL(deepLink)
        }
        .configurationDisplayName("Live Whispr")
        .description("Current Whispr counts and the latest update.")
    }
}
