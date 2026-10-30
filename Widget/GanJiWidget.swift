import WidgetKit
import SwiftUI

struct WidgetDay: Identifiable {
    let date: Date
    let markets: [String]
    var id: Date { date }
}

struct GanJiEntry: TimelineEntry {
    let date: Date
    let days: [WidgetDay]
}

struct MarketProvider: TimelineProvider {
    private let groupID = "group.com.ganji.diary"

    private func makeEntry(_ date: Date) -> GanJiEntry {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        let dates = (0..<3).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
        let shared = UserDefaults(suiteName: groupID)
        let ids = Set(shared?.stringArray(forKey: "GanJiFavoriteMarketIDs") ?? [])
        let favoriteData = shared?.data(forKey: "GanJiFavoriteMarketsData") ?? Data()
        let homeData = shared?.data(forKey: "GanJiHomeMarketsData") ?? Data()
        let favorites = (try? JSONDecoder().decode([Market].self, from: favoriteData)) ?? []
        let home = (try? JSONDecoder().decode([Market].self, from: homeData)) ?? []
        let all = MarketStore.load()
        let source = !favorites.isEmpty ? favorites : (!home.isEmpty ? home : all)
        let visible = ids.isEmpty ? source : source.filter { ids.contains($0.id) }
        let days = dates.map { day in
            WidgetDay(date: day, markets: visible
                .filter { MarketStore.opens(on: day, market: $0) }
                .sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
                .map(\.name))
        }
        return GanJiEntry(date: date, days: days)
    }

    func placeholder(in context: Context) -> GanJiEntry { makeEntry(Date()) }
    func getSnapshot(in context: Context, completion: @escaping (GanJiEntry) -> Void) { completion(makeEntry(Date())) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<GanJiEntry>) -> Void) {
        let now = Date()
        completion(Timeline(entries: [makeEntry(now)], policy: .after(Calendar.current.date(byAdding: .hour, value: 1, to: now) ?? now.addingTimeInterval(3600))))
    }
}

private enum Ink {
    static let gold = Color(red: 0.91, green: 0.72, blue: 0.40)
    static let ivory = Color(red: 0.98, green: 0.95, blue: 0.86)
    static let pale = Color(red: 0.86, green: 0.85, blue: 0.76)
    static let cinnabar = Color(red: 0.72, green: 0.24, blue: 0.17)
}

struct GanJiWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: GanJiEntry

    var body: some View {
        Group {
            switch family {
            case .systemSmall: pocketCalendar
            case .systemMedium: horizonCalendar
            default: longScroll
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .unredacted()
    }

    private func dateText(_ date: Date, style: Date.FormatStyle.DateStyle = .numeric) -> String {
        date.formatted(.dateTime.month(.twoDigits).day(.twoDigits).locale(Locale(identifier: "zh_CN")))
    }

    private func weekday(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.wide).locale(Locale(identifier: "zh_CN")))
    }

    private func marketText(_ index: Int, limit: Int = 3) -> String {
        guard entry.days.indices.contains(index) else { return "暂无圩日" }
        let names = entry.days[index].markets
        return names.isEmpty ? "今日歇圩" : names.prefix(limit).joined(separator: " · ")
    }

    private func dayTitle(_ index: Int) -> String {
        ["今日", "明日", "后日"].indices.contains(index) ? ["今日", "明日", "后日"][index] : "日期"
    }

    private var pocketCalendar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center) {
                Text("赶集日记")
                    .font(.system(size: 10, weight: .black, design: .serif))
                    .tracking(2)
                Spacer()
                Circle().fill(Ink.gold).frame(width: 5, height: 5)
                Text("圩历")
                    .font(.system(size: 9, weight: .semibold))
            }
            .foregroundStyle(Ink.gold)

            Spacer(minLength: 7)

            Text(entry.date.formatted(.dateTime.day().locale(Locale(identifier: "zh_CN"))))
                .font(.system(size: 43, weight: .regular, design: .serif))
                .foregroundStyle(Ink.ivory)
                .minimumScaleFactor(0.7)
                .lineLimit(1)

            Text(weekday(entry.date) + " · " + dateText(entry.date))
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(Ink.pale)

            Spacer(minLength: 7)

            Rectangle().fill(Ink.gold.opacity(0.8)).frame(height: 1)
            Text(marketText(0, limit: 2))
                .font(.system(size: 12, weight: .bold, design: .serif))
                .foregroundStyle(Ink.ivory)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
                .padding(.top, 7)
        }
        .padding(13)
    }

    private var horizonCalendar: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("山河圩历")
                        .font(.system(size: 17, weight: .bold, design: .serif))
                        .foregroundStyle(Ink.ivory)
                    Text("把好日子，赶进生活里")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(Ink.pale)
                }
                Spacer()
                Text(dateText(entry.date))
                    .font(.system(size: 12, weight: .bold, design: .serif))
                    .foregroundStyle(Ink.gold)
            }

            HStack(alignment: .top, spacing: 0) {
                ForEach(0..<3, id: \.self) { index in
                    if index > 0 {
                        Rectangle().fill(Ink.gold.opacity(0.42)).frame(width: 1, height: 61)
                            .padding(.horizontal, 9)
                    }
                    VStack(alignment: .leading, spacing: 5) {
                        Text(dayTitle(index))
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Ink.gold)
                        if entry.days.indices.contains(index) {
                            Text(entry.days[index].date.formatted(.dateTime.day().locale(Locale(identifier: "zh_CN"))))
                                .font(.system(size: 23, weight: .regular, design: .serif))
                                .foregroundStyle(Ink.ivory)
                        }
                        Text(marketText(index, limit: 2))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Ink.pale)
                            .lineLimit(2)
                            .minimumScaleFactor(0.72)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(14)
    }

    private var longScroll: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("赶集长卷")
                        .font(.system(size: 21, weight: .bold, design: .serif))
                        .foregroundStyle(Ink.ivory)
                    Text("今日有圩 · 三日行程")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Ink.pale)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(entry.date.formatted(.dateTime.day().locale(Locale(identifier: "zh_CN"))))
                        .font(.system(size: 31, weight: .regular, design: .serif))
                        .foregroundStyle(Ink.gold)
                    Text(entry.date.formatted(.dateTime.year().month().locale(Locale(identifier: "zh_CN"))))
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(Ink.pale)
                }
            }

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Capsule().fill(Ink.cinnabar).frame(width: 17, height: 4)
                    Text("今日主场")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Ink.gold)
                }
                Text(marketText(0, limit: 5))
                    .font(.system(size: 24, weight: .bold, design: .serif))
                    .foregroundStyle(Ink.ivory)
                    .lineLimit(2)
                    .minimumScaleFactor(0.68)
                Text(entry.days.first?.markets.isEmpty == false ? "择一处好圩，慢慢逛一程" : "今天暂无收藏集市开圩")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Ink.pale)
            }
            .padding(.vertical, 9)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 0) {
                ForEach(1...2, id: \.self) { index in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(dayTitle(index))
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Ink.gold)
                        Text(marketText(index, limit: 4))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Ink.ivory)
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    if index == 1 {
                        Rectangle().fill(Ink.gold.opacity(0.35)).frame(width: 1, height: 34)
                            .padding(.horizontal, 12)
                    }
                }
            }

            Spacer(minLength: 0)
            HStack {
                Text("依照你的收藏集市整理")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Ink.pale.opacity(0.9))
                Spacer()
                Text("山水有期 · 赶集有时")
                    .font(.system(size: 9, weight: .semibold, design: .serif))
                    .foregroundStyle(Ink.gold)
            }
        }
        .padding(15)
    }
}

struct GanJiWidget: Widget {
    let kind = "GanJiWidget"
    var body: some WidgetConfiguration {
        let configuration = StaticConfiguration(kind: kind, provider: MarketProvider()) { entry in
            GanJiWidgetView(entry: entry)
        }

        if #available(iOSApplicationExtension 17.0, *) {
            return configuration
                .contentMarginsDisabled()
                .configurationDisplayName("赶集日记")
                .description("三款东方圩市主题小组件，查看未来三天圩期")
                .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        } else {
            return configuration
                .configurationDisplayName("赶集日记")
                .description("三款东方圩市主题小组件，查看未来三天圩期")
                .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        }
    }
}

@main
struct GanJiWidgetBundle: WidgetBundle {
    var body: some Widget { GanJiWidget() }
}
