import SwiftUI

private enum CalendarCopy {
    static func day(_ date: Date) -> String { String(Calendar.current.component(.day, from: date)) }
    static func month(_ date: Date) -> String { "\(Calendar.current.component(.month, from: date))月" }
    static func date(_ date: Date) -> String { "\(month(date))\(day(date))日" }
    static func names(_ markets: [MarketRule], limit: Int = 2) -> String {
        guard !markets.isEmpty else { return "收藏的圩点今日休圩" }
        let text = markets.prefix(limit).map(\.widgetDisplayName).joined(separator: " · ")
        return markets.count > limit ? text + " 等\(markets.count)处" : text
    }
    static func accessibility(_ board: DayBoard, label: String) -> String {
        "\(label)，\(date(board.date))，\(LunarCalendar.weekdayText(board.date))，" +
        (board.markets.isEmpty ? "收藏的圩点休圩" : "开圩：" + board.markets.map(\.widgetDisplayName).joined(separator: "、"))
    }
}

/// Both settings and the extension use this content, including identical empty states.
/// Background rendering stays with each host so editable photo crops remain unchanged.
struct WidgetBoardContent: View {
    let entry: GanJiEntry
    let size: WidgetPhotoSize

    var body: some View {
        Group {
            if entry.boards.isEmpty || entry.favoriteCount == 0 {
                EmptyBoard(entry: entry)
            } else {
                switch size {
                case .small: SealBoard(entry: entry)
                case .medium: StripBoard(entry: entry)
                case .large: AlmanacBoard(entry: entry)
                }
            }
        }
    }
}

struct EmptyBoard: View {
    let entry: GanJiEntry

    private var title: String { entry.synced ? "还没有收藏" : "尚未同步" }
    private var detail: String {
        entry.synced ? "点心形收藏圩点，开圩就会出现在这里"
                     : "打开「赶集日记」选一次地区即可同步"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            WidgetIdentity()
            Spacer(minLength: 8)
            Image(systemName: "heart").font(.system(size: 24, weight: .light))
            Text(title).font(.system(size: 17, weight: .semibold))
            Text(detail).font(.system(size: 11, weight: .medium))
                .opacity(0.8).lineLimit(3)
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

struct SealBoard: View {
    let entry: GanJiEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(CalendarCopy.month(entry.date)).font(.system(size: 12, weight: .semibold))
                Spacer(minLength: 2)
                Text(LunarCalendar.weekdayText(entry.date)).font(.system(size: 11, weight: .medium))
            }.opacity(0.85)
            Text(CalendarCopy.day(entry.date))
                .font(.system(size: 38, weight: .light, design: .rounded))
                .monospacedDigit().lineLimit(1)
            Text("农历" + LunarCalendar.lunarText(entry.date))
                .font(.system(size: 10, weight: .medium)).opacity(0.8).lineLimit(1)
            Spacer(minLength: 4)
            HStack(spacing: 5) {
                Circle().fill(Color.white).frame(width: 4, height: 4)
                Text(entry.today.isEmpty ? "今日休圩" : "今日开圩 · \(entry.today.count)处")
                    .font(.system(size: 10, weight: .semibold))
            }
            Text(summary)
                .font(.system(size: 12, weight: .semibold)).lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(15).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibility)
    }
    private var summary: String {
        if !entry.today.isEmpty { return CalendarCopy.names(entry.today, limit: 1) }
        if let next = entry.boards.dropFirst().first(where: { !$0.markets.isEmpty }) {
            return "\(CalendarCopy.date(next.date)) · \(next.markets.first?.widgetDisplayName ?? "")"
        }
        return "未来七天暂无安排"
    }
    private var accessibility: String {
        guard let board = entry.boards.first else { return "暂无圩日信息" }
        return CalendarCopy.accessibility(board, label: "今天") + "，农历" + LunarCalendar.lunarText(entry.date)
            + (entry.today.isEmpty ? "，" + summary : "")
    }
}

struct StripBoard: View {
    let entry: GanJiEntry
    var body: some View {
        GeometryReader { geometry in
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    WidgetIdentity()
                    HStack(alignment: .firstTextBaseline, spacing: 5) {
                        Text(CalendarCopy.day(entry.date)).font(.system(size: 34, weight: .light, design: .rounded))
                        Text(CalendarCopy.month(entry.date)).font(.system(size: 12, weight: .medium))
                    }
                    Text(LunarCalendar.weekdayText(entry.date) + " · " + LunarCalendar.lunarText(entry.date))
                        .font(.system(size: 10, weight: .medium)).opacity(0.8).lineLimit(1)
                    Spacer(minLength: 2)
                    Text(entry.today.isEmpty ? "今日休圩" : "今日开圩")
                        .font(.system(size: 10, weight: .medium)).opacity(0.8)
                    Text(CalendarCopy.names(entry.today, limit: 1))
                        .font(.system(size: 13, weight: .semibold)).lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(width: max(100, (geometry.size.width - 46) * 0.49), alignment: .leading)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(entry.boards.first.map { CalendarCopy.accessibility($0, label: "今天") } ?? "暂无信息")
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(entry.boards.dropFirst().prefix(2).enumerated()), id: \.element.id) { index, board in
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Text(index == 0 ? "明天" : "后天").font(.system(size: 10, weight: .semibold))
                                Spacer(minLength: 2)
                                Text(CalendarCopy.date(board.date)).font(.system(size: 9)).opacity(0.7)
                            }
                            Text(board.markets.isEmpty ? "休圩" : CalendarCopy.names(board.markets, limit: 1))
                                .font(.system(size: 12, weight: .semibold)).lineLimit(2)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(CalendarCopy.accessibility(board, label: index == 0 ? "明天" : "后天"))
                        if index == 0 { Rectangle().fill(Color.white.opacity(0.18)).frame(height: 0.5) }
                    }
                }.padding(11).background(PhotoPanel())
            }
            .padding(16)
        }
    }
}

struct AlmanacBoard: View {
    let entry: GanJiEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 7) {
                    WidgetIdentity()
                    Text("把日子，过成风景。")
                        .font(.system(size: 17, weight: .medium, design: .serif))
                }
                Spacer(minLength: 4)
                VStack(alignment: .trailing, spacing: 0) {
                    Text(CalendarCopy.day(entry.date))
                        .font(.system(size: 47, weight: .light, design: .rounded))
                    Text(CalendarCopy.month(entry.date) + " · " + LunarCalendar.weekdayText(entry.date))
                        .font(.system(size: 10, weight: .medium)).opacity(0.8)
                }
            }
            Text("农历" + LunarCalendar.lunarText(entry.date) + "  ·  " + LunarCalendar.ganzhiName(entry.date) + "日")
                .font(.system(size: 11, weight: .medium)).opacity(0.8).lineLimit(1)
            Spacer(minLength: 0)
            VStack(spacing: 0) {
                ForEach(Array(entry.boards.prefix(3).enumerated()), id: \.element.id) { index, board in
                    HStack(alignment: .center, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(["今天", "明天", "后天"][index])
                                .font(.system(size: 12, weight: .semibold))
                            Text(CalendarCopy.date(board.date)).font(.system(size: 10)).opacity(0.65)
                        }.frame(width: 44, alignment: .leading)
                        Rectangle().fill(Color.white.opacity(0.2)).frame(width: 1, height: 27)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(board.markets.isEmpty ? "休圩 · 留一点闲暇" : CalendarCopy.names(board.markets, limit: 3))
                                .font(.system(size: 14, weight: .semibold)).lineLimit(2)
                            if !board.markets.isEmpty {
                                Text("\(board.markets.count)处收藏圩点开圩")
                                    .font(.system(size: 10)).opacity(0.7)
                            }
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.vertical, 10)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(CalendarCopy.accessibility(board, label: ["今天", "明天", "后天"][index]))
                    if index < 2 { Rectangle().fill(Color.white.opacity(0.12)).frame(height: 0.5) }
                }
            }.padding(.horizontal, 13).background(PhotoPanel())
        }.padding(20).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
