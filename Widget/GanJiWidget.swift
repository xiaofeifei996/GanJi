import SwiftUI
import WidgetKit
import UIKit
import os

private let ganJiLog = Logger(subsystem: "com.ganji.diary.widget", category: "photo")

private let ganJiGroupID = "group.com.ganji.diary"
private let ganJiWidgetKind = "GanJiWidget"

private struct GanJiWidgetEntry: TimelineEntry {
    let date: Date
    let areaName: String
    let today: [Market]
    let tomorrow: [Market]
    let dayAfter: [Market]
    /// Loaded by the provider so the view body only ever draws a value.
    var photo: UIImage? = nil
    /// Temporary on-screen diagnostic while the photo does not appear.
    var diagnostic: String = ""
}

private struct GanJiWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> GanJiWidgetEntry {
        GanJiWidgetEntry(date: Date(), areaName: "赶集日记", today: [], tomorrow: [], dayAfter: [])
    }

    func getSnapshot(in context: Context, completion: @escaping (GanJiWidgetEntry) -> Void) {
        // Widget gallery previews must be returned immediately. Waiting for a network
        // image download can make iOS show its generic gray placeholder for small/medium.
        completion(makeEntry(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<GanJiWidgetEntry>) -> Void) {
        // Answer immediately, then fetch the photo in the background and reload.
        refreshWidgetPhoto()
        let entry = makeEntry(in: context)
        let nextRefresh = Calendar.current.nextDate(
            after: Date(),
            matching: DateComponents(hour: 0, minute: 5),
            matchingPolicy: .nextTime
        ) ?? Date().addingTimeInterval(3600)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }

    /// Download a real market-produce photograph into the shared App Group container.
    /// The widget uses the last cached image when the network is unavailable.
    ///
    /// The download finishes independently of the timeline: the entry is handed to
    /// WidgetKit at once, and the photo is asked for again with
    /// WidgetCenter.reloadTimelines when the file has been written. Waiting for the
    /// request before answering a timeline can make WidgetKit drop the entry and
    /// leave the widget without its photo.
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
            do {
                try data.write(to: destination, options: .atomic)
            } catch {
                return
            }
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

        let photoResult = WidgetPhotoStore.load(for: context.family)
        return GanJiWidgetEntry(
            date: Date(),
            areaName: areaName.isEmpty ? "赶集日记" : areaName,
            today: markets.filter { MarketStore.opens(on: today, market: $0) },
            tomorrow: markets.filter { MarketStore.opens(on: tomorrow, market: $0) },
            dayAfter: markets.filter { MarketStore.opens(on: dayAfter, market: $0) },
            photo: photoResult.photo,
            diagnostic: "OS\(ProcessInfo.processInfo.operatingSystemVersion.majorVersion) \(photoResult.status)"
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

/// The backdrop is the real photograph: the one the user picked for this widget
/// size, else the downloaded market photo. A file that cannot be decoded counts
/// as missing. Only when no photo exists at all does a gradient stand in.
private struct WidgetBackdrop: View {
    /// Resolved by the timeline, which runs outside the view body, so the view
    /// only ever draws a value that SwiftUI can compare between renders.
    let photo: UIImage?
    /// Temporary on-screen diagnostic while the photo does not appear on iOS 26.
    let diagnostic: String

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if let photo {
                    Image(uiImage: photo)
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                } else {
                    LinearGradient(
                        colors: [WidgetPalette.paper, Color(red: 0.82, green: 0.89, blue: 0.77)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
                // A restrained dark wash keeps the light text legible.
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
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
    }
}

/// Loads the photo for one widget family from the App Group container.
enum WidgetPhotoStore {
    /// The photo and a short status the widget can display on screen.
    struct Result {
        let photo: UIImage?
        let status: String
    }

    static func load(for family: WidgetFamily) -> Result {
        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: ganJiGroupID
        ) else {
            ganJiLog.error("no App Group container for \(ganJiGroupID, privacy: .public)")
            return Result(photo: nil, status: "无容器")
        }

        let customFileName: String
        switch family {
        case .systemSmall: customFileName = "GanJiWidgetPhoto-small.jpg"
        case .systemMedium: customFileName = "GanJiWidgetPhoto-medium.jpg"
        default: customFileName = "GanJiWidgetPhoto-large.jpg"
        }

        var notes: [String] = []
        for name in [customFileName, "GanJiWidgetMarket.jpg"] {
            let url = container.appendingPathComponent(name)
            let exists = FileManager.default.fileExists(atPath: url.path)
            let bytes = (try? Data(contentsOf: url))?.count ?? 0
            let image = image(in: container, named: name)
            let tag = name == customFileName ? "自选" : "下载"
            notes.append("\(tag)\(exists ? "有" : "无")\(bytes > 0 ? "\(bytes / 1024)K" : "")\(image != nil ? "✓" : "✗")")
            ganJiLog.notice("photo \(name, privacy: .public) exists=\(exists, privacy: .public) bytes=\(bytes, privacy: .public) decoded=\(image != nil, privacy: .public)")
            if let image { return Result(photo: image, status: notes.joined(separator: " ")) }
        }
        return Result(photo: nil, status: notes.joined(separator: " "))
    }

    private static func image(in container: URL, named name: String) -> UIImage? {
        let url = container.appendingPathComponent(name)
        guard let data = try? Data(contentsOf: url), !data.isEmpty,
              let image = UIImage(data: data), image.size.width > 0 else { return nil }
        return downsized(image)
    }

    /// WidgetKit renders a container background from a bitmap; a full-resolution
    /// photo (the picked image is 1440x2558) can be too large and fail to draw,
    /// which is why the widget falls back to nothing. Cap the decoded image to
    /// what a widget needs (2x the largest family) so the drawing always works.
    private static func downsized(_ image: UIImage) -> UIImage {
        let maxDimension: CGFloat = 800
        let scale = max(image.size.width, image.size.height)
        guard scale > maxDimension else { return image }
        let ratio = maxDimension / scale
        let newSize = CGSize(width: (image.size.width * ratio).rounded(),
                             height: (image.size.height * ratio).rounded())
        guard newSize.width > 0, newSize.height > 0 else { return image }
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
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
        .overlay(alignment: .bottom) {
            if !entry.diagnostic.isEmpty {
                Text(entry.diagnostic)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(.red, in: RoundedRectangle(cornerRadius: 4))
                    .padding(4)
            }
        }
    }

    // 小号：突出日期与今日是否有集市，减少次要信息。
    // Sizes are kept inside the ~158pt small widget: 68pt numerals plus two
    // flexible spacers overflowed it, and an overflowing VStack pushed the
    // photo background out of the widget on iOS 26.
    private var small: some View {
        VStack(alignment: .leading, spacing: 0) {
            brandLine

            Spacer(minLength: 2)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(dayNumber)
                    .font(.system(size: 54, weight: .black, design: .rounded))
                    .tracking(-4)
                    .foregroundStyle(WidgetPalette.forest)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .layoutPriority(1)
                VStack(alignment: .leading, spacing: 1) {
                    Text(month)
                        .font(.system(size: 9, weight: .heavy, design: .rounded))
                        .tracking(1)
                    Text(weekday)
                        .font(.system(size: 9, weight: .semibold))
                }
                .foregroundStyle(WidgetPalette.secondary)
                .fixedSize()
            }

            Spacer(minLength: 2)
            HStack(spacing: 6) {
                Image(systemName: entry.today.isEmpty ? "sun.max.fill" : "basket.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 26, height: 26)
                    .background(entry.today.isEmpty ? WidgetPalette.orange : WidgetPalette.leaf, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                VStack(alignment: .leading, spacing: 1) {
                    Text(entry.today.isEmpty ? "今日休市" : "今日开集")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(WidgetPalette.secondary)
                    Text(entry.today.first?.name ?? "暂无安排")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(WidgetPalette.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                Spacer(minLength: 0)
                if entry.today.count > 1 {
                    Text("+\(entry.today.count - 1)")
                        .font(.system(size: 9, weight: .heavy, design: .rounded))
                        .foregroundStyle(WidgetPalette.forest)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).stroke(.white.opacity(0.55), lineWidth: 1))
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

@main
struct GanJiWidget: Widget {
    let kind = ganJiWidgetKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: GanJiWidgetProvider()) { entry in
            // Draw the photo as the base layer of the widget's own content for
            // every family, one path for all three.
            ZStack {
                WidgetBackdrop(photo: entry.photo, diagnostic: entry.diagnostic)
                GanJiWidgetView(entry: entry)
                    // WidgetKit redacts gallery placeholders by default, which turns
                    // the small/medium previews into gray skeletons. Keep our designed
                    // preview visible.
                    .unredacted()
            }
        }
        // The layouts pad their own content, so the default .widget content margins
        // would only inset the photograph and the text twice.
        .contentMarginsDisabled()
        .configurationDisplayName("赶集日记")
        .description("查看今天、明天、后天的赶集安排")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
