import WidgetKit
import SwiftUI

// MARK: - Timeline model

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
    private let appGroup = "group.com.ganji.diary"

    // One data path is used by placeholder, snapshot and timeline. This avoids
    // the old state where the installed widget could remain on a separate demo view.
    private func makeEntry(at date: Date) -> GanJiEntry {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        let days = (0..<3).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }

        let shared = UserDefaults(suiteName: appGroup)
        let favoriteIDs = Set(shared?.stringArray(forKey: "GanJiFavoriteMarketIDs") ?? [])
        let favoriteData = shared?.data(forKey: "GanJiFavoriteMarketsData") ?? Data()
        let homeData = shared?.data(forKey: "GanJiHomeMarketsData") ?? Data()

        let favorites = (try? JSONDecoder().decode([Market].self, from: favoriteData)) ?? []
        let home = (try? JSONDecoder().decode([Market].self, from: homeData)) ?? []
        let bundled = MarketStore.load()

        let source: [Market]
        if !favorites.isEmpty {
            source = favorites
        } else if !home.isEmpty {
            source = home
        } else {
            source = bundled
        }

        // When favorites exist, show only those. If the user has not favorited
        // anything yet, show the available homepage markets instead of blank cards.
        let visible = favoriteIDs.isEmpty
            ? source
            : source.filter { favoriteIDs.contains($0.id) }

        let sections = days.map { target in
            visible
                .filter { MarketStore.opens(on: target, market: $0) }
                .sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
                .map { DayItem(id: $0.id, name: $0.name) }
        }
        return GanJiEntry(date: date, days: days, sections: sections)
    }

    func placeholder(in context: Context) -> GanJiEntry {
        makeEntry(at: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (GanJiEntry) -> Void) {
        completion(makeEntry(at: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<GanJiEntry>) -> Void) {
        let now = Date()
        let entry = makeEntry(at: now)
        let refresh = Calendar.current.date(byAdding: .hour, value: 1, to: now)
            ?? now.addingTimeInterval(3600)
        completion(Timeline(entries: [entry], policy: .after(refresh)))
    }
}

// MARK: - Artwork

private struct WidgetArtwork: View {
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            if family == .systemSmall {
                Image("HanLi-square", bundle: .main)
                    .resizable()
                    .scaledToFill()
            } else {
                Image("HanLi-wide", bundle: .main)
                    .resizable()
                    .scaledToFill()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .overlay {
            LinearGradient(
                colors: [.white.opacity(0.18), .white.opacity(0.06)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Widget view

struct GanJiWidgetView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var colorScheme
    let entry: GanJiEntry

    private let ink = Color(red: 0.12, green: 0.22, blue: 0.18)
    private let orange = Color(red: 0.94, green: 0.39, blue: 0.08)
    private var dark: Bool { colorScheme == .dark }
    private var textColor: Color { dark ? .white : ink }
    private var secondary: Color { dark ? .white.opacity(0.78) : ink.opacity(0.72) }

    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                smallView
            case .systemMedium:
                mediumView
            default:
                largeView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .unredacted()
        .containerBackground(for: .widget) {
            WidgetArtwork()
        }
    }

    private func marketNames(_ index: Int, short: Bool = false) -> String {
        guard entry.sections.indices.contains(index) else { return "暂无数据" }
        let items = entry.sections[index]
        guard !items.isEmpty else { return index == 0 ? "今日暂无圩日" : "暂无圩日" }
        return items.map { short ? $0.short : $0.name }.joined(separator: " · ")
    }

    private func dateText(_ date: Date) -> String {
        let parts = Calendar.current.dateComponents([.month, .day], from: date)
        return "\(parts.month ?? 1)/\(parts.day ?? 1)"
    }

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: "basket.fill")
                    .foregroundColor(orange)
                Text("今日圩日")
                    .font(.system(size: 13, weight: .heavy, design: .serif))
                    .foregroundColor(textColor)
                Spacer(minLength: 0)
                Text("今天")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(ink)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(Color(red: 0.86, green: 0.90, blue: 0.72), in: Capsule())
            }
            Text(marketNames(0, short: true))
                .font(.system(size: 21, weight: .heavy, design: .serif))
                .foregroundColor(textColor)
                .lineLimit(3)
                .minimumScaleFactor(0.58)
            Spacer(minLength: 0)
            Text("\(LunarCalendar.shortDate(entry.date))  \(LunarCalendar.weekdayText(entry.date))")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(secondary)
            Text("农历 \(LunarCalendar.lunarText(entry.date))")
                .font(.system(size: 8, weight: .medium))
                .foregroundColor(secondary)
        }
        .padding(11)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.white.opacity(dark ? 0.08 : 0.24), in: RoundedRectangle(cornerRadius: 14))
    }

    private var mediumView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("今日圩日")
                        .font(.system(size: 15, weight: .heavy, design: .serif))
                        .foregroundColor(textColor)
                    Text("\(LunarCalendar.shortDate(entry.date)) · \(LunarCalendar.weekdayText(entry.date))")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(secondary)
                }
                Spacer()
                Text("赶集日记")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(orange)
            }
            Text(marketNames(0))
                .font(.system(size: 23, weight: .heavy, design: .serif))
                .foregroundColor(textColor)
                .lineLimit(2)
                .minimumScaleFactor(0.6)
            HStack(spacing: 7) {
                forecastCard(1)
                forecastCard(2)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func forecastCard(_ index: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(index == 1 ? "明日" : "后日")
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(secondary)
            Text(marketNames(index))
                .font(.system(size: 12, weight: .bold, design: .serif))
                .foregroundColor(textColor)
                .lineLimit(2)
                .minimumScaleFactor(0.65)
            Text("\(dateText(entry.days[index]))  \(LunarCalendar.weekdayText(entry.days[index]))")
                .font(.system(size: 8, weight: .medium))
                .foregroundColor(secondary)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(dark ? 0.08 : 0.58), in: RoundedRectangle(cornerRadius: 11))
    }

    private var largeView: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("今日圩日")
                        .font(.system(size: 17, weight: .heavy, design: .serif))
                        .foregroundColor(textColor)
                    Text("\(LunarCalendar.shortDate(entry.date))  \(LunarCalendar.weekdayText(entry.date))")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(secondary)
                    Text("农历 \(LunarCalendar.lunarText(entry.date)) · \(LunarCalendar.ganzhiName(entry.date))日")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(secondary)
                }
                Spacer()
                Text("今日")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(ink)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Color(red: 0.86, green: 0.90, blue: 0.72), in: Capsule())
            }
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(marketNames(0))
                        .font(.system(size: 28, weight: .heavy, design: .serif))
                        .foregroundColor(textColor)
                        .lineLimit(2)
                        .minimumScaleFactor(0.6)
                    Text(entry.sections.first?.isEmpty == false ? "今天赶集 · 记得出发" : "今天暂无圩日")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(orange)
                }
                Spacer(minLength: 0)
                Image("HanLi-square", bundle: .main)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 82, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(10)
            .background(.white.opacity(dark ? 0.08 : 0.38), in: RoundedRectangle(cornerRadius: 14))
            HStack(spacing: 7) {
                dayCard(0)
                dayCard(1)
                dayCard(2)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
    }

    private func dayCard(_ index: Int) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(["今天", "明天", "后天"][index])
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(index == 0 ? .white : textColor)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(index == 0 ? orange : Color.white.opacity(dark ? 0.12 : 0.55), in: Capsule())
            Text(dateText(entry.days[index]))
                .font(.system(size: 16, weight: .heavy, design: .serif))
                .foregroundColor(textColor)
            Text(LunarCalendar.weekdayText(entry.days[index]))
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(secondary)
            Spacer(minLength: 2)
            Text(marketNames(index, short: true))
                .font(.system(size: 12, weight: .heavy, design: .serif))
                .foregroundColor(index == 0 ? orange : textColor)
                .lineLimit(2)
                .minimumScaleFactor(0.55)
        }
        .padding(8)
        .frame(maxWidth: .infinity, minHeight: 100, alignment: .leading)
        .background(.white.opacity(dark ? 0.10 : 0.58), in: RoundedRectangle(cornerRadius: 13))
    }
}

// MARK: - Widget registration

struct GanJiWidget: Widget {
    let kind = "GanJiWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MarketProvider()) { entry in
            GanJiWidgetView(entry: entry)
        }
        .configurationDisplayName("赶集日记")
        .description("查看今日、明日与后日圩日")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

@main
struct GanJiWidgetBundle: WidgetBundle {
    var body: some Widget {
        GanJiWidget()
    }
}
