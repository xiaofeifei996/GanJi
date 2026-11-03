import SwiftUI
import WidgetKit

struct GanJiBoardView: View {
    let entry: GanJiEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            if entry.boards.isEmpty || entry.favoriteCount == 0 {
                EmptyBoard(entry: entry, family: family)
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

/// 没有可显示的圩日时的引导页。
///
/// 之前的版本是「大字摆在正中 + 一大片空白」，看起来像加载失败。
/// 这里改成有结构的版式：顶部栏目标签、中间一行说明、底部一条明确指引，
/// 用朱砂竖标和分隔线把版面撑住，不留空洞感。
private struct EmptyBoard: View {
    let entry: GanJiEntry
    let family: WidgetFamily

    private var isSynced: Bool { entry.synced }

    private var title: String { isSynced ? "还没有收藏" : "尚未同步" }

    private var detail: String {
        if isSynced {
            return family == .systemSmall
                ? "在 App 里点心形收藏"
                : "打开「赶集日记」，在心仪的圩点上点一下心形"
        }
        return family == .systemSmall
            ? "打开 App 选一次地区"
            : "打开「赶集日记」，选择一次地区即可写入圩日"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 5) {
                SectionLabel(text: "赶集历")
                Spacer(minLength: 0)
                // 用一个空心圆点暗示「等待数据」，比纯文字更有状态感。
                Circle()
                    .strokeBorder(Paper.vermilion.opacity(0.5), lineWidth: 1.2)
                    .frame(width: 6, height: 6)
            }

            Spacer(minLength: 6)

            HStack(alignment: .top, spacing: 7) {
                VermilionTick(height: family == .systemSmall ? 12 : 15)
                    .padding(.top, 2)
                Text(title)
                    .font(.system(size: family == .systemSmall ? 14 : 16,
                                  weight: .heavy, design: .serif))
                    .foregroundStyle(Paper.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 0)
            }

            Spacer(minLength: 4)

            Text(detail)
                .font(.system(size: family == .systemSmall ? 9.5 : 10.5, weight: .medium))
                .foregroundStyle(Paper.inkSoft)
                .lineSpacing(1.5)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.leading, 10)

            Spacer(minLength: 6)

            HairLine()

            Spacer(minLength: 5)

            HStack(spacing: 4) {
                Text("心形 = 收藏")
                    .font(.system(size: 8.5, weight: .heavy))
                    .tracking(0.8)
                    .foregroundStyle(Paper.inkSoft.opacity(0.8))
                Spacer(minLength: 0)
            }
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
