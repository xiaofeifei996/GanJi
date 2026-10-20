import WidgetKit
import SwiftUI

// MARK: - 数据

struct DayItem: Identifiable {
    let id = UUID()
    let name: String
    let size: String

    /// 去掉“圩”字，用于页脚紧凑排版：大妙圩 → 大妙
    var short: String { name.replacingOccurrences(of: "圩", with: "") }
}

struct GanJiEntry: TimelineEntry {
    let date: Date
    /// 0/1/2 = 今天/明天/后天
    let sections: [[DayItem]]
    let branchNames: [String]     // 卯 / 辰 / 巳
    let ganzhiNames: [String]     // 丁卯 / 戊辰 / 己巳
    let todayZodiac: String       // 兔
}

struct MarketProvider: TimelineProvider {
    private func build(_ date: Date) -> GanJiEntry {
        let cal = Calendar.current
        let day = cal.startOfDay(for: date)
        var sections: [[DayItem]] = []
        var branchNames: [String] = []
        var ganzhiNames: [String] = []
        for offset in 0..<3 {
            guard let d = cal.date(byAdding: .day, value: offset, to: day) else { continue }
            sections.append(
                MarketStore.markets(on: d).map { DayItem(name: $0.name, size: $0.size) }
            )
            branchNames.append(LunarCalendar.branchName(d))
            ganzhiNames.append(LunarCalendar.ganzhiName(d))
        }
        return GanJiEntry(date: cal.date(byAdding: .minute, value: 1, to: day) ?? date,
                          sections: sections,
                          branchNames: branchNames,
                          ganzhiNames: ganzhiNames,
                          todayZodiac: LunarCalendar.zodiacName(day))
    }

    func placeholder(in context: Context) -> GanJiEntry { build(Date()) }

    func getSnapshot(in context: Context, completion: @escaping (GanJiEntry) -> Void) {
        completion(build(Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<GanJiEntry>) -> Void) {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        var entries: [GanJiEntry] = []
        for offset in 0..<8 {
            guard let d = cal.date(byAdding: .day, value: offset, to: today) else { continue }
            entries.append(build(d))
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

// MARK: - 视觉

enum Paper {
    static let bg    = Color(red: 0.984, green: 0.961, blue: 0.914)   // 宣纸
    static let ink   = Color(red: 0.165, green: 0.129, blue: 0.094)   // 墨
    static let red   = Color(red: 0.706, green: 0.204, blue: 0.122)   // 朱红
    static let muted = Color(red: 0.604, green: 0.545, blue: 0.475)   // 灰褐
    static let hair  = Color(red: 0.706, green: 0.204, blue: 0.122).opacity(0.30)
}

struct Seal: View {
    var side: CGFloat
    var body: some View {
        RoundedRectangle(cornerRadius: side * 0.24, style: .continuous)
            .fill(Paper.red)
            .frame(width: side, height: side)
            .overlay(
                Text("圩")
                    .font(.system(size: side * 0.60, weight: .bold))
                    .foregroundColor(Paper.bg)
            )
    }
}

struct DashedRule: View {
    var body: some View {
        GeometryReader { geo in
            Path { p in
                p.move(to: CGPoint(x: 0, y: 0.5))
                p.addLine(to: CGPoint(x: geo.size.width, y: 0.5))
            }
            .stroke(Paper.hair, style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
        }
        .frame(height: 1)
    }
}

extension View {
    @ViewBuilder
    func paperBackground() -> some View {
        if #available(iOS 17.0, *) {
            containerBackground(for: .widget) { Paper.bg }
        } else {
            background(Paper.bg)
        }
    }
}

// MARK: - 小组件

struct GanJiWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: GanJiEntry

    var body: some View {
        Group {
            switch family {
            case .systemSmall:  smallBody
            case .systemLarge:  largeBody
            default:            mediumBody
            }
        }
        .paperBackground()
    }

    // 共用部件 ------------------------------------------------------------

    private func header(titleSize: CGFloat) -> some View {
        HStack(spacing: 7) {
            Seal(side: titleSize + 10)
            Text("赶集日记")
                .font(.system(size: titleSize, weight: .bold))
                .foregroundColor(Paper.ink)
            Spacer(minLength: 4)
            Text("\(LunarCalendar.shortDate(entry.date)) \(LunarCalendar.lunarText(entry.date))")
                .font(.system(size: max(titleSize - 3, 8.5), weight: .medium))
                .foregroundColor(Paper.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
    }

    private func hero(gzSize: CGFloat, subSize: CGFloat) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(entry.ganzhiNames[0])
                .font(.system(size: gzSize, weight: .heavy))
                .foregroundColor(Paper.red)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text("\(entry.branchNames[0])日 · \(entry.todayZodiac) · 三日一圩")
                .font(.system(size: subSize, weight: .medium))
                .foregroundColor(Paper.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 0)
        }
    }

    private func marketRow(_ item: DayItem, size: CGFloat) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Paper.red)
                .frame(width: max(size * 0.32, 4), height: max(size * 0.32, 4))
            Text(item.name)
                .font(.system(size: size, weight: .semibold))
                .foregroundColor(Paper.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }

    private func dayTitle(_ offset: Int) -> String {
        switch offset {
        case 0: return "今天"
        case 1: return "明天"
        default: return "后天"
        }
    }

    private func compactNames(_ offset: Int, limit: Int) -> String {
        let items = entry.sections[offset]
        guard !items.isEmpty else { return "无圩" }
        let names = items.prefix(limit).map { $0.short }.joined(separator: " · ")
        return items.count > limit ? "\(names) 等\(items.count)圩" : names
    }

    // 小号 ----------------------------------------------------------------

    private var smallBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            header(titleSize: 11.5)
            Spacer(minLength: 5)
            hero(gzSize: 25, subSize: 9)
            Spacer(minLength: 6)
            VStack(alignment: .leading, spacing: 3) {
                if entry.sections[0].isEmpty {
                    Text("今天无圩")
                        .font(.system(size: 12))
                        .foregroundColor(Paper.muted)
                } else {
                    ForEach(entry.sections[0].prefix(3)) { item in
                        marketRow(item, size: 12.5)
                    }
                }
            }
            Spacer(minLength: 4)
            HStack(spacing: 5) {
                Text("明天")
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundColor(Paper.red)
                Text(compactNames(1, limit: 2))
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundColor(Paper.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // 中号 ----------------------------------------------------------------

    private var mediumBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            header(titleSize: 12.5)
            Spacer(minLength: 6)
            hero(gzSize: 26, subSize: 10)
            DashedRule()
                .padding(.top, 7)
                .padding(.bottom, 8)
            HStack(spacing: 14) {
                if entry.sections[0].isEmpty {
                    Text("今天无圩")
                        .font(.system(size: 13))
                        .foregroundColor(Paper.muted)
                } else {
                    ForEach(entry.sections[0].prefix(4)) { item in
                        marketRow(item, size: 14)
                    }
                }
                Spacer(minLength: 0)
            }
            Spacer(minLength: 4)
            HStack(spacing: 6) {
                Text("明天")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Paper.red)
                Text(compactNames(1, limit: 2))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Paper.muted)
                Text("｜")
                    .font(.system(size: 10))
                    .foregroundColor(Paper.hair)
                Text("后天")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Paper.red)
                Text(compactNames(2, limit: 3))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Paper.muted)
                Spacer(minLength: 0)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // 大号 ----------------------------------------------------------------

    private var largeBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            header(titleSize: 13.5)
            Spacer(minLength: 8)
            hero(gzSize: 38, subSize: 11)
            DashedRule()
                .padding(.top, 9)
                .padding(.bottom, 10)

            ForEach(0..<3, id: \.self) { offset in
                if offset > 0 {
                    DashedRule().padding(.vertical, 9)
                }
                largeSection(offset)
                if offset < 2 { Spacer(minLength: 6) }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func largeSection(_ offset: Int) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(dayTitle(offset))
                    .font(.system(size: 11.5, weight: .bold))
                    .foregroundColor(Paper.red)
                Text("\(entry.branchNames[offset])日")
                    .font(.system(size: 10))
                    .foregroundColor(Paper.muted)
                Spacer(minLength: 0)
            }
            if entry.sections[offset].isEmpty {
                Text("无圩")
                    .font(.system(size: 15))
                    .foregroundColor(Paper.muted)
            } else {
                HStack(spacing: 16) {
                    ForEach(entry.sections[offset].prefix(4)) { item in
                        marketRow(item, size: offset == 0 ? 19 : 16)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }
}

struct GanJiWidget: Widget {
    let kind: String = "GanJiWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MarketProvider()) { entry in
            GanJiWidgetView(entry: entry)
        }
        .configurationDisplayName("赶集日记")
        .description("今天、明天、后天，哪几个圩开市。")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

@main
struct GanJiWidgetBundle: WidgetBundle {
    var body: some Widget {
        GanJiWidget()
    }
}
