import SwiftUI
import WidgetKit
import UIKit

private let ganJiGroupID = "group.com.ganji.diary"
private let ganJiWidgetKind = "GanJiWidget"

// MARK: - Timeline entry & provider

private struct GanJiWidgetEntry: TimelineEntry {
    let date: Date
    let areaName: String
    let today: [Market]
    let tomorrow: [Market]
    let dayAfter: [Market]
    var photo: UIImage? = nil
}

private struct GanJiWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> GanJiWidgetEntry {
        GanJiWidgetEntry(date: Date(), areaName: "赶集日记", today: [], tomorrow: [], dayAfter: [])
    }

    func getSnapshot(in context: Context, completion: @escaping (GanJiWidgetEntry) -> Void) {
        completion(makeEntry(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<GanJiWidgetEntry>) -> Void) {
        refreshWidgetPhoto()
        let entry = makeEntry(in: context)
        let nextRefresh = Calendar.current.nextDate(
            after: Date(),
            matching: DateComponents(hour: 0, minute: 5),
            matchingPolicy: .nextTime
        ) ?? Date().addingTimeInterval(3600)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }

    private func refreshWidgetPhoto() {
        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: ganJiGroupID
        ) else { return }
        let destination = container.appendingPathComponent("GanJiWidgetMarket.jpg")
        let url = URL(string: "https://images.unsplash.com/photo-1586480185285-9e602c969a95?auto=format&fit=crop&w=1400&q=88")!
        URLSession.shared.dataTask(with: url) { data, response, error in
            guard error == nil,
                  let http = response as? HTTPURLResponse,
                  (200...299).contains(http.statusCode),
                  let data, UIImage(data: data) != nil else { return }
            do { try data.write(to: destination, options: .atomic) }
            catch { return }
            WidgetCenter.shared.reloadTimelines(ofKind: ganJiWidgetKind)
        }.resume()
    }

    private func makeEntry(in context: Context) -> GanJiWidgetEntry {
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
            dayAfter: markets.filter { MarketStore.opens(on: dayAfter, market: $0) },
            photo: WidgetPhotoStore.photo(for: context.family)
        )
    }
}

// MARK: - Photo loading

private enum WidgetPhotoStore {
    static func photo(for family: WidgetFamily) -> UIImage? {
        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: ganJiGroupID
        ) else { return nil }

        let custom: String
        switch family {
        case .systemSmall: custom = "GanJiWidgetPhoto-small.jpg"
        case .systemMedium: custom = "GanJiWidgetPhoto-medium.jpg"
        default: custom = "GanJiWidgetPhoto-large.jpg"
        }

        if let image = image(in: container, named: custom) { return image }
        return image(in: container, named: "GanJiWidgetMarket.jpg")
    }

    private static func image(in container: URL, named name: String) -> UIImage? {
        let url = container.appendingPathComponent(name)
        guard let data = try? Data(contentsOf: url), !data.isEmpty,
              let image = UIImage(data: data), image.size.width > 0 else { return nil }
        return downsized(image)
    }

    private static func downsized(_ image: UIImage) -> UIImage {
        let maxDimension: CGFloat = 800
        let longest = max(image.size.width, image.size.height)
        guard longest > maxDimension else { return image }
        let ratio = maxDimension / longest
        let size = CGSize(width: (image.size.width * ratio).rounded(),
                          height: (image.size.height * ratio).rounded())
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
    }
}

// MARK: - Theme

private enum T {
    static let warm = Color(red: 0.98, green: 0.93, blue: 0.84)
    static let sand = Color(red: 0.91, green: 0.85, blue: 0.72)
    static let clay = Color(red: 0.83, green: 0.55, blue: 0.34)
    static let moss = Color(red: 0.45, green: 0.60, blue: 0.38)
    static let deep = Color(red: 0.22, green: 0.28, blue: 0.22)
}

// MARK: - Background

private struct WidgetBackdrop: View {
    let photo: UIImage?

    var body: some View {
        ZStack {
            if let photo {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
            } else {
                LinearGradient(colors: [T.warm, T.sand],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            }
            Color.black.opacity(0.30)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }
}

// MARK: - Widget content

private struct GanJiWidgetView: View {
    let entry: GanJiWidgetEntry
    @Environment(\.widgetFamily) private var family

    private var solarDay: String { "\(Calendar.current.component(.day, from: entry.date))" }
    private var solarMonth: String { "\(Calendar.current.component(.month, from: entry.date))月" }
    private var solarWeekday: String { LunarCalendar.weekdayText(entry.date) }
    private var lunarText: String { LunarCalendar.lunarText(entry.date) }
    private var gzText: String { LunarCalendar.ganzhiName(entry.date) }

    private func firstNames(_ markets: [Market]) -> String {
        markets.isEmpty ? "无" : markets.prefix(3).map(\.name).joined(separator: " ")
    }

    private func countText(_ markets: [Market]) -> String {
        markets.isEmpty ? "休市" : "\(markets.count) 场"
    }

    var body: some View {
        switch family {
        case .systemSmall: small
        case .systemMedium: medium
        default: large
        }
    }

    // 小号：底部大数字日期，顶部状态圆点。
    private var small: some View {
        VStack(spacing: 0) {
            HStack {
                Circle()
                    .fill(entry.today.isEmpty ? T.sand : T.clay)
                    .frame(width: 7, height: 7)
                Text(entry.today.isEmpty ? "今日休市" : "今日有圩")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer()
                Text(solarMonth)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white.opacity(0.8))
            }
            Spacer(minLength: 0)
            HStack(alignment: .lastTextBaseline, spacing: 6) {
                Text(solarDay)
                    .font(.system(size: 84, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.6)
                VStack(alignment: .leading, spacing: 3) {
                    Text(solarWeekday).font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
                    Text(lunarText).font(.system(size: 11)).foregroundStyle(.white.opacity(0.85))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
    }

    // 中号：三张等宽竖向卡片，今天高亮。
    private var medium: some View {
        HStack(spacing: 8) {
            dayColumn(title: "今天", markets: entry.today, highlight: true)
            dayColumn(title: "明天", markets: entry.tomorrow, highlight: false)
            dayColumn(title: "后天", markets: entry.dayAfter, highlight: false)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func dayColumn(title: String, markets: [Market], highlight: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(highlight ? T.deep : .white.opacity(0.9))
                .padding(.horizontal, 9).padding(.vertical, 4)
                .background(highlight ? T.warm : .white.opacity(0.16),
                            in: Capsule())
            Spacer(minLength: 0)
            Text(countText(markets))
                .font(.system(size: 26, weight: .black, design: .rounded))
                .foregroundStyle(.white)
            Text(firstNames(markets))
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(3)
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.white.opacity(highlight ? 0.14 : 0.08),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // 大号：顶部横贯日期标题，下方三行排班。
    private var large: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(solarDay)
                    .font(.system(size: 58, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(solarMonth) · \(solarWeekday)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                    Text("\(lunarText) · \(gzText)日")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.8))
                }
                Spacer()
                Text(entry.areaName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(1)
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(.white.opacity(0.12),
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous))

            VStack(spacing: 8) {
                scheduleRow(title: "今天", markets: entry.today, tone: T.clay)
                scheduleRow(title: "明天", markets: entry.tomorrow, tone: T.moss)
                scheduleRow(title: "后天", markets: entry.dayAfter, tone: T.sand)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func scheduleRow(title: String, markets: [Market], tone: Color) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 3)
                .fill(tone)
                .frame(width: 5, height: 40)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 11, weight: .heavy)).foregroundStyle(.white)
                Text(markets.isEmpty ? "今日无圩" : markets.prefix(3).map(\.name).joined(separator: "、"))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Text(countText(markets))
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(tone, in: Capsule())
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(.white.opacity(0.09),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - Widget

@main
struct GanJiWidget: Widget {
    let kind = ganJiWidgetKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: GanJiWidgetProvider()) { entry in
            ZStack {
                WidgetBackdrop(photo: entry.photo)
                GanJiWidgetView(entry: entry)
                    .unredacted()
            }
        }
        .contentMarginsDisabled()
        .configurationDisplayName("赶集日记")
        .description("查看今天、明天、后天的赶集安排")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
