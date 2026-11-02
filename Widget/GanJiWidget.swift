import SwiftUI
import WidgetKit
import UIKit

private let ganJiGroupID = "group.com.ganji.diary"
private let ganJiWidgetKind = "GanJiWidget"

// MARK: - Timeline

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

// MARK: - Photo

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

    /// WidgetKit draws a container-sized bitmap; a full-resolution photo can be
    /// too large to draw. Cap the long edge at twice the largest widget size.
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

// MARK: - Palette

private enum P {
    static let paper = Color(red: 0.98, green: 0.96, blue: 0.90)
    static let field = Color(red: 0.82, green: 0.89, blue: 0.77)
    static let ink = Color.white
    static let sub = Color.white.opacity(0.84)
    static let accent = Color(red: 1.0, green: 0.80, blue: 0.42)
    static let leaf = Color(red: 0.55, green: 0.80, blue: 0.50)
}

// MARK: - Backdrop

private struct WidgetBackdrop: View {
    let photo: UIImage?

    var body: some View {
        ZStack {
            if let photo {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
            } else {
                LinearGradient(colors: [P.paper, P.field],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            }
            // A gentle dark wash keeps white text readable over any photo.
            LinearGradient(colors: [.black.opacity(0.45), .black.opacity(0.18), .black.opacity(0.52)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }
}

// MARK: - Content

private struct GanJiWidgetView: View {
    let entry: GanJiWidgetEntry
    @Environment(\.widgetFamily) private var family

    private var day: String { "\(Calendar.current.component(.day, from: entry.date))" }
    private var month: String { "\(Calendar.current.component(.month, from: entry.date))月" }
    private var weekday: String { LunarCalendar.weekdayText(entry.date) }
    private var totalCount: Int { entry.today.count + entry.tomorrow.count + entry.dayAfter.count }

    var body: some View {
        switch family {
        case .systemSmall: small
        case .systemMedium: medium
        default: large
        }
    }

    private func names(_ markets: [Market]) -> String {
        markets.isEmpty ? "暂无" : markets.prefix(2).map(\.name).joined(separator: "、")
    }

    private var brand: some View {
        HStack(spacing: 5) {
            Image(systemName: "leaf.fill")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(P.leaf)
            Text("赶集日记")
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(P.ink)
            Circle().fill(P.leaf.opacity(0.6)).frame(width: 3, height: 3)
            Text("赶集生活")
                .font(.system(size: 8, weight: .bold, design: .rounded))
                .tracking(1)
                .foregroundStyle(P.sub)
        }
        .lineLimit(1)
    }

    // 小号：日期 + 今日开集。
    private var small: some View {
        VStack(alignment: .leading, spacing: 0) {
            brand
            Spacer(minLength: 6)
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(day)
                    .font(.system(size: 50, weight: .black, design: .rounded))
                    .foregroundStyle(P.ink)
                VStack(alignment: .leading, spacing: 1) {
                    Text(month).font(.system(size: 10, weight: .bold))
                    Text(weekday).font(.system(size: 10, weight: .semibold))
                }
                .foregroundStyle(P.sub)
            }
            Spacer(minLength: 6)
            HStack(spacing: 6) {
                Image(systemName: entry.today.isEmpty ? "sun.max.fill" : "basket.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
                    .background(entry.today.isEmpty ? P.accent : P.leaf,
                                in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                VStack(alignment: .leading, spacing: 1) {
                    Text(entry.today.isEmpty ? "今日休市" : "今日开集")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(P.sub)
                    Text(names(entry.today))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(P.ink)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 8).padding(.vertical, 6)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // 中号：左侧日期，右侧三天清单。
    private var medium: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 0) {
                brand
                Spacer(minLength: 6)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(day)
                        .font(.system(size: 56, weight: .black, design: .rounded))
                        .foregroundStyle(P.ink)
                    Text(month)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(P.sub)
                }
                Text("\(weekday) · \(entry.areaName)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(P.sub)
                Spacer(minLength: 6)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Rectangle().fill(P.sub.opacity(0.4)).frame(width: 1).padding(.vertical, 4)

            VStack(spacing: 8) {
                row("今天", entry.today, P.leaf)
                row("明天", entry.tomorrow, P.accent)
                row("后天", entry.dayAfter, P.leaf)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // 大号：日期 + 三日卡片。
    private var large: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    brand
                    Text(entry.areaName)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(P.sub)
                }
                Spacer()
                Image(systemName: "basket.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(P.accent)
                    .frame(width: 36, height: 36)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            HStack(alignment: .lastTextBaseline, spacing: 8) {
                Text(day)
                    .font(.system(size: 66, weight: .black, design: .rounded))
                    .foregroundStyle(P.ink)
                VStack(alignment: .leading, spacing: 2) {
                    Text(month).font(.system(size: 11, weight: .bold)).foregroundStyle(P.sub)
                    Text(weekday).font(.system(size: 11, weight: .semibold)).foregroundStyle(P.accent)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("未来三日").font(.system(size: 10)).foregroundStyle(P.sub)
                    Text("\(totalCount) 场赶集")
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .foregroundStyle(P.ink)
                }
            }
            Rectangle().fill(P.sub.opacity(0.4)).frame(height: 1)
            VStack(spacing: 7) {
                card("今天", "今日赶集", entry.today, P.leaf)
                card("明天", "提前安排", entry.tomorrow, P.accent)
                card("后天", "出行计划", entry.dayAfter, P.leaf)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func row(_ title: String, _ markets: [Market], _ tint: Color) -> some View {
        HStack(spacing: 7) {
            Capsule().fill(tint).frame(width: 3, height: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 9, weight: .bold)).foregroundStyle(tint)
                Text(names(markets)).font(.system(size: 10, weight: .semibold)).foregroundStyle(P.ink).lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8).padding(.vertical, 5)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func card(_ title: String, _ subtitle: String, _ markets: [Market], _ tint: Color) -> some View {
        HStack(spacing: 9) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 11, weight: .heavy)).foregroundStyle(tint)
                Text(subtitle).font(.system(size: 7, weight: .bold)).foregroundStyle(P.sub)
            }
            .frame(width: 60, alignment: .leading)
            Capsule().fill(tint.opacity(0.7)).frame(width: 3, height: 26)
            Text(names(markets)).font(.system(size: 11, weight: .semibold)).foregroundStyle(P.ink).lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10).padding(.vertical, 7)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
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
