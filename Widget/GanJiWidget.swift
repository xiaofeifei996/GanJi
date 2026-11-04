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

/// 空状态：同样浮在水墨画上，白卡说明。
private struct EmptyBoard: View {
    let entry: GanJiEntry

    private var title: String { entry.synced ? "还没有收藏" : "尚未同步" }
    private var detail: String {
        entry.synced ? "点心形收藏圩点，开圩就会出现在这里"
                     : "打开「赶集日记」选一次地区即可同步"
    }

    var body: some View {
        VStack(spacing: 8) {
            Spacer(minLength: 0)
            Text(title)
                .font(.system(size: 14, weight: .heavy))
                .foregroundStyle(Ink.title)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(GlassCard(strong: true, radius: 13))
            Text(detail)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Ink.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(GlassCard(radius: 10))
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(14)
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
        .description("只显示你收藏的圩点，今日与未来三日的开圩安排")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
