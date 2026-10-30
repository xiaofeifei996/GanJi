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
        let nextRefresh = Calendar.current.nextDate(
            after: Date(),
            matching: DateComponents(hour: 0, minute: 5),
            matchingPolicy: .nextTime
        ) ?? Date().addingTimeInterval(3600)
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
    static let forest = Color(red: 0.10, green: 0.31, blue: 0.23)
    static let leaf = Color(red: 0.24, green: 0.53, blue: 0.37)
    static let lime = Color(red: 0.78, green: 0.87, blue: 0.57)
    static let paper = Color(red: 0.97, green: 0.96, blue: 0.88)
    static let ink = Color(red: 0.12, green: 0.19, blue: 0.16)
    static let secondary = Color(red: 0.39, green: 0.47, blue: 0.41)
    static let orange = Color(red: 0.88, green: 0.43, blue: 0.20)
    static let blue = Color(red: 0.30, green: 0.48, blue: 0.61)
    static let line = Color(red: 0.78, green: 0.82, blue: 0.73)
}

private struct WidgetBackdrop: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.97, green: 0.97, blue: 0.89),
                        Color(red: 0.88, green: 0.93, blue: 0.82),
                        Color(red: 0.81, green: 0.89, blue: 0.76)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Circle()
                    .fill(WidgetPalette.paper.opacity(0.76))
                    .frame(width: proxy.size.width * 0.88)
                    .blur(radius: 1)
                    .offset(x: proxy.size.width * 0.43, y: -proxy.size.height * 0.43)
                Circle()
                    .fill(WidgetPalette.lime.opacity(0.30))
                    .frame(width: proxy.size.width * 0.72)
                    .blur(radius: 2)
                    .offset(x: -proxy.size.width * 0.48, y: proxy.size.height * 0.48)
                LinearGradient(
                    colors: [.white.opacity(0.10), .clear, WidgetPalette.forest.opacity(0.035)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct GanJiWidgetView: View {
    let entry: GanJiWidgetEntry
    @Environment(\.widgetFamily) private var family

    private var dayNumber: String { entry.date.formatted(.dateTime.day()) }
    private var weekday: String { entry.date.formatted(.dateTime.weekday(.wide)) }
    private var month: String { entry.date.formatted(.dateTime.month(.abbreviated)) }
    private var totalCount: Int { entry.today.count + entry.tomorrow.count + entry.dayAfter.count }

    var body: some View {
        Group {
            switch family {
            case .systemSmall: small
            case .systemMedium: medium
            default: large
            }
        }
        .padding(family == .systemSmall ? 13 : 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .widgetURL(URL(string: "ganji://home"))
    }

    // 小号：突出日期与今日是否有集市，减少次要信息。
    private var small: some View {
        VStack(alignment: .leading, spacing: 0) {
            brandLine
            Spacer(minLength: 5)

            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(dayNumber)
                    .font(.system(size: 68, weight: .black, design: .rounded))
                    .tracking(-5)
                    .foregroundStyle(WidgetPalette.forest)
                    .minimumScaleFactor(0.55)
                    .lineLimit(1)
                VStack(alignment: .leading, spacing: 2) {
                    Text(month.uppercased())
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .tracking(1.1)
                    Text(weekday)
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundStyle(WidgetPalette.secondary)
            }

            Spacer(minLength: 4)
            HStack(spacing: 8) {
                Image(systemName: entry.today.isEmpty ? "sun.max.fill" : "basket.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 31, height: 31)
                    .background(entry.today.isEmpty ? WidgetPalette.orange : WidgetPalette.leaf, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.today.isEmpty ? "今日休市" : "今日开集")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(WidgetPalette.secondary)
                    Text(entry.today.first?.name ?? "暂无安排")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(WidgetPalette.ink)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                if entry.today.count > 1 {
                    Text("+\(entry.today.count - 1)")
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .foregroundStyle(WidgetPalette.forest)
                }
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).stroke(.white.opacity(0.55), lineWidth: 1))
        }
    }

    // 中号：左侧日期信息，右侧三日清单。
    private var medium: some View {
        HStack(spacing: 13) {
            VStack(alignment: .leading, spacing: 4) {
                brandLine
                Spacer(minLength: 0)
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(dayNumber)
                        .font(.system(size: 61, weight: .black, design: .rounded))
                        .tracking(-4)
                        .foregroundStyle(WidgetPalette.forest)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    Text(month.uppercased())
                        .font(.system(size: 9, weight: .heavy, design: .rounded))
                        .foregroundStyle(WidgetPalette.secondary)
                }
                Text(weekday + " · " + entry.areaName)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(WidgetPalette.secondary)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Rectangle()
                .fill(WidgetPalette.line.opacity(0.75))
                .frame(width: 1)
                .padding(.vertical, 5)

            VStack(alignment: .leading, spacing: 8) {
                agendaRow(title: "今天", markets: entry.today, tint: WidgetPalette.leaf)
                agendaRow(title: "明天", markets: entry.tomorrow, tint: WidgetPalette.blue)
                agendaRow(title: "后天", markets: entry.dayAfter, tint: WidgetPalette.orange)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }

    // 大号：日期、三日总览与独立行程卡片。
    private var large: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    brandLine
                    Text(entry.areaName)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(WidgetPalette.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "basket.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(WidgetPalette.forest)
                    .frame(width: 38, height: 38)
                    .background(.white.opacity(0.62), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).stroke(.white.opacity(0.6), lineWidth: 1))
            }

            HStack(alignment: .lastTextBaseline, spacing: 8) {
                Text(dayNumber)
                    .font(.system(size: 72, weight: .black, design: .rounded))
                    .tracking(-5)
                    .foregroundStyle(WidgetPalette.forest)
                VStack(alignment: .leading, spacing: 3) {
                    Text(month.uppercased())
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .tracking(1)
                        .foregroundStyle(WidgetPalette.secondary)
                    Text(weekday)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(WidgetPalette.leaf)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("未来三日")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(WidgetPalette.secondary)
                    Text("\(totalCount) 场集市")
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundStyle(WidgetPalette.forest)
                }
            }

            Rectangle()
                .fill(WidgetPalette.line.opacity(0.8))
                .frame(height: 1)

            VStack(spacing: 7) {
                agendaCard(title: "今天", subtitle: "TODAY", markets: entry.today, tint: WidgetPalette.leaf)
                agendaCard(title: "明天", subtitle: "TOMORROW", markets: entry.tomorrow, tint: WidgetPalette.blue)
                agendaCard(title: "后天", subtitle: "DAY AFTER", markets: entry.dayAfter, tint: WidgetPalette.orange)
            }
            Spacer(minLength: 0)
        }
    }

    private var brandLine: some View {
        HStack(spacing: 5) {
            Image(systemName: "sun.max.fill")
                .font(.system(size: 10, weight: .bold))
            Text("赶集日记")
                .font(.system(size: 12, weight: .heavy))
            Circle()
                .fill(WidgetPalette.leaf.opacity(0.55))
                .frame(width: 3, height: 3)
            Text("GANJI")
                .font(.system(size: 8, weight: .bold, design: .rounded))
                .tracking(1)
        }
        .foregroundStyle(WidgetPalette.forest)
        .lineLimit(1)
    }

    private func agendaRow(title: String, markets: [Market], tint: Color) -> some View {
        HStack(alignment: .center, spacing: 7) {
            Capsule()
                .fill(tint)
                .frame(width: 3, height: 30)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(tint)
                Text(markets.isEmpty ? "暂无安排" : markets.prefix(2).map(\.name).joined(separator: "、"))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(WidgetPalette.ink)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            if markets.count > 1 {
                Text("\(markets.count)处")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(WidgetPalette.secondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(.white.opacity(0.48), lineWidth: 1))
    }

    private func agendaCard(title: String, subtitle: String, markets: [Market], tint: Color) -> some View {
        HStack(spacing: 9) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(tint)
                Text(subtitle)
                    .font(.system(size: 7, weight: .bold, design: .rounded))
                    .tracking(0.8)
                    .foregroundStyle(WidgetPalette.secondary.opacity(0.85))
            }
            .frame(width: 62, alignment: .leading)

            Capsule()
                .fill(tint.opacity(0.65))
                .frame(width: 3, height: 27)

            Text(markets.isEmpty ? "暂无安排" : markets.prefix(2).map(\.name).joined(separator: "、"))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(WidgetPalette.ink)
                .lineLimit(1)

            Spacer(minLength: 0)
            if markets.count > 1 {
                Text("\(markets.count)处")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(tint)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).stroke(.white.opacity(0.58), lineWidth: 1))
    }
}

private extension View {
    @ViewBuilder
    func ganjiWidgetBackground() -> some View {
        if #available(iOSApplicationExtension 17.0, *) {
            self.containerBackground(for: .widget) {
                WidgetBackdrop()
                    .ignoresSafeArea()
            }
        } else {
            self.background {
                WidgetBackdrop()
                    .ignoresSafeArea()
            }
        }
    }
}

@main
struct GanJiWidget: Widget {
    let kind = "GanJiWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: GanJiWidgetProvider()) { entry in
            GanJiWidgetView(entry: entry)
                .ganjiWidgetBackground()
        }
        .configurationDisplayName("赶集日记")
        .description("查看今天、明天和后天的赶集安排")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
