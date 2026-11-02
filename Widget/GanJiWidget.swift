import SwiftUI
import WidgetKit
import UIKit

// 全新实现：不使用旧的命名与结构。
private let sharedGroupID = "group.com.ganji.diary"
private let widgetKindID = "GanJiWidget"

// MARK: - 时间线条目

private struct MarketEntry: TimelineEntry {
    let date: Date
    let region: String
    let todayMarkets: [Market]
    let tomorrowMarkets: [Market]
    let dayAfterMarkets: [Market]
    let backdrop: UIImage?
}

// MARK: - 数据提供者

private struct MarketTimeline: TimelineProvider {
    func placeholder(in context: Context) -> MarketEntry {
        MarketEntry(date: Date(), region: "赶集日记", todayMarkets: [], tomorrowMarkets: [], dayAfterMarkets: [], backdrop: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (MarketEntry) -> Void) {
        completion(build(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MarketEntry>) -> Void) {
        let entry = build(in: context)
        let refresh = Calendar.current.nextDate(
            after: Date(),
            matching: DateComponents(hour: 0, minute: 5),
            matchingPolicy: .nextTime
        ) ?? Date().addingTimeInterval(3600)
        completion(Timeline(entries: [entry], policy: .after(refresh)))
    }

    private func build(in context: Context) -> MarketEntry {
        let store = UserDefaults(suiteName: sharedGroupID)
        let region = store?.string(forKey: "GanJiSelectedAreaName") ?? "赶集日记"
        let favorites = Set(store?.stringArray(forKey: "GanJiFavoriteMarketIDs") ?? [])
        let savedData = store?.data(forKey: "GanJiFavoriteMarketsData") ?? Data()
        let saved = (try? JSONDecoder().decode([Market].self, from: savedData)) ?? []
        let markets = saved.filter { favorites.isEmpty || favorites.contains($0.id) }

        let day = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: day) ?? day
        let dayAfter = Calendar.current.date(byAdding: .day, value: 2, to: day) ?? day

        return MarketEntry(
            date: Date(),
            region: region.isEmpty ? "赶集日记" : region,
            todayMarkets: markets.filter { MarketStore.opens(on: day, market: $0) },
            tomorrowMarkets: markets.filter { MarketStore.opens(on: tomorrow, market: $0) },
            dayAfterMarkets: markets.filter { MarketStore.opens(on: dayAfter, market: $0) },
            backdrop: BackdropLoader.photo(for: context.family)
        )
    }
}

// MARK: - 照片读取（真实照片，从 App Group）

private enum BackdropLoader {
    static func photo(for family: WidgetFamily) -> UIImage? {
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: sharedGroupID) else {
            return nil
        }
        let specific: String
        switch family {
        case .systemSmall: specific = "GanJiWidgetPhoto-small.jpg"
        case .systemMedium: specific = "GanJiWidgetPhoto-medium.jpg"
        default: specific = "GanJiWidgetPhoto-large.jpg"
        }
        if let image = read(container, specific) { return image }
        return read(container, "GanJiWidgetMarket.jpg")
    }

    private static func read(_ container: URL, _ name: String) -> UIImage? {
        let url = container.appendingPathComponent(name)
        guard let data = try? Data(contentsOf: url), !data.isEmpty,
              let image = UIImage(data: data), image.size.width > 0 else { return nil }
        // 大图在小组件里解码会占太多内存，缩到长边 800pt。
        let longest = max(image.size.width, image.size.height)
        guard longest > 800 else { return image }
        let ratio = 800 / longest
        let size = CGSize(width: (image.size.width * ratio).rounded(), height: (image.size.height * ratio).rounded())
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
    }
}

// MARK: - 配色

private enum Ink {
    static let night = Color(red: 0.20, green: 0.25, blue: 0.34)
    static let gold = Color(red: 0.92, green: 0.70, blue: 0.30)
    static let cream = Color(red: 0.97, green: 0.94, blue: 0.87)
    static let white = Color.white
}

// MARK: - 背景

private struct PhotoBackdrop: View {
    let image: UIImage?

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                LinearGradient(colors: [Ink.cream, Color(red: 0.90, green: 0.93, blue: 0.82)],
                               startPoint: .top, endPoint: .bottom)
            }
            Color.black.opacity(0.28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }
}

// MARK: - 内容

private struct MarketWidgetView: View {
    let entry: MarketEntry
    @Environment(\.widgetFamily) private var family

    private var dayNumber: String { "\(Calendar.current.component(.day, from: entry.date))" }
    private var monthText: String { "\(Calendar.current.component(.month, from: entry.date))月" }
    private var weekdayText: String { LunarCalendar.weekdayText(entry.date) }
    private var lunarText: String { LunarCalendar.lunarText(entry.date) }

    private func names(_ list: [Market]) -> String {
        list.isEmpty ? "无圩" : list.prefix(3).map(\.name).joined(separator: " ")
    }
    private func count(_ list: [Market]) -> String {
        list.isEmpty ? "休市" : "\(list.count)场"
    }

    var body: some View {
        switch family {
        case .systemSmall: smallView
        case .systemMedium: mediumView
        default: largeView
        }
    }

    // 小号：日期 + 今日圩。
    private var smallView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: entry.todayMarkets.isEmpty ? "moon.fill" : "basket.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(entry.todayMarkets.isEmpty ? Ink.night : Ink.gold)
                Text(entry.todayMarkets.isEmpty ? "今日休市" : "今日开圩")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(Ink.white)
            }
            Spacer(minLength: 0)
            Text(dayNumber)
                .font(.system(size: 58, weight: .black, design: .rounded))
                .foregroundStyle(Ink.white)
            Text("\(monthText)·\(weekdayText) \(lunarText)")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Ink.white.opacity(0.9))
                .lineLimit(1)
            Text(names(entry.todayMarkets))
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Ink.white)
                .lineLimit(2)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // 中号：三列竖条。
    private var mediumView: some View {
        HStack(spacing: 8) {
            column("今天", entry.todayMarkets, hot: true)
            column("明天", entry.tomorrowMarkets, hot: false)
            column("后天", entry.dayAfterMarkets, hot: false)
        }
        .padding(12)
    }

    private func column(_ title: String, _ markets: [Market], hot: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(hot ? Ink.night : Ink.white)
                .padding(.horizontal, 9).padding(.vertical, 4)
                .background(hot ? Ink.cream : Ink.white.opacity(0.16), in: Capsule())
            Spacer(minLength: 0)
            Text(count(markets))
                .font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundStyle(Ink.white)
            Text(names(markets))
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Ink.white.opacity(0.88))
                .lineLimit(3)
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Ink.white.opacity(hot ? 0.16 : 0.08), in: RoundedRectangle(cornerRadius: 15))
    }

    // 大号：标题 + 三行。
    private var largeView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(dayNumber)
                    .font(.system(size: 52, weight: .black, design: .rounded))
                    .foregroundStyle(Ink.white)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(monthText)·\(weekdayText)").font(.system(size: 12, weight: .bold)).foregroundStyle(Ink.white)
                    Text("\(lunarText) · \(LunarCalendar.ganzhiName(entry.date))日")
                        .font(.system(size: 11)).foregroundStyle(Ink.white.opacity(0.85))
                }
                Spacer()
                Text(entry.region)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Ink.white.opacity(0.9))
                    .lineLimit(1)
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(Ink.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))

            row("今天", entry.todayMarkets, Ink.gold)
            row("明天", entry.tomorrowMarkets, Color(red: 0.45, green: 0.62, blue: 0.40))
            row("后天", entry.dayAfterMarkets, Ink.cream)
            Spacer(minLength: 0)
        }
        .padding(14)
    }

    private func row(_ title: String, _ markets: [Market], _ tone: Color) -> some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 3).fill(tone).frame(width: 5, height: 38)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 11, weight: .heavy)).foregroundStyle(Ink.white)
                Text(names(markets)).font(.system(size: 12, weight: .semibold)).foregroundStyle(Ink.white.opacity(0.9)).lineLimit(1)
            }
            Spacer(minLength: 0)
            Text(count(markets))
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Ink.white)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(tone, in: Capsule())
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(Ink.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 13))
    }
}

// MARK: - Widget

@main
struct GanJiWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: widgetKindID, provider: MarketTimeline()) { entry in
            ZStack {
                PhotoBackdrop(image: entry.backdrop)
                MarketWidgetView(entry: entry)
            }
        }
        .contentMarginsDisabled()
        .configurationDisplayName("赶集日记")
        .description("真实照片背景，查看今天、明天、后天的圩日")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
