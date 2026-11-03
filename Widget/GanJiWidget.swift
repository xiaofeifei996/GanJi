import SwiftUI
import WidgetKit

struct GanJiBoardView: View {
    let entry: GanJiEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            if entry.boards.isEmpty {
                EmptyBoard()
            } else {
                switch family {
                case .systemSmall: SealBoard(entry: entry)
                case .systemMedium: StripBoard(entry: entry)
                default: AlmanacBoard(entry: entry)
                }
            }
        }
        .paperWidget()
    }
}

/// 还没同步过圩日时的空状态。不用占位假数据，直接说清要做哪一步。
private struct EmptyBoard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionLabel(text: "赶集历")
            Spacer(minLength: 4)
            Text("尚未同步")
                .font(.system(size: 15, weight: .heavy, design: .serif))
                .foregroundStyle(Paper.ink)
            Text("打开「赶集日记」，选一次地区即可写入圩日")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Paper.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(13)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

@main
struct GanJiWidget: Widget {
    // 与旧实现的 kind 不同，装上新版本后系统会把它当成一个新的小组件，
    // 不会复用桌面上残留的旧快照。
    private let kind = "GanJiAlmanacWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: GanJiProvider()) { entry in
            GanJiBoardView(entry: entry)
        }
        // 版面自己控制内边距，不要再叠加系统的内容边距。
        .contentMarginsDisabled()
        .configurationDisplayName("赶集历")
        .description("今日圩日与未来七日的开圩安排")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
