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

/// 空状态：一张「作废票」，KEEP 字样斜盖，票据语言收尾。
private struct EmptyBoard: View {
    let entry: GanJiEntry

    private var subtitle: String { entry.synced ? "空白票" : "尚未同步" }
    private var title: String { entry.synced ? "去收藏圩点" : "打开赶集日记" }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                SectionLabel(text: "赶集历")
                Spacer(minLength: 0)
                Postmark(text: "空", size: 22)
                    .offset(y: -2)
            }
            .padding(.top, 11)
            .padding(.horizontal, 12)

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 3) {
                Text(subtitle)
                    .font(.system(size: 9, weight: .black))
                    .tracking(1.2)
                    .foregroundStyle(Ink.tertiary)
                Text(title)
                    .font(.system(size: 16, weight: .black, design: .serif))
                    .foregroundStyle(Ink.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)

            Spacer(minLength: 0)

            TornEdge()
                .padding(.bottom, 6)
        }
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
