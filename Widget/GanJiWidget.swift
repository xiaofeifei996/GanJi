import WidgetKit
import SwiftUI

struct MarketEntry: TimelineEntry {
    let date: Date
    let rows: [MarketDay]
}

struct MarketProvider: TimelineProvider {
    func placeholder(in context: Context) -> MarketEntry {
        MarketEntry(date: Date(), rows: MarketStore.upcoming(from: Date()))
    }

    func getSnapshot(in context: Context, completion: @escaping (MarketEntry) -> Void) {
        completion(MarketEntry(date: Date(), rows: MarketStore.upcoming(from: Date())))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MarketEntry>) -> Void) {
        let cal = Calendar(identifier: .gregorian)
        let today = cal.startOfDay(for: Date())
        var entries: [MarketEntry] = []
        for offset in 0..<8 {
            guard let day = cal.date(byAdding: .day, value: offset, to: today) else { continue }
            let stamp = cal.date(byAdding: .minute, value: 1, to: day) ?? day
            entries.append(MarketEntry(date: stamp, rows: MarketStore.upcoming(from: day)))
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

    static func color(for days: Int) -> Color {
        switch days {
        case 0: return green
        case 1: return blue
        case 2: return orange
        default: return gray
        }
    }
}

struct DayPill: View {
    let days: Int
    var compact: Bool = false

    var body: some View {
        let c = GanJiStyle.color(for: days)
        Text(dayText)
            .font(.system(size: compact ? 9 : 10, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, compact ? 5 : 6)
            .padding(.vertical, compact ? 1.5 : 2)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous).fill(c)
            )
    }

    private var dayText: String {
        switch days {
        case 0: return "今天"
        case 1: return "明天"
        case 2: return "后天"
        default: return "\(days)天后"
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

// MARK: - 小组件

struct GanJiWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: MarketEntry

    private var small: Bool { family == .systemSmall }

    var body: some View {
        VStack(alignment: .leading, spacing: small ? 5 : 8) {
            header
            if small {
                ForEach(entry.rows.prefix(4)) { row in
                    compactRow(row)
                }
            } else {
                ForEach(entry.rows) { row in
                    fullRow(row)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .widgetBackground(Color(red: 0.98, green: 0.98, blue: 0.99))
    }

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

    private func compactRow(_ row: MarketDay) -> some View {
        HStack(spacing: 4) {
            Text(row.market.name)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.black.opacity(0.82))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            Spacer(minLength: 2)
            DayPill(days: row.daysAhead, compact: true)
        }
    }

    private func fullRow(_ row: MarketDay) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(row.market.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.black.opacity(0.85))
                    Text(row.market.size)
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1.5)
                        .background(RoundedRectangle(cornerRadius: 3).fill(GanJiStyle.blue.opacity(0.85)))
                }
                Text("属相 \(row.animals) · \(LunarCalendar.shortDate(row.date))")
                    .font(.system(size: 10))
                    .foregroundColor(GanJiStyle.gray)
                    .lineLimit(1)
            }
            Spacer(minLength: 2)
            DayPill(days: row.daysAhead)
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
        .description("看看今天、明天附近哪个乡镇赶集。")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

@main
struct GanJiWidgetBundle: WidgetBundle {
    var body: some Widget {
        GanJiWidget()
    }
}
