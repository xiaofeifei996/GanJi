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
        let next = Calendar.current.date(byAdding: .hour, value: 1, to: now) ?? now.addingTimeInterval(3600)
        completion(Timeline(entries: [makeEntry(now)], policy: .after(next)))
    }
}

private enum Palette {
    static let cream = Color(red: 0.98, green: 0.95, blue: 0.86)
    static let mist = Color(red: 0.83, green: 0.88, blue: 0.82)
    static let jade = Color(red: 0.18, green: 0.39, blue: 0.34)
    static let deep = Color(red: 0.035, green: 0.15, blue: 0.16)
    static let cinnabar = Color(red: 0.78, green: 0.27, blue: 0.18)
    static let gold = Color(red: 0.91, green: 0.70, blue: 0.39)
}

// Shared photo background asset used by all widget families.
private struct LandscapeBackdrop: View {
    var body: some View {
        GeometryReader { proxy in
            Image("GanJiLandscape")
                .resizable()
                .scaledToFill()
                .frame(width: proxy.size.width, height: proxy.size.height)
                .clipped()
                .overlay(
                    LinearGradient(
                        colors: [.clear, Color.black.opacity(0.12), Color.black.opacity(0.42)],
                        startPoint: .center,
                        endPoint: .bottom
                    )
                )
        }
    }
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
        .modifier(WidgetBackgroundStyle(background: LandscapeBackdrop()))
    }

    private func dateText(_ date: Date) -> String {
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
        ["今日", "明日", "后日"][index]
    }

    private var pocketCalendar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("赶集日记")
                    .font(.system(size: 11, weight: .black, design: .serif))
                    .tracking(1.5)
                Spacer()
                Text("圩历")
                    .font(.system(size: 9, weight: .bold))
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Palette.cinnabar, in: Capsule())
            }
            .foregroundStyle(Palette.cream)

            Spacer(minLength: 3)

            Text(entry.date.formatted(.dateTime.day().locale(Locale(identifier: "zh_CN"))))
                .font(.system(size: 48, weight: .regular, design: .serif))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.7)
                .lineLimit(1)

            Text(weekday(entry.date) + " · " + dateText(entry.date))
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Palette.mist)

            Spacer(minLength: 5)

            HStack(spacing: 5) {
                Circle().fill(Palette.gold).frame(width: 5, height: 5)
                Text(marketText(0, limit: 2))
                    .font(.system(size: 10, weight: .bold, design: .serif))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)
            }
            .padding(.horizontal, 8).padding(.vertical, 7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.deep.opacity(0.62), in: RoundedRectangle(cornerRadius: 10))
        }
        .padding(12)
    }

    private var horizonCalendar: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("山河圩历")
                        .font(.system(size: 17, weight: .bold, design: .serif))
                        .foregroundStyle(.white)
                    Text("把好日子，赶进生活里")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(Palette.mist)
                }
                Spacer()
                Text(dateText(entry.date))
                    .font(.system(size: 12, weight: .bold, design: .serif))
                    .foregroundStyle(Palette.cream)
            }

            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { index in
                    VStack(alignment: .leading, spacing: 5) {
                        Text(dayTitle(index))
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Palette.gold)
                        if entry.days.indices.contains(index) {
                            Text(entry.days[index].date.formatted(.dateTime.day().locale(Locale(identifier: "zh_CN"))))
                                .font(.system(size: 25, weight: .regular, design: .serif))
                                .foregroundStyle(.white)
                        }
                        Text(marketText(index, limit: 2))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Palette.cream)
                            .lineLimit(2)
                            .minimumScaleFactor(0.72)
                        Spacer(minLength: 0)
                    }
                    .padding(9)
                    .frame(maxWidth: .infinity, minHeight: 78, alignment: .leading)
                    .background(Palette.deep.opacity(index == 0 ? 0.76 : 0.52),
                                in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12)
                        .stroke(Palette.cream.opacity(index == 0 ? 0.32 : 0.14), lineWidth: 1))
                }
            }
        }
        .padding(13)
    }

    private var longScroll: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("赶集长卷")
                        .font(.system(size: 21, weight: .bold, design: .serif))
                        .foregroundStyle(.white)
                    Text("今日有圩 · 三日行程")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Palette.mist)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 1) {
                    Text(entry.date.formatted(.dateTime.day().locale(Locale(identifier: "zh_CN"))))
                        .font(.system(size: 31, weight: .regular, design: .serif))
                        .foregroundStyle(Palette.cream)
                    Text(entry.date.formatted(.dateTime.year().month().locale(Locale(identifier: "zh_CN"))))
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(Palette.mist)
                }
            }

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Capsule().fill(Palette.cinnabar).frame(width: 17, height: 4)
                    Text("今日主场")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Palette.gold)
                }
                Text(marketText(0, limit: 5))
                    .font(.system(size: 23, weight: .bold, design: .serif))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.68)
                Text(entry.days.first?.markets.isEmpty == false ? "择一处好圩，慢慢逛一程" : "今天暂无收藏集市开圩")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Palette.cream)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.deep.opacity(0.64), in: RoundedRectangle(cornerRadius: 13))

            HStack(spacing: 0) {
                ForEach(1...2, id: \.self) { index in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(dayTitle(index))
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Palette.gold)
                        Text(marketText(index, limit: 4))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    if index == 1 {
                        Rectangle().fill(Palette.cream.opacity(0.35)).frame(width: 1, height: 34)
                            .padding(.horizontal, 12)
                    }
                }
            }
            Spacer(minLength: 0)
            HStack {
                Text("依照你的收藏集市整理")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Palette.mist)
                Spacer()
                Text("山水有期 · 赶集有时")
                    .font(.system(size: 9, weight: .semibold, design: .serif))
                    .foregroundStyle(Palette.cream)
            }
        }
        .padding(14)
    }
}

private struct WidgetBackgroundStyle<Background: View>: ViewModifier {
    let background: Background

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOSApplicationExtension 17.0, *) {
            content.containerBackground(for: .widget) { background }
        } else {
            content.background(background)
        }
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
