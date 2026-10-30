import WidgetKit
import SwiftUI

struct DayItem: Identifiable {
    let id: String
    let name: String
    var short: String { name.replacingOccurrences(of: "圩", with: "") }
}

struct GanJiEntry: TimelineEntry {
    let date: Date
    let days: [Date]
    let sections: [[DayItem]]
    var isPlaceholder: Bool = false
}

struct MarketProvider: TimelineProvider {
    private func build(_ date: Date) -> GanJiEntry {
        let cal = Calendar.current
        let day = cal.startOfDay(for: date)
        let days = (0..<3).compactMap { cal.date(byAdding: .day, value: $0, to: day) }
        // Read only the App Group cache. The widget needs exactly three dates,
        // so do not scan 40 days ahead for every favorite market.
        let shared = UserDefaults(suiteName: "group.com.ganji.diary")
        let favoriteIDs = Set(shared?.stringArray(forKey: "GanJiFavoriteMarketIDs") ?? [])
        let favoriteData = shared?.data(forKey: "GanJiFavoriteMarketsData") ?? Data()
        let savedFavorites = (try? JSONDecoder().decode([Market].self, from: favoriteData)) ?? []
        let homeMarkets = savedFavorites.filter { favoriteIDs.contains($0.id) }
        let sections = days.enumerated().map { offset, targetDate in
            homeMarkets
                .filter { MarketStore.opens(on: targetDate, market: $0) }
                .sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
                .map { DayItem(id: $0.id, name: $0.name) }
        }
        return GanJiEntry(date: date, days: days, sections: sections)
    }

    // Keep the widget gallery / first-add preview fully designed without reading
    // shared defaults or market files while WidgetKit is requesting a placeholder.
    func placeholder(in context: Context) -> GanJiEntry {
        // Keep the placeholder extremely cheap. WidgetKit may request it while
        // the extension is starting; never decode data or calculate market dates here.
        let now = Date()
        let cal = Calendar.current
        let day = cal.startOfDay(for: now)
        let days = (0..<3).compactMap { cal.date(byAdding: .day, value: $0, to: day) }
        return GanJiEntry(date: now, days: days, sections: [[], [], []], isPlaceholder: true)
    }
    func getSnapshot(in context: Context, completion: @escaping (GanJiEntry) -> Void) {
        if context.isPreview {
            completion(placeholder(in: context))
        } else {
            completion(build(Date()))
        }
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<GanJiEntry>) -> Void) {
        // Build only the current entry. Computing eight complete market timelines
        // synchronously can be expensive because each market may require up to
        // 40 lunar-day checks. If WidgetKit times out this request, the widget can
        // remain on its grey placeholder instead of receiving real content.
        let now = Date()
        let entry = build(now)
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))
            ?? now.addingTimeInterval(24 * 60 * 60)
        completion(Timeline(entries: [entry], policy: .after(tomorrow)))
    }
}

// Explicitly draw the asset as the widget's full-bleed background.
// Avoid GeometryReader-based image selection in containerBackground: WidgetKit may
// provide a constrained proposal, which can leave the fallback paper color visible.
private struct WidgetCanvas: View {
    let dark: Bool
    @Environment(\.widgetFamily) private var family

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                // Use the existing Han Li artwork shipped with the widget target.
                // Square crop for small widgets; wide artwork for medium/large.
                Image(family == .systemSmall ? "HanLi-square" : "HanLi-wide")
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()

                // A subtle ink-paper veil keeps widget text readable without
                // hiding Han Li or the misty mountain scenery.
                LinearGradient(
                    colors: dark
                        ? [Color.black.opacity(0.34), Color(red: 0.04, green: 0.10, blue: 0.13).opacity(0.30)]
                        : [Color(red: 0.97, green: 0.96, blue: 0.91).opacity(0.28), Color(red: 0.91, green: 0.94, blue: 0.92).opacity(0.12)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
        .accessibilityHidden(true)
    }
}

private struct LandscapeMiniature: View {
    @Environment(\.colorScheme) private var colorScheme
    private var dark: Bool { colorScheme == .dark }

    var body: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(
                colors: dark
                    ? [Color(red: 0.12, green: 0.25, blue: 0.28), Color(red: 0.08, green: 0.19, blue: 0.18)]
                    : [Color(red: 0.80, green: 0.90, blue: 0.91), Color(red: 0.93, green: 0.92, blue: 0.82)],
                startPoint: .top,
                endPoint: .bottom
            )
            Circle()
                .fill(Color(red: 1.0, green: 0.74, blue: 0.39).opacity(dark ? 0.70 : 0.95))
                .frame(width: 15, height: 15)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(.top, 12)
                .padding(.trailing, 14)
            Ellipse()
                .fill(dark ? Color(red: 0.19, green: 0.39, blue: 0.34) : Color(red: 0.61, green: 0.77, blue: 0.68))
                .frame(width: 145, height: 38)
                .offset(x: -20, y: 8)
            Ellipse()
                .fill(dark ? Color(red: 0.10, green: 0.29, blue: 0.23) : Color(red: 0.38, green: 0.62, blue: 0.47))
                .frame(width: 130, height: 27)
                .offset(x: 32, y: 10)
            HStack(alignment: .bottom, spacing: 3) {
                villageHouse(width: 15, height: 17)
                villageHouse(width: 19, height: 22)
                villageHouse(width: 13, height: 15)
            }
            .offset(x: 8, y: -13)
        }
        .clipped()
        .accessibilityHidden(true)
    }

    private func villageHouse(width: CGFloat, height: CGFloat) -> some View {
        VStack(spacing: 0) {
            Triangle()
                .fill(Color(red: 0.78, green: 0.40, blue: 0.25))
                .frame(width: width + 5, height: 7)
            Rectangle()
                .fill(dark ? Color(red: 0.83, green: 0.81, blue: 0.70) : Color(red: 1.0, green: 0.97, blue: 0.87))
                .frame(width: width, height: height - 7)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(Color(red: 0.42, green: 0.57, blue: 0.55)).frame(width: 4, height: 7)
                }
        }
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
        }
    }
}

private struct PaperCard<Content: View>: View {
    let dark: Bool
    let content: Content
    init(dark: Bool, @ViewBuilder content: () -> Content) {
        self.dark = dark
        self.content = content()
    }
    var body: some View {
        content
            .padding(10)
            .background(dark ? Color(red: 0.12, green: 0.20, blue: 0.18) : Color(red: 1.0, green: 0.99, blue: 0.95), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).stroke(dark ? Color.white.opacity(0.06) : Color(red: 0.83, green: 0.78, blue: 0.62).opacity(0.42), lineWidth: 0.6))
    }
}

struct GanJiWidgetView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var colorScheme
    let entry: GanJiEntry
    private var dark: Bool { colorScheme == .dark }
    private var small: Bool { family == .systemSmall }
    private var large: Bool { family == .systemLarge }
    private let ink = Color(red: 0.12, green: 0.22, blue: 0.18)
    private let vermilion = Color(red: 0.96, green: 0.43, blue: 0.08)
    private var primaryInk: Color { dark ? Color(red: 0.97, green: 0.94, blue: 0.84) : ink }
    private var secondaryInk: Color { dark ? Color.white.opacity(0.76) : ink.opacity(0.72) }

    var body: some View {
        Group {
            if entry.isPlaceholder {
                previewContent
            } else {
                // Draw the photo inside the widget content instead of using
                // containerBackground, which iOS 26 can remove/replace when
                // the Home Screen uses the clear/glass widget appearance.
                content
                    .background {
                        GeometryReader { proxy in
                            WidgetCanvas(dark: dark)
                                .frame(width: proxy.size.width, height: proxy.size.height)
                        }
                    }
                    .clipped()
            }
        }
        .unredacted()
    }

    private var previewContent: some View {
        ZStack {
            Color(red: 0.94, green: 0.95, blue: 0.88)
            VStack(alignment: .leading, spacing: 8) {
                Text("赶集日记")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(Color(red: 0.12, green: 0.22, blue: 0.18))
                Text("今日圩日")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(Color(red: 0.12, green: 0.22, blue: 0.18))
                Text("圩日预览")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(Color(red: 0.12, green: 0.22, blue: 0.18))
                Text("打开 App 同步圩日")
                    .font(.caption)
                    .foregroundColor(Color(red: 0.75, green: 0.28, blue: 0.12))
                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    @ViewBuilder private var legacyContent: some View {
        ZStack {
            (dark ? Color(red: 0.07, green: 0.16, blue: 0.15) : Color(red: 0.94, green: 0.95, blue: 0.88))
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 5) {
                    Image(systemName: "leaf.fill")
                    Text("赶集日记")
                        .fontWeight(.bold)
                    Spacer(minLength: 0)
                    Text(entry.date, style: .date)
                        .font(.caption2)
                }
                .font(.caption)
                .foregroundColor(dark ? .white : Color(red: 0.12, green: 0.22, blue: 0.18))

                ForEach(0..<3, id: \.self) { index in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(["今日", "明日", "后日"][index])
                            .font(.caption2)
                            .fontWeight(.semibold)
                        Text(legacyMarketNames(index))
                            .font(index == 0 ? .headline : .subheadline)
                            .fontWeight(.bold)
                            .lineLimit(2)
                            .minimumScaleFactor(0.65)
                    }
                    .foregroundColor(dark ? .white : Color(red: 0.12, green: 0.22, blue: 0.18))
                    if index < 2 {
                        Divider().opacity(0.45)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    private func legacyMarketNames(_ index: Int) -> String {
        if entry.isPlaceholder {
            return index == 0 ? "圩日预览" : "待同步"
        }
        guard entry.sections.indices.contains(index) else { return "暂无数据" }
        let items = entry.sections[index]
        if items.isEmpty { return index == 0 ? "今日无圩" : "暂无圩日" }
        return items.map { $0.name }.joined(separator: " · ")
    }

    private func names(_ offset: Int, short: Bool = false) -> String {
        if entry.isPlaceholder { return offset == 0 ? "圩日预览" : "待同步" }
        guard entry.sections.indices.contains(offset) else { return "—" }
        let items = entry.sections[offset]
        return items.isEmpty ? (offset == 0 ? "今日无圩" : "暂无圩日") : items.map { short ? $0.short : $0.name }.joined(separator: " · ")
    }
    private func numericDate(_ date: Date) -> String {
        let c = Calendar.current.dateComponents([.month, .day], from: date)
        return "\(c.month ?? 1)/\(c.day ?? 1)"
    }

    @ViewBuilder private var content: some View {
        if small { smallLayout }
        else if family == .systemMedium { mediumLayout }
        else { largeLayout }
    }

    private var header: some View {
        HStack(spacing: 5) {
            Image(systemName: "leaf.fill").font(.system(size: 10, weight: .bold)).foregroundColor(dark ? Color(red: 0.98, green: 0.79, blue: 0.53) : vermilion)
            Text("赶集日记").font(.system(size: 12, weight: .bold, design: .rounded)).foregroundColor(primaryInk)
            Spacer(minLength: 2)
            Text("本地圩日历").font(.system(size: 9, weight: .medium)).foregroundColor(secondaryInk)
        }
    }

    private var smallLayout: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                ZStack {
                    Circle().fill(vermilion.opacity(0.14)).frame(width: 23, height: 23)
                    Image(systemName: "basket.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(vermilion)
                }
                Text("今日圩日")
                    .font(.system(size: 12, weight: .heavy, design: .serif))
                    .foregroundColor(primaryInk)
                Spacer(minLength: 1)
                Text("今天")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(ink)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color(red: 0.84, green: 0.89, blue: 0.70), in: Capsule())
            }

            Rectangle()
                .fill(vermilion.opacity(0.55))
                .frame(height: 1)

            Text(names(0, short: true))
                .font(.system(size: 22, weight: .heavy, design: .serif))
                .foregroundColor(primaryInk)
                .lineLimit(2)
                .minimumScaleFactor(0.62)
                .fixedSize(horizontal: false, vertical: true)

            Text(entry.isPlaceholder ? "打开 App 同步圩日" :
                 (entry.sections.first?.isEmpty == false ? "今天开圩 · 记得出发" : "今日暂无圩日"))
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(vermilion)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Spacer(minLength: 1)

            HStack(alignment: .bottom, spacing: 4) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(LunarCalendar.shortDate(entry.date))  \(LunarCalendar.weekdayText(entry.date))")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(secondaryInk)
                        .lineLimit(1)
                    Text("农历 \(LunarCalendar.lunarText(entry.date))")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(secondaryInk)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: "sun.max.fill")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(vermilion.opacity(0.85))
            }
        }
        .padding(11)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(dark ? Color.white.opacity(0.035) : Color.white.opacity(0.22),
                    in: RoundedRectangle(cornerRadius: 15, style: .continuous))
    }

    private var mediumLayout: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 6) {
                ZStack {
                    Circle().fill(vermilion.opacity(0.14)).frame(width: 25, height: 25)
                    Image(systemName: "basket.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(vermilion)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text("今日圩日")
                        .font(.system(size: 15, weight: .heavy, design: .serif))
                        .foregroundColor(primaryInk)
                    Text("\(LunarCalendar.shortDate(entry.date)) · \(LunarCalendar.weekdayText(entry.date))")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(secondaryInk)
                }
                Spacer(minLength: 3)
                Text("赶集日记")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(vermilion)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(vermilion.opacity(0.10), in: Capsule())
            }

            HStack(alignment: .center, spacing: 9) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(names(0, short: false))
                        .font(.system(size: 24, weight: .heavy, design: .serif))
                        .foregroundColor(primaryInk)
                        .lineLimit(2)
                        .minimumScaleFactor(0.62)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("农历 \(LunarCalendar.lunarText(entry.date)) · \(LunarCalendar.ganzhiName(entry.date))日")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(secondaryInk)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)

                    HStack(spacing: 4) {
                        Circle().fill(vermilion).frame(width: 5, height: 5)
                        Text(entry.sections.first?.isEmpty == false ? "今日开圩 · 记得出发" : "今日暂无圩日")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(vermilion)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    EmptyView()
                        .frame(height: 42)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(alignment: .bottomLeading) {
                            Text("岭南乡野 · 圩日历")
                                .font(.system(size: 8, weight: .semibold))
                                .foregroundColor(Color(red: 0.12, green: 0.22, blue: 0.18))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color.white.opacity(0.72), in: Capsule())
                                .padding(5)
                        }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 6) {
                    forecastMiniCard(1)
                    forecastMiniCard(2)
                }
                .frame(width: 116)
            }
            .frame(maxHeight: .infinity, alignment: .center)
        }
        .padding(12)
        .background(alignment: .bottomTrailing) {
            Circle()
                .fill(vermilion.opacity(dark ? 0.08 : 0.06))
                .frame(width: 100, height: 100)
                .offset(x: 25, y: 28)
        }
        .clipped()
    }

    private func forecastMiniCard(_ index: Int) -> some View {
        HStack(spacing: 7) {
            RoundedRectangle(cornerRadius: 2)
                .fill(index == 1 ? vermilion : Color(red: 0.43, green: 0.60, blue: 0.33))
                .frame(width: 3, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(index == 1 ? "明日" : "后日")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(secondaryInk)
                Text(names(index, short: false))
                    .font(.system(size: 12, weight: .bold, design: .serif))
                    .foregroundColor(primaryInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                Text("\(numericDate(entry.days[index]))  \(LunarCalendar.weekdayText(entry.days[index]))")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(secondaryInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(dark ? Color.white.opacity(0.06) : Color.white.opacity(0.56),
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func forecastColumn(_ index: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(index == 1 ? "明日" : "后日")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(secondaryInk)
                .lineLimit(1)

            Text(names(index, short: false))
                .font(.system(size: 15, weight: .heavy, design: .serif))
                .foregroundColor(primaryInk)
                .lineLimit(2)
                .minimumScaleFactor(0.66)
                .fixedSize(horizontal: false, vertical: true)

            Text("（赶集）")
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(secondaryInk)
                .lineLimit(1)

            Spacer(minLength: 3)

            Text("农历\(LunarCalendar.lunarText(entry.days[index]))")
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(secondaryInk)
                .lineLimit(1)
                .minimumScaleFactor(0.66)
        }
        .padding(.horizontal, 7)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .combine)
    }

    private func dayCard(_ index: Int, compact: Bool = false) -> some View {
        let accent = index == 0 ? vermilion : Color(red: 0.24, green: 0.43, blue: 0.32)
        return VStack(alignment: .leading, spacing: compact ? 3 : 5) {
            Text(["今天", "明天", "后天"][index])
                .font(.system(size: compact ? 8 : 9, weight: .bold))
                .foregroundColor(index == 0 ? .white : primaryInk)
                .padding(.horizontal, compact ? 6 : 7)
                .padding(.vertical, compact ? 2 : 3)
                .background(index == 0 ? vermilion : (dark ? Color.white.opacity(0.10) : Color(red: 0.88, green: 0.91, blue: 0.79)), in: Capsule())
                .lineLimit(1)
            Text(numericDate(entry.days[index]))
                .font(.system(size: compact ? 12 : 15, weight: .heavy, design: .serif))
                .foregroundColor(primaryInk).lineLimit(1).minimumScaleFactor(0.65)
            Text(LunarCalendar.weekdayText(entry.days[index]))
                .font(.system(size: compact ? 8 : 9, weight: .medium)).foregroundColor(secondaryInk).lineLimit(1)
            if !compact { Spacer(minLength: 1) }
            Text(names(index, short: true))
                .font(.system(size: compact ? 9 : 13, weight: .heavy, design: .serif))
                .foregroundColor(accent).lineLimit(compact ? 2 : 1).minimumScaleFactor(0.55)
            if !compact {
                HStack(spacing: 3) {
                    Image(systemName: "basket.fill").font(.system(size: 8))
                    Text(index == 0 ? "今日开圩" : "圩日预告").font(.system(size: 8, weight: .medium))
                }.foregroundColor(secondaryInk).lineLimit(1)
            }
        }
        .padding(compact ? 6 : 8)
        .frame(maxWidth: .infinity, minHeight: compact ? 76 : 92, maxHeight: compact ? 82 : nil, alignment: .leading)
        .background(index == 0
            ? (dark ? Color(red: 0.35, green: 0.16, blue: 0.12).opacity(0.82) : Color(red: 1.0, green: 0.91, blue: 0.84).opacity(0.96))
            : (dark ? Color(red: 0.04, green: 0.17, blue: 0.19).opacity(0.86) : Color(red: 0.98, green: 0.98, blue: 0.90).opacity(0.91)),
            in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous)
            .stroke(index == 0 ? vermilion.opacity(dark ? 0.52 : 0.38) : (dark ? Color.white.opacity(0.12) : Color.white.opacity(0.60)), lineWidth: 0.7))
        .accessibilityElement(children: .combine)
    }

    private var largeLayout: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(vermilion)
                        Text("今日圩日")
                            .font(.system(size: 17, weight: .heavy, design: .serif))
                            .foregroundColor(primaryInk)
                    }
                    Text("\(LunarCalendar.shortDate(entry.date))  \(LunarCalendar.weekdayText(entry.date))")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(secondaryInk)
                    Text("农历 \(LunarCalendar.lunarText(entry.date)) · \(LunarCalendar.ganzhiName(entry.date))日")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(secondaryInk)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                Spacer(minLength: 0)
                Text("今日")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(ink)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Color(red: 0.84, green: 0.89, blue: 0.70), in: Capsule())
            }

            HStack(alignment: .center, spacing: 9) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(names(0, short: false))
                        .font(.system(size: 30, weight: .heavy, design: .serif))
                        .foregroundColor(primaryInk)
                        .lineLimit(2)
                        .minimumScaleFactor(0.62)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(entry.sections.first?.isEmpty == false ? "今天赶集 · 记得出发" : "今天暂无圩日")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(vermilion)
                }
                Spacer(minLength: 0)
                EmptyView()
                    .frame(width: 94, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .stroke(Color.white.opacity(dark ? 0.10 : 0.62), lineWidth: 0.8))
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
            .background(dark ? Color.black.opacity(0.14) : Color.white.opacity(0.45),
                        in: RoundedRectangle(cornerRadius: 15, style: .continuous))

            HStack(spacing: 7) {
                dayCard(0)
                dayCard(1)
                dayCard(2)
            }
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .padding(12)
    }



}

struct GanJiWidget: Widget {
    let kind = "GanJiWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MarketProvider()) { entry in
            // Apply this at the WidgetKit configuration boundary as well as in
            // the view body. WidgetKit's placeholder redaction can be injected
            // above the view's own layout hierarchy while the timeline is pending.
            GanJiWidgetView(entry: entry)
                .unredacted()
        }
        .configurationDisplayName("赶集日记 · 田园集市")
        .description("岭南乡土插画风，查看今日、明日与后日圩日及农历干支")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

@main struct GanJiWidgetBundle: WidgetBundle {
    var body: some Widget { GanJiWidget() }
}
