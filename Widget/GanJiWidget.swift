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

/// 空状态：系统风。灰字 + 蓝色提示，不做多余装饰。
private struct EmptyBoard: View {
    let entry: GanJiEntry

    private var title: String { entry.synced ? "还没有收藏" : "尚未同步" }
    private var detail: String {
        entry.synced
            ? "在 App 里点心形收藏圩点"
            : "打开「赶集日记」选择一次地区"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                SectionLabel(text: "赶集历")
                Spacer(minLength: 0)
            }
            Spacer(minLength: 0)
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Ink.title)
                Text(detail)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Ink.secondary)
                    .lineSpacing(1.5)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
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
