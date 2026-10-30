import WidgetKit
import SwiftUI

// MARK: - Widget data

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

        let source: [Market]
        if !favorites.isEmpty {
            source = favorites
        } else if !home.isEmpty {
            source = home
        } else {
            source = all
        }

        let visible = ids.isEmpty ? source : source.filter { ids.contains($0.id) }
        let days = dates.map { day in
            WidgetDay(
                date: day,
                markets: visible
                    .filter { MarketStore.opens(on: day, market: $0) }
                    .sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
                    .map(\.name)
            )
        }
        return GanJiEntry(date: date, days: days)
    }

    func placeholder(in context: Context) -> GanJiEntry { makeEntry(Date()) }

    func getSnapshot(in context: Context, completion: @escaping (GanJiEntry) -> Void) {
        completion(makeEntry(Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<GanJiEntry>) -> Void) {
        let now = Date()
        let entry = makeEntry(now)
        let next = Calendar.current.date(byAdding: .hour, value: 1, to: now) ?? now.addingTimeInterval(3600)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

// MARK: - A clean, image-free visual system

private enum WidgetPalette {
    static let paper = Color(red: 0.96, green: 0.94, blue: 0.87)
    static let ink = Color(red: 0.12, green: 0.20, blue: 0.17)
    static let muted = Color(red: 0.38, green: 0.43, blue: 0.38)
    static let orange = Color(red: 0.82, green: 0.31, blue: 0.10)
    static let sage = Color(red: 0.77, green: 0.82, blue: 0.66)
}

private struct WidgetBackdrop: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.88, green: 0.89, blue: 0.78),
                    Color(red: 0.78, green: 0.84, blue: 0.76),
                    Color(red: 0.91, green: 0.86, blue: 0.75)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            GeometryReader { proxy in
                Circle()
                    .fill(.white.opacity(0.16))
                    .frame(width: proxy.size.width * 0.72)
                    .offset(x: proxy.size.width * 0.48, y: -proxy.size.height * 0.28)
                Circle()
                    .stroke(.white.opacity(0.18), lineWidth: 1)
                    .frame(width: proxy.size.width * 0.92)
                    .offset(x: -proxy.size.width * 0.42, y: proxy.size.height * 0.62)
            }
        }
        .accessibilityHidden(true)
    }
}

private struct WidgetBackground: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content.containerBackground(for: .widget) { WidgetBackdrop() }
        } else {
            content.background(WidgetBackdrop())
        }
    }
}

struct GanJiWidgetView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var colorScheme
    let entry: GanJiEntry

    private var ink: Color { colorScheme == .dark ? .white : WidgetPalette.ink }
    private var muted: Color { colorScheme == .dark ? .white.opacity(0.72) : WidgetPalette.muted }

    var body: some View {
        Group {
            switch family {
            case .systemSmall: small
            case .systemMedium: medium
            default: large
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .modifier(WidgetBackground())
        .unredacted()
    }

    private func names(_ index: Int, limit: Int = 3) -> String {
        guard entry.days.indices.contains(index) else { return "暂无数据" }
        let values = entry.days[index].markets
        return values.isEmpty ? "暂无圩日" : values.prefix(limit).joined(separator: " · ")
    }

    private func dateLabel(_ date: Date) -> String {
        date.formatted(
            .dateTime.month(.twoDigits).day(.twoDigits).weekday(.wide).locale(Locale(identifier: "zh_CN"))
        )
    }

    private func heading(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 17, weight: .bold, design: .serif))
                .foregroundStyle(ink)
            Text(subtitle)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(muted)
        }
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("赶集日记")
                    .font(.system(size: 12, weight: .heavy, design: .serif))
                    .tracking(2)
                    .foregroundStyle(WidgetPalette.orange)
                Spacer()
                Text("今日")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(WidgetPalette.ink)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(WidgetPalette.sage.opacity(0.8), in: Capsule())
            }
            Text(names(0, limit: 2))
                .font(.system(size: 22, weight: .heavy, design: .serif))
                .foregroundStyle(ink)
                .lineLimit(3)
                .minimumScaleFactor(0.62)
            Spacer(minLength: 0)
            Rectangle().fill(WidgetPalette.orange.opacity(0.7)).frame(height: 2)
            Text(dateLabel(entry.date))
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(muted)
        }
        .padding(12)
    }

    private var medium: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                heading("今日圩日", subtitle: dateLabel(entry.date))
                Spacer()
                Text("赶集日记")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(WidgetPalette.orange)
            }
            Text(names(0, limit: 4))
                .font(.system(size: 23, weight: .heavy, design: .serif))
                .foregroundStyle(ink)
                .lineLimit(2)
                .minimumScaleFactor(0.65)
            HStack(spacing: 8) {
                forecast(index: 1)
                forecast(index: 2)
            }
        }
        .padding(13)
    }

    private var large: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                heading("赶集日记", subtitle: "今日圩日 · 未来三天")
                Spacer()
                Text(entry.date.formatted(.dateTime.month(.twoDigits).day(.twoDigits).locale(Locale(identifier: "zh_CN"))))
                    .font(.system(size: 12, weight: .bold, design: .serif))
                    .foregroundStyle(WidgetPalette.orange)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("今天")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(WidgetPalette.orange)
                Text(names(0, limit: 5))
                    .font(.system(size: 27, weight: .heavy, design: .serif))
                    .foregroundStyle(ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.62)
                Text(entry.days.first?.markets.isEmpty == false ? "把握今日圩期，出发去赶集" : "今天暂无圩日安排")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(muted)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white.opacity(colorScheme == .dark ? 0.08 : 0.42), in: RoundedRectangle(cornerRadius: 16))
            HStack(spacing: 8) {
                forecast(index: 1)
                forecast(index: 2)
            }
            Spacer(minLength: 0)
            Text("按已收藏的集市为你整理")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(muted)
        }
        .padding(14)
    }

    private func forecast(index: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(index == 1 ? "明天" : "后天")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(WidgetPalette.orange)
            if entry.days.indices.contains(index) {
                Text(entry.days[index].date.formatted(.dateTime.month(.twoDigits).day(.twoDigits).locale(Locale(identifier: "zh_CN"))))
                    .font(.system(size: 16, weight: .heavy, design: .serif))
                    .foregroundStyle(ink)
            }
            Text(names(index, limit: 3))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(ink)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 66, alignment: .leading)
        .background(.white.opacity(colorScheme == .dark ? 0.08 : 0.48), in: RoundedRectangle(cornerRadius: 13))
    }
}

struct GanJiWidget: Widget {
    let kind = "GanJiWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MarketProvider()) { entry in
            GanJiWidgetView(entry: entry)
        }
        .configurationDisplayName("赶集日记")
        .description("简洁查看今天、明天和后天的圩日")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

@main
struct GanJiWidgetBundle: WidgetBundle {
    var body: some Widget { GanJiWidget() }
}
