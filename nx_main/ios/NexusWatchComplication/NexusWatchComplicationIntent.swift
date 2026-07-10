import AppIntents
import WidgetKit

struct NexusWatchComplicationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Nexus Recording" }
    static var description: IntentDescription { "Quick access to voice recording" }

    static var openAppWhenRun: Bool { true }

    func perform() async throws -> some IntentResult {
        .result()
    }
}
