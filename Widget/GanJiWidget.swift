import SwiftUI
import WidgetKit

struct GanJiBoardView: View {
    let entry: GanJiEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            switch family {
            case .systemSmall: SealBoard(entry: entry)
            case .systemMedium: StripBoard(entry: entry)
            default: AlmanacBoard(entry: entry)
            }
        }
        .paperWidget()
    }
}

@main
struct GanJiWidget: Widget {
    // 与旧实现的 kind 不同，装上新版本后系统会把它当成一个新的小组件，
    // 不会去复用桌面上残留的旧快照。
    private let kind = "GanJiAlmanacWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: GanJiProvider()) { entry in
            GanJiBoardView(entry: entry)
        }
        .configurationDisplayName("赶集历")
        .description("今日圩日与未来七日的开圩安排")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
