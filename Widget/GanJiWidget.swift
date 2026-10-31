import SwiftUI
import WidgetKit
import UIKit

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
        // Widget gallery previews must be returned immediately. Waiting for a network
        // image download can make iOS show its generic gray placeholder for small/medium.
        completion(makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<GanJiWidgetEntry>) -> Void) {
        refreshWidgetPhoto {
            let entry = makeEntry()
            let nextRefresh = Calendar.current.nextDate(
                after: Date(),
                matching: DateComponents(hour: 0, minute: 5),
                matchingPolicy: .nextTime
            ) ?? Date().addingTimeInterval(3600)
            completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
        }
    }

    /// Download a real market-produce photograph into the shared App Group container.
    /// The widget uses the last cached image when the network is unavailable.
    private func refreshWidgetPhoto(completion: @escaping () -> Void) {
        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: ganJiGroupID
        ) else {
            completion()
            return
        }
        let destination = container.appendingPathComponent("GanJiWidgetMarket.jpg")
        let url = URL(string: "https://images.unsplash.com/photo-1586480185285-9e602c969a95?auto=format&fit=crop&w=1400&q=88")!
        URLSession.shared.dataTask(with: url) { data, response, error in
            defer { completion() }
            guard error == nil,
                  let http = response as? HTTPURLResponse,
                  (200...299).contains(http.statusCode),
                  let data, UIImage(data: data) != nil else { return }
            try? data.write(to: destination, options: .atomic)
        }.resume()
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
    static let forest = Color(red: 0.98, green: 0.91, blue: 0.76)
    static let leaf = Color(red: 0.83, green: 0.78, blue: 0.52)
    static let lime = Color(red: 0.91, green: 0.78, blue: 0.55)
    static let paper = Color.white
    static let ink = Color(red: 0.99, green: 0.95, blue: 0.86)
    static let secondary = Color(red: 0.98, green: 0.91, blue: 0.79).opacity(0.92)
    static let orange = Color(red: 0.88, green: 0.43, blue: 0.20)
    static let blue = Color(red: 0.70, green: 0.78, blue: 0.72)
    static let line = Color(red: 0.98, green: 0.91, blue: 0.79).opacity(0.62)
}

private struct WidgetBackdrop: View {
    @Environment(\.widgetFamily) private var family

    private var marketPhoto: UIImage? {
        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: ganJiGroupID
        ) else { return nil }

        let customFileName: String
        switch family {
        case .systemSmall: customFileName = "GanJiWidgetPhoto-small.jpg"
        case .systemMedium: customFileName = "GanJiWidgetPhoto-medium.jpg"
        default: customFileName = "GanJiWidgetPhoto-large.jpg"
        }

        // A size-specific photo takes priority; otherwise keep the shared market photo.
        let customURL = container.appendingPathComponent(customFileName)
        if let customImage = UIImage(contentsOfFile: customURL.path) {
            return customImage
        }
        return UIImage(contentsOfFile: container.appendingPathComponent("GanJiWidgetMarket.jpg").path)
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if let marketPhoto {
                    if #available(iOSApplicationExtension 18.0, *) {
                        Image(uiImage: marketPhoto)
                            .resizable()
                            // Apply the image-specific rendering mode before the chain
                            // becomes a generic SwiftUI View.
                            .widgetAccentedRenderingMode(.fullColor)
                            .scaledToFill()
                            .frame(width: proxy.size.width, height: proxy.size.height)
                            .clipped()
                    } else {
                        Image(uiImage: marketPhoto)
                            .resizable()
                            .scaledToFill()
                            .frame(width: proxy.size.width, height: proxy.size.height)
                            .clipped()
                    }
                } else {
                    LinearGradient(
                        colors: [WidgetPalette.paper, Color(red: 0.82, green: 0.89, blue: 0.77)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
                // A restrained dark wash keeps white text legible while preserving the real vendor photograph.
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.42),
                        Color.black.opacity(0.18),
                        Color.black.opacity(0.52)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
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
    private var weekday: String { entry.date.formatted(.dateTime.weekday(.wide).locale(Locale(identifier: "zh_CN"))) }
    private var month: String { "\(Calendar.current.component(.month, from: entry.date))月" }
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
                    Text(month)
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
                    Text(month)
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
                    Text(month)
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
                    Text("\(totalCount) 场赶集")
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundStyle(WidgetPalette.forest)
                }
            }

            Rectangle()
                .fill(WidgetPalette.line.opacity(0.8))
                .frame(height: 1)

            VStack(spacing: 7) {
                agendaCard(title: "今天", subtitle: "今日赶集", markets: entry.today, tint: WidgetPalette.leaf)
                agendaCard(title: "明天", subtitle: "提前安排", markets: entry.tomorrow, tint: WidgetPalette.blue)
                agendaCard(title: "后天", subtitle: "出行计划", markets: entry.dayAfter, tint: WidgetPalette.orange)
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
            Text("赶集生活")
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
        let configuration = StaticConfiguration(kind: kind, provider: GanJiWidgetProvider()) { entry in
            GanJiWidgetView(entry: entry)
                // WidgetKit redacts gallery placeholders by default, which turns the
                // small/medium previews into gray skeletons. Keep our designed preview visible.
                .unredacted()
                .ganjiWidgetBackground()
        }
        .configurationDisplayName("赶集日记")
        .description("查看今天、明天、后天的赶集安排")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])

        // This widget's photograph is essential content, not a decorative background.
        // Keep it visible in iOS 17+ contexts that otherwise remove widget backgrounds.
        if #available(iOSApplicationExtension 17.0, *) {
            configuration.containerBackgroundRemovable(false)
        } else {
            configuration
        }
    }
}
