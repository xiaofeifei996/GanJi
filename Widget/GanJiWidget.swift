import SwiftUI
import WidgetKit

private let ganJiGroupID = "group.com.ganji.diary"

private struct GanJiWidgetEntry: TimelineEntry {
    let date: Date
    let areaName: String
    let today: [Market]
    let tomorrow: [Market]
    let dayAfter: [Market]
}

private struct GanJiWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> GanJiWidgetEntry {
        GanJiWidgetEntry(date: Date(), areaName: "赶集日记", today: [], tomorrow: [], dayAfter: [])
    }

    func getSnapshot(in context: Context, completion: @escaping (GanJiWidgetEntry) -> Void) {
        completion(makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<GanJiWidgetEntry>) -> Void) {
        let entry = makeEntry()
        let nextRefresh = Calendar.current.nextDate(after: Date(), matching: DateComponents(hour: 0, minute: 5), matchingPolicy: .nextTime) ?? Date().addingTimeInterval(3600)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }

    private func makeEntry() -> GanJiWidgetEntry {
        let shared = UserDefaults(suiteName: ganJiGroupID)
        let areaName = shared?.string(forKey: "GanJiSelectedAreaName") ?? ""
        let favoriteIDs = Set(shared?.stringArray(forKey: "GanJiFavoriteMarketIDs") ?? [])
        let data = shared?.data(forKey: "GanJiFavoriteMarketsData") ?? Data()
        let saved = (try? JSONDecoder().decode([Market].self, from: data)) ?? []
        let markets = saved.filter { favoriteIDs.isEmpty || favoriteIDs.contains($0.id) }
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today) ?? today
        let dayAfter = Calendar.current.date(byAdding: .day, value: 2, to: today) ?? today
        return GanJiWidgetEntry(
            date: Date(),
            areaName: areaName.isEmpty ? "赶集日记" : areaName,
            today: markets.filter { MarketStore.opens(on: today, market: $0) },
            tomorrow: markets.filter { MarketStore.opens(on: tomorrow, market: $0) },
            dayAfter: markets.filter { MarketStore.opens(on: dayAfter, market: $0) }
        )
    }
}

private enum WidgetPalette {
    static let ink = Color(red: 0.10, green: 0.13, blue: 0.19)
    static let secondary = Color(red: 0.53, green: 0.57, blue: 0.64)
    static let green = Color(red: 0.17, green: 0.70, blue: 0.47)
    static let blue = Color(red: 0.25, green: 0.60, blue: 0.92)
    static let orange = Color(red: 0.97, green: 0.67, blue: 0.27)
    static let line = Color(red: 0.91, green: 0.92, blue: 0.94)
    static let paleGreen = Color(red: 0.94, green: 0.98, blue: 0.95)
}

private struct GanJiWidgetView: View {
    let entry: GanJiWidgetEntry
    @Environment(\.widgetFamily) private var family

    private var dayNumber: String { entry.date.formatted(.dateTime.day()) }
    private var weekday: String { entry.date.formatted(.dateTime.weekday(.wide)) }
    private var month: String { entry.date.formatted(.dateTime.month()) + "月" }

    var body: some View {
        Group {
            switch family {
            case .systemSmall: small
            case .systemMedium: medium
            default: large
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.white)
        .widgetURL(URL(string: "ganji://home"))
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("赶集日记")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(WidgetPalette.ink)
            Spacer(minLength: 8)
            HStack(alignment: .center, spacing: 8) {
                Text(dayNumber)
                    .font(.system(size: 50, weight: .regular, design: .rounded))
                    .tracking(-2)
                    .foregroundStyle(WidgetPalette.ink)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                VStack(alignment: .leading, spacing: 3) {
                    Text(weekday)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(WidgetPalette.ink)
                    Text(month)
                        .font(.system(size: 12))
                        .foregroundStyle(WidgetPalette.secondary)
                }
            }
            Spacer(minLength: 8)
            Rectangle().fill(WidgetPalette.line).frame(height: 1)
            HStack(spacing: 7) {
                Circle().fill(entry.today.isEmpty ? WidgetPalette.secondary : WidgetPalette.green).frame(width: 7, height: 7)
                Text(entry.today.first?.name ?? (entry.today.isEmpty ? "今日暂无赶集" : "今日赶集"))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(WidgetPalette.ink)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(WidgetPalette.secondary)
            }
            .padding(.top, 10)
        }
    }

    private var medium: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("赶集日记")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(WidgetPalette.ink)
                Text(entry.areaName)
                    .font(.system(size: 10))
                    .foregroundStyle(WidgetPalette.secondary)
                    .lineLimit(1)
                Spacer(minLength: 4)
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(dayNumber)
                        .font(.system(size: 49, weight: .regular, design: .rounded))
                        .tracking(-2)
                        .foregroundStyle(WidgetPalette.ink)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(weekday).font(.system(size: 11, weight: .medium)).foregroundStyle(WidgetPalette.ink)
                        Text(month).font(.system(size: 11)).foregroundStyle(WidgetPalette.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Rectangle().fill(WidgetPalette.line).frame(width: 1)
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 6) {
                    Circle().fill(WidgetPalette.green).frame(width: 7, height: 7)
                    Text("今日赶集").font(.system(size: 12, weight: .semibold)).foregroundStyle(WidgetPalette.ink)
                    Spacer(minLength: 0)
                    Text(entry.today.count.description).font(.system(size: 10)).foregroundStyle(WidgetPalette.secondary)
                }
                if let market = entry.today.first {
                    marketRow(market, tint: WidgetPalette.paleGreen)
                } else {
                    Text("今天没有收藏的集市")
                        .font(.system(size: 11))
                        .foregroundStyle(WidgetPalette.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(WidgetPalette.paleGreen, in: RoundedRectangle(cornerRadius: 12))
                }
                HStack(spacing: 8) {
                    compactDay(title: "明日", name: entry.tomorrow.first?.name ?? "暂无安排", tint: WidgetPalette.blue)
                    compactDay(title: "后日", name: entry.dayAfter.first?.name ?? "暂无安排", tint: WidgetPalette.orange)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var large: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 7) {
                Text("赶集日记")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(WidgetPalette.ink)
                Text(entry.areaName)
                    .font(.system(size: 11))
                    .foregroundStyle(WidgetPalette.secondary)
                    .lineLimit(2)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(dayNumber)
                        .font(.system(size: 58, weight: .regular, design: .rounded))
                        .tracking(-3)
                        .foregroundStyle(WidgetPalette.ink)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(weekday).font(.system(size: 12, weight: .medium)).foregroundStyle(WidgetPalette.ink)
                        Text(month).font(.system(size: 12)).foregroundStyle(WidgetPalette.secondary)
                    }
                }
                Spacer(minLength: 0)
                HStack(spacing: 6) {
                    Circle().fill(WidgetPalette.green).frame(width: 8, height: 8)
                    Text("今日赶集").font(.system(size: 12, weight: .medium)).foregroundStyle(WidgetPalette.ink)
                }
                Text(entry.today.first?.name ?? "暂无赶集安排")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(WidgetPalette.ink)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Rectangle().fill(WidgetPalette.line).frame(width: 1)
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "calendar").font(.system(size: 12, weight: .semibold))
                    Text("未来赶集").font(.system(size: 13, weight: .semibold))
                    Spacer(minLength: 0)
                }
                .foregroundStyle(WidgetPalette.ink)
                daySection(title: "明日", markets: entry.tomorrow, tint: WidgetPalette.blue)
                Rectangle().fill(WidgetPalette.line).frame(height: 1)
                daySection(title: "后日", markets: entry.dayAfter, tint: WidgetPalette.orange)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func marketRow(_ market: Market, tint: Color) -> some View {
        HStack(spacing: 9) {
            Image(systemName: "storefront.fill")
                .font(.system(size: 19))
                .foregroundStyle(WidgetPalette.green)
            VStack(alignment: .leading, spacing: 3) {
                Text(market.name).font(.system(size: 12, weight: .semibold)).foregroundStyle(WidgetPalette.ink).lineLimit(1)
                Text(market.remark.isEmpty ? market.size : market.remark)
                    .font(.system(size: 9))
                    .foregroundStyle(WidgetPalette.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(9)
        .background(tint, in: RoundedRectangle(cornerRadius: 11))
    }

    private func compactDay(title: String, name: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Circle().fill(tint).frame(width: 6, height: 6)
                Text(title).font(.system(size: 10, weight: .medium)).foregroundStyle(WidgetPalette.secondary)
            }
            Text(name).font(.system(size: 11, weight: .semibold)).foregroundStyle(WidgetPalette.ink).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(Color(red: 0.98, green: 0.98, blue: 0.99), in: RoundedRectangle(cornerRadius: 10))
    }

    private func daySection(title: String, markets: [Market], tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Circle().fill(tint).frame(width: 7, height: 7)
                Text(title).font(.system(size: 11, weight: .medium)).foregroundStyle(WidgetPalette.secondary)
            }
            if markets.isEmpty {
                Text("暂无安排").font(.system(size: 11)).foregroundStyle(WidgetPalette.secondary)
            } else {
                ForEach(markets.prefix(2)) { market in
                    Text(market.name)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(WidgetPalette.ink)
                        .lineLimit(1)
                }
            }
        }
    }
}

private extension GanJiWidgetView {
    static let dateFontSize: CGFloat = 50
}

private extension View {
    @ViewBuilder
    func ganJiWidgetBackground() -> some View {
        if #available(iOSApplicationExtension 17.0, *) {
            containerBackground(for: .widget) {
                Color.white
            }
        } else {
            background(Color.white)
        }
    }
}

@main
struct GanJiWidget: Widget {
    let kind = "GanJiWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: GanJiWidgetProvider()) { entry in
            GanJiWidgetView(entry: entry)
                .ganJiWidgetBackground()
        }
        .configurationDisplayName("赶集日记")
        .description("查看今天、明天和后天的赶集安排")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
