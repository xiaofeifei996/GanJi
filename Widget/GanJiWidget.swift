import WidgetKit
import SwiftUI
import UIKit

struct DayItem: Identifiable {
    let id: String
    let name: String
    var short: String { name.replacingOccurrences(of: "圩", with: "") }
}

struct GanJiEntry: TimelineEntry {
    let date: Date
    let days: [Date]
    let sections: [[DayItem]]
}

struct MarketProvider: TimelineProvider {
    private func build(_ date: Date) -> GanJiEntry {
        let cal = Calendar(identifier: .gregorian)
        let day = cal.startOfDay(for: date)
        let days = (0..<3).map { cal.date(byAdding: .day, value: $0, to: day)! }
        return GanJiEntry(date: date, days: days, sections: days.map { d in
            MarketStore.markets(on: d).map { DayItem(id: $0.id, name: $0.name) }
        })
    }

    func placeholder(in context: Context) -> GanJiEntry { build(Date()) }
    func getSnapshot(in context: Context, completion: @escaping (GanJiEntry) -> Void) {
        completion(build(Date()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<GanJiEntry>) -> Void) {
        let now = Date()
        let cal = Calendar(identifier: .gregorian)
        let today = cal.startOfDay(for: now)
        var entries = [build(now)]
        for offset in 1..<8 {
            entries.append(build(cal.date(byAdding: .day, value: offset, to: today)!))
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

struct HanLiBackground: View {
    let square: Bool
    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color(red: 0.03, green: 0.08, blue: 0.13)
                if let path = Bundle.main.path(forResource: square ? "HanLi-square" : "HanLi-wide", ofType: "jpg"),
                   let image = UIImage(contentsOfFile: path) {
                    Image(uiImage: image).resizable().scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height).clipped()
                }
                LinearGradient(stops: [
                    .init(color: Color(red: 0.027, green: 0.078, blue: 0.125).opacity(0.95), location: 0),
                    .init(color: Color(red: 0.027, green: 0.078, blue: 0.125).opacity(0.72), location: 0.45),
                    .init(color: .black.opacity(0.02), location: 0.88)
                ], startPoint: .leading, endPoint: .trailing)
            }
            .frame(width: geo.size.width, height: geo.size.height).clipped()
        }
    }
}

struct GanJiWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: GanJiEntry
    private let mint = Color(red: 0.51, green: 0.94, blue: 0.89)
    private var small: Bool { family == .systemSmall }
    private var large: Bool { family == .systemLarge }

    var body: some View {
        Group {
            if #available(iOS 17.0, *) {
                layout.containerBackground(for: .widget) {
                    HanLiBackground(square: family != .systemMedium)
                }
            } else {
                layout.background(HanLiBackground(square: family != .systemMedium))
            }
        }
    }

    private func names(_ offset: Int, short: Bool) -> String {
        let items = entry.sections[offset]
        return items.isEmpty ? "无圩" : items.map { short ? $0.short : $0.name }.joined(separator: " · ")
    }
    private func numericDate(_ date: Date) -> String {
        let c = Calendar(identifier: .gregorian).dateComponents([.month, .day], from: date)
        return "\(c.month!)/\(c.day!)"
    }

    private var layout: some View {
        GeometryReader { geo in
            VStack(alignment: .leading, spacing: 0) {
                Text("赶集日记")
                    .font(.system(size: small ? 11 : 12, weight: .medium))
                    .tracking(1.5).foregroundColor(.white.opacity(0.75))
                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Text(LunarCalendar.shortDate(entry.date))
                        .font(.system(size: small ? 23 : large ? 40 : 29, weight: .bold))
                    if !small {
                        Text(LunarCalendar.weekdayText(entry.date))
                            .font(.system(size: 12)).foregroundColor(.white.opacity(0.85))
                    }
                }
                .lineLimit(1).minimumScaleFactor(0.8).padding(.top, 4)
                Text("农历\(LunarCalendar.lunarText(entry.date)) · \(LunarCalendar.ganzhiName(entry.date))日")
                    .font(.system(size: small ? 10 : large ? 14 : 11))
                    .foregroundColor(Color(red: 0.62, green: 0.77, blue: 0.82))
                    .lineLimit(1).minimumScaleFactor(0.7).padding(.top, 1)

                if large { Spacer(minLength: 12) }
                today.padding(.top, small ? 7 : 6)
                    .frame(maxWidth: small ? .infinity : geo.size.width * 0.76, alignment: .leading)
                Spacer(minLength: 2)
                VStack(alignment: .leading, spacing: large ? 12 : 3) {
                    future(1)
                    future(2)
                }
            }
            .foregroundColor(.white)
            .shadow(color: .black.opacity(0.5), radius: 3, x: 0, y: 1)
            .padding(.horizontal, small ? 12 : 15)
            .padding(.vertical, small ? 11 : large ? 20 : 10)
            .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
        }
    }

    @ViewBuilder private var today: some View {
        if small || large {
            VStack(alignment: .leading, spacing: large ? 9 : 3) {
                Text("今天").font(.system(size: small ? 10 : 14, weight: .semibold)).foregroundColor(mint)
                Text(names(0, short: small))
                    .font(.system(size: small ? 15 : 27, weight: .bold))
                    .lineLimit(large ? 2 : 1).minimumScaleFactor(0.65)
            }
        } else {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("今天").font(.system(size: 11, weight: .semibold)).foregroundColor(mint)
                Text(names(0, short: false)).font(.system(size: 21, weight: .bold))
                    .lineLimit(1).minimumScaleFactor(0.65)
            }
        }
    }

    private func future(_ offset: Int) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: small ? 3 : 5) {
            Text(offset == 1 ? "明天" : "后天")
                .font(.system(size: small ? 10 : large ? 14 : 11, weight: .semibold)).foregroundColor(mint)
            Text(numericDate(entry.days[offset]))
                .font(.system(size: small ? 9 : large ? 13 : 10)).foregroundColor(.white.opacity(0.62))
            Text(names(offset, short: offset == 2 || small))
                .font(.system(size: small ? 10 : large ? 17 : 11))
                .foregroundColor(.white.opacity(0.85))
                .lineLimit(1).minimumScaleFactor(0.65)
        }
    }
}

struct GanJiWidget: Widget {
    let kind = "GanJiWidget"
    var body: some WidgetConfiguration {
        configuration.contentMarginsDisabled()
    }
    private var configuration: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MarketProvider()) { entry in
            GanJiWidgetView(entry: entry)
        }
        .configurationDisplayName("赶集日记")
        .description("韩立背景 · 公历农历干支 · 今日及明后天圩日")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

@main struct GanJiWidgetBundle: WidgetBundle {
    var body: some Widget { GanJiWidget() }
}
