import WidgetKit
import SwiftUI

// MARK: - 数据快照

struct DayItem: Identifiable {
    let id = UUID()
    let name: String
    let size: String
}

struct GanJiEntry: TimelineEntry {
    let date: Date
    /// index 0/1/2 = 今天/明天/后天
    let sections: [[DayItem]]
    /// 每天对应的地支日，如 卯
    let branchNames: [String]
}

struct MarketProvider: TimelineProvider {
    private func build(_ date: Date) -> GanJiEntry {
        let cal = Calendar(identifier: .gregorian)
        let day = cal.startOfDay(for: date)
        var sections: [[DayItem]] = []
        var branchNames: [String] = []
        for offset in 0..<3 {
            guard let d = cal.date(byAdding: .day, value: offset, to: day) else { continue }
            let ms = MarketStore.markets(on: d)
                .map { DayItem(name: $0.name, size: $0.size) }
            sections.append(ms)
            branchNames.append(LunarCalendar.branchName(d))
        }
        return GanJiEntry(date: cal.date(byAdding: .minute, value: 1, to: day) ?? date,
                          sections: sections, branchNames: branchNames)
    }

    func placeholder(in context: Context) -> GanJiEntry { build(Date()) }

    func getSnapshot(in context: Context, completion: @escaping (GanJiEntry) -> Void) {
        completion(build(Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<GanJiEntry>) -> Void) {
        let cal = Calendar(identifier: .gregorian)
        let today = cal.startOfDay(for: Date())
        var entries: [GanJiEntry] = []
        for offset in 0..<8 {
            guard let day = cal.date(byAdding: .day, value: offset, to: today) else { continue }
            entries.append(build(day))
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

// MARK: - 样式

enum GanJiStyle {
    static let green = Color(red: 0.18, green: 0.72, blue: 0.31)
    static let blue = Color(red: 0.18, green: 0.42, blue: 0.90)
    static let orange = Color(red: 0.95, green: 0.55, blue: 0.13)
    static let gray = Color(red: 0.45, green: 0.47, blue: 0.52)

    static func color(for offset: Int) -> Color {
        switch offset {
        case 0: return green
        case 1: return blue
        default: return orange
        }
    }

    static func title(for offset: Int) -> String {
        switch offset {
        case 0: return "今天"
        case 1: return "明天"
        default: return "后天"
        }
    }
}

extension View {
    @ViewBuilder
    func widgetBackground(_ color: Color) -> some View {
        if #available(iOS 17.0, *) {
            containerBackground(for: .widget) { color }
        } else {
            background(color)
        }
    }
}

// MARK: - 小组件视图

struct GanJiWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: GanJiEntry

    private var small: Bool { family == .systemSmall }

    var body: some View {
        ZStack(alignment: .topLeading) {
            if small { smallBody } else if family == .systemMedium { mediumBody } else { largeBody }
        }
        .widgetBackground(Color(red: 0.98, green: 0.98, blue: 0.99))
    }

    // MARK: 小号

    @ViewBuilder
    private var smallBody: some View {
        VStack(alignment: .leading, spacing: 5) {
            header
            if entry.sections[0].isEmpty {
                Text("今天无圩")
                    .font(.system(size: 11))
                    .foregroundColor(GanJiStyle.gray)
            } else {
                ForEach(entry.sections[0].prefix(4)) { item in
                    HStack(spacing: 4) {
                        Circle().fill(GanJiStyle.green).frame(width: 4, height: 4)
                        Text(item.name)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.black.opacity(0.82))
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                }
                if entry.sections[0].count > 4 { Spacer() }
                nextFooter
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 11)
    }

    @ViewBuilder
    private var nextFooter: some View {
        if let next = nextSection {
            HStack(spacing: 4) {
                Circle().fill(GanJiStyle.color(for: next.offset)).frame(width: 4, height: 4)
                Text("\(GanJiStyle.title(for: next.offset)) \(next.names)")
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundColor(GanJiStyle.gray)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
    }

    private var nextSection: (offset: Int, names: String)? {
        for offset in 1...2 {
            let items = entry.sections[offset]
            if !items.isEmpty {
                let names = items.prefix(2).map { $0.name }.joined(separator: " ")
                let suffix = items.count > 2 ? "等\(items.count)圩" : ""
                return (offset, names + suffix)
            }
        }
        return nil
    }

    // MARK: 中号

    private var mediumBody: some View {
        VStack(alignment: .leading, spacing: 6) {
            header
            HStack(alignment: .top, spacing: 12) {
                ForEach(0..<3, id: \.self) { offset in
                    column(offset)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 11)
    }

    private func column(_ offset: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Text(GanJiStyle.title(for: offset))
                    .font(.system(size: 11.5, weight: .bold))
                    .foregroundColor(GanJiStyle.color(for: offset))
                Text(entry.branchNames[offset] + "日")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(GanJiStyle.gray)
            }
            if entry.sections[offset].isEmpty {
                Text("无圩")
                    .font(.system(size: 11))
                    .foregroundColor(GanJiStyle.gray.opacity(0.8))
            } else {
                ForEach(Array(entry.sections[offset].prefix(4).enumerated()), id: \.element.id) { _, item in
                    Text(item.name)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.black.opacity(0.82))
                        .lineLimit(1)
                }
                if entry.sections[offset].count > 4 {
                    Text("还有 \(entry.sections[offset].count - 4) 个")
                        .font(.system(size: 9))
                        .foregroundColor(GanJiStyle.gray)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: 大号

    private var largeBody: some View {
        VStack(alignment: .leading, spacing: 9) {
            header
            ForEach(0..<3, id: \.self) { offset in
                sectionRow(offset)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
    }

    private func sectionRow(_ offset: Int) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 5) {
                Text(GanJiStyle.title(for: offset))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(GanJiStyle.color(for: offset))
                Text(entry.branchNames[offset] + "日")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(GanJiStyle.gray)
                Spacer(minLength: 2)
            }
            if entry.sections[offset].isEmpty {
                Text("无圩")
                    .font(.system(size: 12))
                    .foregroundColor(GanJiStyle.gray.opacity(0.8))
            } else {
                Text(entry.sections[offset].map { $0.name }.joined(separator: " · "))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.black.opacity(0.85))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
    }

    // MARK: 头部

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text("赶集日记")
                .font(.system(size: small ? 12 : 14, weight: .bold))
                .foregroundColor(.black.opacity(0.85))
            Spacer(minLength: 2)
            Text("\(LunarCalendar.shortDate(entry.date)) \(LunarCalendar.lunarText(entry.date))")
                .font(.system(size: small ? 8.5 : 10, weight: .medium))
                .foregroundColor(GanJiStyle.gray)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }
}

// MARK: - 小组件

struct GanJiWidget: Widget {
    let kind: String = "GanJiWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MarketProvider()) { entry in
            GanJiWidgetView(entry: entry)
        }
        .configurationDisplayName("赶集日记")
        .description("看看今天、明天、后天哪几个圩开市。")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

@main
struct GanJiWidgetBundle: WidgetBundle {
    var body: some Widget {
        GanJiWidget()
    }
}
