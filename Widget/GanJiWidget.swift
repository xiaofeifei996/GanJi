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

/// 空状态：同样用一张灰票说话，保持「票」的语言一致。
private struct EmptyBoard: View {
    let entry: GanJiEntry

    private var subtitle: String { entry.synced ? "还没有收藏" : "尚未同步" }
    private var title: String {
        entry.synced ? "去收藏圩点" : "打开赶集日记"
    }
    private var detail: String {
        entry.synced ? "点心形，这里就会出现它" : "选一次地区，圩日就会同步过来"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TicketCard(title: title, subtitle: subtitle, isOpen: false)
            Spacer(minLength: 8)
            Text(detail)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Ink.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(13)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

@main
struct GanJiWidget: Widget {
    private let kind = "GanJiAlmanacWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: GanJiProvider()) { entry in
            GanJiBoardView(entry: entry)
        }
        .contentMarginsDisabled()
        .configurationDisplayName("赶集历")
        .description("只显示你收藏的圩点，今日与未来七日的开圩安排")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
