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

// MARK: - Ink-wash mountain visual system

private enum WidgetPalette {
    static let cream = Color(red: 0.97, green: 0.92, blue: 0.80)
    static let ink = Color(red: 0.10, green: 0.18, blue: 0.17)
    static let muted = Color(red: 0.83, green: 0.84, blue: 0.75)
    static let gold = Color(red: 0.91, green: 0.67, blue: 0.34)
    static let vermilion = Color(red: 0.72, green: 0.25, blue: 0.16)
}

private struct Ridge: Shape {
    var height: CGFloat
    var shift: CGFloat
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: rect.height * height))
        p.addCurve(to: CGPoint(x: rect.width * 0.48, y: rect.height * (height - 0.38)),
                   control1: CGPoint(x: rect.width * 0.18, y: rect.height * (height - 0.48)),
                   control2: CGPoint(x: rect.width * 0.30, y: rect.height * (height - 0.08)))
        p.addCurve(to: CGPoint(x: rect.width, y: rect.height * (height - 0.12 + shift)),
                   control1: CGPoint(x: rect.width * 0.69, y: rect.height * (height - 0.62)),
                   control2: CGPoint(x: rect.width * 0.82, y: rect.height * (height + 0.12)))
        p.addLine(to: CGPoint(x: rect.width, y: rect.height))
        p.addLine(to: CGPoint(x: 0, y: rect.height))
        p.closeSubpath()
        return p
    }
}

private struct WidgetBackdrop: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                LinearGradient(colors: [
                    Color(red: 0.78, green: 0.77, blue: 0.65),
                    Color(red: 0.39, green: 0.53, blue: 0.48),
                    Color(red: 0.12, green: 0.27, blue: 0.26)
                ], startPoint: .top, endPoint: .bottom)
                Circle()
                    .fill(WidgetPalette.gold.opacity(0.72))
                    .frame(width: min(proxy.size.width, proxy.size.height) * 0.34)
                    .blur(radius: 1)
                    .offset(x: proxy.size.width * 0.27, y: -proxy.size.height * 0.25)
                Ridge(height: 0.68, shift: 0.02)
                    .fill(Color(red: 0.58, green: 0.66, blue: 0.58).opacity(0.72))
                Ridge(height: 0.82, shift: -0.02)
                    .fill(Color(red: 0.29, green: 0.43, blue: 0.39).opacity(0.88))
                Ridge(height: 0.94, shift: 0.01)
                    .fill(Color(red: 0.10, green: 0.24, blue: 0.23))
                VStack {
                    Spacer()
                    HStack(spacing: 18) {
                        Capsule().fill(.white.opacity(0.13)).frame(width: proxy.size.width * 0.28, height: 1)
                        Capsule().fill(.white.opacity(0.20)).frame(width: proxy.size.width * 0.18, height: 1)
                    }
                    .blur(radius: 5)
                    .padding(.bottom, proxy.size.height * 0.20)
                }
                // A small, original ink-style traveler silhouette on the ridge.
                VStack(spacing: 0) {
                    Circle().fill(Color(red: 0.08, green: 0.13, blue: 0.12))
                        .frame(width: 5, height: 5)
                    Path { p in
                        p.move(to: CGPoint(x: 5, y: 0))
                        p.addQuadCurve(to: CGPoint(x: 0, y: 17), control: CGPoint(x: -1, y: 9))
                        p.addLine(to: CGPoint(x: 13, y: 17))
                        p.addQuadCurve(to: CGPoint(x: 8, y: 0), control: CGPoint(x: 14, y: 8))
                        p.closeSubpath()
                    }
                    .fill(Color(red: 0.08, green: 0.13, blue: 0.12))
                    .frame(width: 13, height: 17)
                }
                .offset(x: -proxy.size.width * 0.22, y: proxy.size.height * 0.31)
                LinearGradient(colors: [.black.opacity(0.18), .clear, .black.opacity(0.26)],
                               startPoint: .top, endPoint: .bottom)
            }
            .clipped()
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

    private var ink: Color { WidgetPalette.cream }
    private var muted: Color { WidgetPalette.muted }

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
                    .foregroundStyle(WidgetPalette.gold)
                Spacer()
                Text("今日")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(WidgetPalette.ink)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(WidgetPalette.gold.opacity(0.28), in: Capsule())
            }
            Text(names(0, limit: 2))
                .font(.system(size: 22, weight: .heavy, design: .serif))
                .foregroundStyle(ink)
                .lineLimit(3)
                .minimumScaleFactor(0.62)
            Spacer(minLength: 0)
            Rectangle().fill(WidgetPalette.gold.opacity(0.7)).frame(height: 2)
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
                    .foregroundStyle(WidgetPalette.gold)
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
                    .foregroundStyle(WidgetPalette.gold)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("今天")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(WidgetPalette.gold)
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
            .background(.black.opacity(0.20), in: RoundedRectangle(cornerRadius: 16))
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
                .foregroundStyle(WidgetPalette.gold)
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
        .background(.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 13))
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
