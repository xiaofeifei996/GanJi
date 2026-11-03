import SwiftUI
import WidgetKit

struct GanJiBoardView: View {
    let entry: GanJiEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            if entry.boards.isEmpty || entry.favoriteCount == 0 {
                EmptyBoard(entry: entry)
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

/// 没有可显示的圩日时的说明页。
/// 「从未同步」和「同步了但一个都没收藏」是两种完全不同的状态，必须分开讲。
private struct EmptyBoard: View {
    let entry: GanJiEntry

    private var title: String {
        entry.synced ? "还没有收藏" : "尚未同步"
    }

    private var detail: String {
        if entry.synced {
            return "在「赶集日记」里点心形收藏圩点，这里就只显示收藏的那些"
        }
        return "打开「赶集日记」，选一次地区即可写入圩日"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionLabel(text: "赶集历")
            Spacer(minLength: 6)
            Text(title)
                .font(.system(size: 15, weight: .heavy, design: .serif))
                .foregroundStyle(Paper.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 4)
            Text(detail)
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
        .description("只显示你收藏的圩点，今日与未来七日的开圩安排")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
