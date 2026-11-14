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
        .photoWidget()
    }
}

/// 空状态也展示已设置的照片背景。
private struct EmptyBoard: View {
    let entry: GanJiEntry

    private var title: String { entry.synced ? "还没有收藏" : "尚未同步" }
    private var detail: String {
        entry.synced ? "点心形收藏圩点，开圩就会出现在这里"
                     : "打开「赶集日记」选一次地区即可同步"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            WidgetIdentity()
            Spacer(minLength: 8)
            Image(systemName: "heart").font(.system(size: 24, weight: .light))
            Text(title).font(.system(size: 17, weight: .semibold))
            Text(detail).font(.system(size: 11, weight: .medium))
                .opacity(0.8).lineLimit(3)
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
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
        // The full-bleed illustration is the widget's background. Without this,
        // the system applies the default `.widget` content margins on iOS 17+,
        // and on iOS 26 that reads as the glass plate showing through around the
        // canvas. The layouts draw their own padding, so nothing is lost.
        .contentMarginsDisabled()
        // Let WidgetKit strip the container background where it wants to (such as
        // the Lock Screen), which is the supported path for a custom canvas
        // instead of leaving it behind the system glass.
        .containerBackgroundRemovable()
    }
}
