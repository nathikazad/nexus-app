import SwiftUI
import WidgetKit

struct NexusWatchComplicationProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> NexusWatchComplicationEntry {
        NexusWatchComplicationEntry(date: Date(), configuration: NexusWatchComplicationIntent())
    }

    func snapshot(
        for configuration: NexusWatchComplicationIntent,
        in context: Context
    ) async -> NexusWatchComplicationEntry {
        NexusWatchComplicationEntry(date: Date(), configuration: configuration)
    }

    func timeline(
        for configuration: NexusWatchComplicationIntent,
        in context: Context
    ) async -> Timeline<NexusWatchComplicationEntry> {
        let entry = NexusWatchComplicationEntry(date: Date(), configuration: configuration)
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
        return Timeline(entries: [entry], policy: .after(nextUpdate))
    }

    func recommendations() -> [AppIntentRecommendation<NexusWatchComplicationIntent>] {
        [
            AppIntentRecommendation(
                intent: NexusWatchComplicationIntent(),
                description: "Quick Record"
            )
        ]
    }
}

struct NexusWatchComplicationEntry: TimelineEntry {
    let date: Date
    let configuration: NexusWatchComplicationIntent
}

struct NexusWatchComplicationEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: NexusWatchComplicationProvider.Entry

    var body: some View {
        switch family {
        case .accessoryCircular:
            NexusCircularComplicationView()
        case .accessoryRectangular:
            NexusRectangularComplicationView()
        case .accessoryCorner:
            NexusCornerComplicationView()
        case .accessoryInline:
            NexusInlineComplicationView()
        default:
            NexusCircularComplicationView()
        }
    }
}

private struct NexusCircularComplicationView: View {
    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            Image(systemName: "mic.fill")
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(.primary)
        }
    }
}

private struct NexusRectangularComplicationView: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "mic.fill")
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(.primary)

            VStack(alignment: .leading, spacing: 2) {
                Text("Nexus")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text("Tap to record")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct NexusCornerComplicationView: View {
    var body: some View {
        Image(systemName: "mic.fill")
            .font(.system(size: 20, weight: .medium))
            .foregroundStyle(.primary)
            .widgetLabel {
                Text("Record")
            }
    }
}

private struct NexusInlineComplicationView: View {
    var body: some View {
        Label("Nexus", systemImage: "mic.fill")
    }
}

@main
struct NexusWatchComplication: Widget {
    let kind = "NexusWatchComplication"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: NexusWatchComplicationIntent.self,
            provider: NexusWatchComplicationProvider()
        ) { entry in
            NexusWatchComplicationEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Nexus")
        .description("Quick access to voice recording")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryCorner,
            .accessoryInline,
        ])
    }
}

#Preview(as: .accessoryCircular) {
    NexusWatchComplication()
} timeline: {
    NexusWatchComplicationEntry(date: .now, configuration: NexusWatchComplicationIntent())
}

#Preview(as: .accessoryRectangular) {
    NexusWatchComplication()
} timeline: {
    NexusWatchComplicationEntry(date: .now, configuration: NexusWatchComplicationIntent())
}

#Preview(as: .accessoryCorner) {
    NexusWatchComplication()
} timeline: {
    NexusWatchComplicationEntry(date: .now, configuration: NexusWatchComplicationIntent())
}
