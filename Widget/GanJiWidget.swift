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

private enum WidgetStyle {
    static let ink = Color(red: 0.10, green: 0.16, blue: 0.15)
    static let muted = Color(red: 0.38, green: 0.46, blue: 0.42)
    static let green = Color(red: 0.12, green: 0.43, blue: 0.31)
    static let mint = Color(red: 0.70, green: 0.88, blue: 0.73)
    static let cream = Color(red: 0.98, green: 0.96, blue: 0.88)
    static let orange = Color(red: 0.91, green: 0.48, blue: 0.22)
    static let blue = Color(red: 0.29, green: 0.49, blue: 0.63)
    static let divider = Color(red: 0.83, green: 0.86, blue: 0.80)
}

private struct WidgetBackdrop: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.96, green: 0.97, blue: 0.88), Color(red: 0.85, green: 0.92, blue: 0.82)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Circle()
                .fill(WidgetStyle.cream.opacity(0.72))
                .frame(width: 190, height: 190)
                .blur(radius: 1)
                .offset(x: 118, y: -112)
            Circle()
                .fill(WidgetStyle.mint.opacity(0.35))
                .frame(width: 150, height: 150)
                .blur(radius: 2)
                .offset(x: -125, y: 125)
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
        .padding(family == .systemSmall ? 14 : 17)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .widgetURL(URL(string: "ganji://home"))
    }

    // 小号：以大日期和今日赶集状态为核心，保证一眼读懂。
    private var small: some View {
        VStack(alignment: .leading, spacing: 0) {
            brandLine
            Spacer(minLength: 5)
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(dayNumber)
                    .font(.system(size: 66, weight: .heavy, design: .rounded))
                    .tracking(-4)
                    .foregroundStyle(WidgetStyle.ink)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                VStack(alignment: .leading, spacing: 2) {
                    Text(month.uppercased())
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .tracking(1)
                    Text(weekday)
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundStyle(WidgetStyle.muted)
            }
            Spacer(minLength: 4)
            HStack(spacing: 8) {
                Image(systemName: entry.today.isEmpty ? "sun.max" : "basket.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(entry.today.isEmpty ? WidgetStyle.orange : WidgetStyle.green, in: RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 2) {
                    Text("今日赶集")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(WidgetStyle.muted)
                    Text(entry.today.first?.name ?? "暂无安排")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(WidgetStyle.ink)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                if entry.today.count > 1 {
                    Text("+\(entry.today.count - 1)")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(WidgetStyle.green)
                }
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 8)
            .background(.white.opacity(0.58), in: RoundedRectangle(cornerRadius: 13))
        }
    }

    // 中号：左侧日期视觉锚点，右侧按时间顺序列出三天安排。
    private var medium: some View {
        HStack(spacing: 15) {
            VStack(alignment: .leading, spacing: 4) {
                brandLine
                Spacer(minLength: 0)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(dayNumber)
                        .font(.system(size: 61, weight: .heavy, design: .rounded))
                        .tracking(-4)
                        .foregroundStyle(WidgetStyle.ink)
                        .minimumScaleFactor(0.65)
                        .lineLimit(1)
                    Text(month.uppercased())
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundStyle(WidgetStyle.muted)
                }
                Text(weekday + " · " + entry.areaName)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(WidgetStyle.muted)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Rectangle()
                .fill(WidgetStyle.divider.opacity(0.8))
                .frame(width: 1)
                .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 9) {
                agendaRow(title: "今天", markets: entry.today, tint: WidgetStyle.green, compact: true)
                agendaRow(title: "明天", markets: entry.tomorrow, tint: WidgetStyle.blue, compact: true)
                agendaRow(title: "后天", markets: entry.dayAfter, tint: WidgetStyle.orange, compact: true)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }

    // 大号：三日行程卡片化，并突出未来三天的赶集总数。
    private var large: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    brandLine
                    Text(entry.areaName)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(WidgetStyle.muted)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "basket.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(WidgetStyle.green)
                    .frame(width: 38, height: 38)
                    .background(.white.opacity(0.58), in: RoundedRectangle(cornerRadius: 13))
            }

            HStack(alignment: .lastTextBaseline, spacing: 8) {
                Text(dayNumber)
                    .font(.system(size: 72, weight: .heavy, design: .rounded))
                    .tracking(-5)
                    .foregroundStyle(WidgetStyle.ink)
                VStack(alignment: .leading, spacing: 3) {
                    Text(month.uppercased())
                        .font(.system(size: 11, weight: .heavy))
                        .tracking(1)
                        .foregroundStyle(WidgetStyle.muted)
                    Text(weekday)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(WidgetStyle.green)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("未来三日")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(WidgetStyle.muted)
                    Text("\(totalCount) 场集市")
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundStyle(WidgetStyle.green)
                }
            }

            Rectangle()
                .fill(WidgetStyle.divider.opacity(0.85))
                .frame(height: 1)

            VStack(spacing: 7) {
                agendaCard(title: "今天", subtitle: "TODAY", markets: entry.today, tint: WidgetStyle.green)
                agendaCard(title: "明天", subtitle: "TOMORROW", markets: entry.tomorrow, tint: WidgetStyle.blue)
                agendaCard(title: "后天", subtitle: "DAY AFTER", markets: entry.dayAfter, tint: WidgetStyle.orange)
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
                .fill(WidgetStyle.green.opacity(0.45))
                .frame(width: 3, height: 3)
            Text("GANJI")
                .font(.system(size: 8, weight: .bold, design: .rounded))
                .tracking(1)
        }
        .foregroundStyle(WidgetStyle.green)
        .lineLimit(1)
    }

    private func agendaRow(title: String, markets: [Market], tint: Color, compact: Bool = false) -> some View {
        HStack(alignment: .center, spacing: 7) {
            RoundedRectangle(cornerRadius: 2)
                .fill(tint)
                .frame(width: 3, height: compact ? 29 : 32)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(tint)
                Text(markets.isEmpty ? "暂无安排" : markets.prefix(2).map(\.name).joined(separator: "、"))
                    .font(.system(size: compact ? 10 : 11, weight: .semibold))
                    .foregroundStyle(WidgetStyle.ink)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            if markets.count > 1 {
                Text("\(markets.count)处")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(WidgetStyle.muted)
            }
        }
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
                    .foregroundStyle(WidgetStyle.muted.opacity(0.8))
            }
            .frame(width: 62, alignment: .leading)

            Rectangle()
                .fill(tint.opacity(0.55))
                .frame(width: 2, height: 27)

            Text(markets.isEmpty ? "暂无安排" : markets.prefix(2).map(\.name).joined(separator: "、"))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(WidgetStyle.ink)
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
        .background(.white.opacity(0.52), in: RoundedRectangle(cornerRadius: 12))
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
