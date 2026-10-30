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
    private var month: String { entry.date.formatted(.dateTime.month(.abbreviated)) }

    var body: some View {
        Group {
            switch family {
            case .systemSmall: small
            case .systemMedium: medium
            default: large
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.white)
        .widgetURL(URL(string: "ganji://home"))
    }

    // 小号：日期做主角，底部用一条状态色块显示今日集市
    private var small: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("GANJI · 赶集日记")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(WidgetPalette.green)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(WidgetPalette.secondary)
            }
            Spacer(minLength: 8)
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(dayNumber)
                    .font(.system(size:  60, weight: .bold, design: .rounded))
                    .tracking(-3)
                    .foregroundStyle(WidgetPalette.ink)
                    .minimumScaleFactor(0.65)
                    .lineLimit(1)
                VStack(alignment: .leading, spacing: 2) {
                    Text(month.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(WidgetPalette.secondary)
                    Text(weekday)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(WidgetPalette.ink)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            HStack(spacing: 7) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(entry.today.isEmpty ? WidgetPalette.orange : WidgetPalette.green)
                    .frame(width: 4, height: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text("今日赶集")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(WidgetPalette.secondary)
                    Text(entry.today.first?.name ?? "暂无安排")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(WidgetPalette.ink)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
            .background(WidgetPalette.paleGreen, in: RoundedRectangle(cornerRadius: 10))
        }
    }

    // 中号：左侧日期，右侧以清晰列表展示三天安排
    private var medium: some View {
        HStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 5) {
                Text("赶集日记")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(WidgetPalette.green)
                Text(entry.areaName)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(WidgetPalette.secondary)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Text(dayNumber)
                    .font(.system(size: 58, weight: .bold, design: .rounded))
                    .tracking(-3)
                    .foregroundStyle(WidgetPalette.ink)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                Text("\(month)  /  \(weekday)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(WidgetPalette.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Rectangle().fill(WidgetPalette.line).frame(width: 1)

            VStack(alignment: .leading, spacing: 0) {
                agendaRow(title: "今天", markets: entry.today, tint: WidgetPalette.green)
                Rectangle().fill(WidgetPalette.line).frame(height: 1).padding(.vertical, 7)
                agendaRow(title: "明天", markets: entry.tomorrow, tint: WidgetPalette.blue)
                Rectangle().fill(WidgetPalette.line).frame(height: 1).padding(.vertical, 7)
                agendaRow(title: "后天", markets: entry.dayAfter, tint: WidgetPalette.orange)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }

    // 大号：顶部日期横幅，下方三天日程卡片，减少空白
    private var large: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("赶集日记")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(WidgetPalette.green)
                    Text(entry.areaName)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(WidgetPalette.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Text(weekday)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(WidgetPalette.green)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(WidgetPalette.paleGreen, in: Capsule())
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(dayNumber)
                    .font(.system(size: 68, weight: .bold, design: .rounded))
                    .tracking(-4)
                    .foregroundStyle(WidgetPalette.ink)
                Text(month.uppercased())
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(WidgetPalette.secondary)
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text("未来三日")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(WidgetPalette.secondary)
                    Text("\(entry.today.count + entry.tomorrow.count + entry.dayAfter.count) 场集市")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(WidgetPalette.ink)
                }
            }

            Rectangle().fill(WidgetPalette.line).frame(height: 1)

            VStack(alignment: .leading, spacing: 10) {
                agendaRow(title: "今天", markets: entry.today, tint: WidgetPalette.green)
                agendaRow(title: "明天", markets: entry.tomorrow, tint: WidgetPalette.blue)
                agendaRow(title: "后天", markets: entry.dayAfter, tint: WidgetPalette.orange)
            }
            Spacer(minLength: 0)
        }
    }

    private func agendaRow(title: String, markets: [Market], tint: Color) -> some View {
        HStack(alignment: .top, spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(tint)
                .frame(width: 4, height: 27)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(WidgetPalette.secondary)
                if markets.isEmpty {
                    Text("暂无安排")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(WidgetPalette.ink)
                        .lineLimit(1)
                } else {
                    Text(markets.prefix(2).map(\.name).joined(separator: "、"))
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(WidgetPalette.ink)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            if markets.count > 1 {
                Text("\(markets.count)处")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(WidgetPalette.secondary)
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
                    .ignoresSafeArea()
            }
            .background(Color.white.ignoresSafeArea())
        } else {
            background(Color.white.ignoresSafeArea())
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
