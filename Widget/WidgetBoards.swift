import SwiftUI

// 三个尺寸是三套不同的版面，不是同一张图缩放：
//   小号 = 印章  —— 一个朱砂方印压住今日日期
//   中号 = 刻度带 —— 未来七日横排，开圩日打点
//   大号 = 历书页 —— 七日逐行，带圩名与圩期规则

// MARK: - 小号：印章

struct SealBoard: View {
    let entry: GanJiEntry

    private var today: DayBoard? { entry.boards.first }
    private var markets: [MarketRule] { today?.markets ?? [] }

    private var dayNumber: String {
        let d = Calendar.current.component(.day, from: entry.date)
        return String(d)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 5) {
                SectionLabel(text: "今日")
                Text(LunarCalendar.weekdayText(entry.date))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Paper.inkSoft)
                Spacer(minLength: 0)
                if !markets.isEmpty {
                    Text("\(markets.count) 处")
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundStyle(Paper.vermilion)
                }
            }

            Spacer(minLength: 4)

            HStack(alignment: .top, spacing: 9) {
                // 朱砂印章：日期数字反白压在印面上
                ZStack {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(markets.isEmpty ? Paper.inkSoft.opacity(0.55) : Paper.vermilion)
                    Text(dayNumber)
                        .font(.system(size: 33, weight: .black, design: .serif))
                        .foregroundStyle(Paper.cream)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                }
                .frame(width: 52, height: 52)

                VStack(alignment: .leading, spacing: 3) {
                    Text(LunarCalendar.lunarText(entry.date))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Paper.ink)
                        .lineLimit(1)
                    Text(LunarCalendar.ganzhiName(entry.date) + "日")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Paper.inkSoft)
                }
                .padding(.top, 2)

                Spacer(minLength: 0)
            }

            Spacer(minLength: 5)

            HairLine()

            Spacer(minLength: 5)

            if markets.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text("今日休市")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Paper.ink)
                    if let next = nextMarketDay() {
                        Text("\(next.label) 起圩")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Paper.inkSoft)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(markets.prefix(2).indices), id: \.self) { index in
                        let rule = markets[index]
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Paper.vermilion.opacity(index == 0 ? 1 : 0.4))
                                .frame(width: 4, height: 4)
                            Text(rule.name)
                                .font(.system(size: index == 0 ? 13 : 11,
                                              weight: index == 0 ? .bold : .medium))
                                .foregroundStyle(index == 0 ? Paper.ink : Paper.inkSoft)
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                        }
                    }
                }
            }
        }
        .padding(13)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    /// 今天之后的第一个开圩日，给「今日休市」补一句有信息量的提示。
    private func nextMarketDay() -> (label: String, date: Date)? {
        for board in entry.boards.dropFirst() where !board.markets.isEmpty {
            let offset = Calendar.current.dateComponents(
                [.day], from: Calendar.current.startOfDay(for: entry.date),
                to: Calendar.current.startOfDay(for: board.date)
            ).day ?? 0
            let label = offset == 1 ? "明天" : LunarCalendar.weekdayText(board.date)
            return (label, board.date)
        }
        return nil
    }
}

// MARK: - 中号：七日刻度带

struct StripBoard: View {
    let entry: GanJiEntry

    private var today: [MarketRule] { entry.boards.first?.markets ?? [] }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(entry.region.isEmpty ? "赶集日记" : entry.region)
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(Paper.ink)
                    .lineLimit(1)
                Spacer(minLength: 0)
                SectionLabel(text: "未来七日")
            }
            .padding(.bottom, 9)

            HStack(alignment: .top, spacing: 0) {
                ForEach(entry.boards.prefix(7)) { board in
                    StripColumn(
                        board: board,
                        isToday: Calendar.current.isDateInToday(board.date)
                    )
                }
                if entry.boards.count < 7 {
                    ForEach(entry.boards.count..<7, id: \.self) { _ in
                        Spacer(minLength: 0)
                    }
                }
            }
            .frame(maxWidth: .infinity)

            Spacer(minLength: 6)

            HairLine()

            Spacer(minLength: 7)

            // 底部一行说清今天到底哪几处开圩 —— 刻度带只能表达「有没有」，名字放这里。
            HStack(spacing: 5) {
                Rectangle()
                    .fill(today.isEmpty ? Paper.inkSoft.opacity(0.5) : Paper.vermilion)
                    .frame(width: 3, height: 12)
                Text(todayLine)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(today.isEmpty ? Paper.inkSoft : Paper.ink)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
        }
        .padding(13)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var todayLine: String {
        if !entry.synced { return "打开 App 同步圩日" }
        if today.isEmpty { return "今日休市" }
        let names = today.prefix(3).map(\.name).joined(separator: " · ")
        return today.count > 3 ? names + " 等 \(today.count) 处" : names
    }
}

private struct StripColumn: View {
    let board: DayBoard
    let isToday: Bool

    private var weekday: String {
        let names = ["日", "一", "二", "三", "四", "五", "六"]
        let idx = Calendar.current.component(.weekday, from: board.date) - 1
        return "周" + names[min(max(idx, 0), 6)]
    }

    var body: some View {
        VStack(spacing: 5) {
            Text(weekday)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(isToday ? Paper.vermilion : Paper.inkSoft)
                .lineLimit(1)

            Text("\(Calendar.current.component(.day, from: board.date))")
                .font(.system(size: 15, weight: isToday ? .black : .semibold, design: .serif))
                .foregroundStyle(board.markets.isEmpty ? Paper.inkSoft.opacity(0.55) : Paper.ink)
                .lineLimit(1)

            // 开圩日实心点，休市日留一个空环，刻度感更清楚
            Group {
                if board.markets.isEmpty {
                    Circle()
                        .strokeBorder(Paper.rule.opacity(0.5), lineWidth: 1)
                        .frame(width: 5, height: 5)
                } else {
                    Circle()
                        .fill(isToday ? Paper.vermilion : Paper.jade)
                        .frame(width: 5, height: 5)
                }
            }
            .frame(height: 6)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 大号：历书页

struct AlmanacBoard: View {
    let entry: GanJiEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerForToday

            HairLine().padding(.vertical, 8)

            VStack(spacing: 0) {
                ForEach(entry.boards) { board in
                    AlmanacRow(board: board)
                    if board.id != entry.boards.last?.id {
                        Rectangle()
                            .fill(Paper.rule.opacity(0.20))
                            .frame(height: 1)
                            .padding(.leading, 34)
                    }
                }
            }

            Spacer(minLength: 0)

            footerNote
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var headerForToday: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(monthTitle)
                .font(.system(size: 16, weight: .heavy, design: .serif))
                .foregroundStyle(Paper.ink)
                .lineLimit(1)
                .fixedSize()
            Spacer(minLength: 4)
            Text("\(LunarCalendar.ganzhiName(entry.date)) · \(LunarCalendar.lunarText(entry.date))")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Paper.inkSoft)
                .lineLimit(1)
        }
    }

    private var monthTitle: String {
        let c = Calendar.current.dateComponents([.month, .day], from: entry.date)
        return "\(c.month ?? 1)月\(c.day ?? 1)日 · \(LunarCalendar.weekdayText(entry.date))"
    }

    private var footerNote: some View {
        HStack(spacing: 6) {
            Text(entry.region.isEmpty ? "赶集日记" : entry.region)
                .font(.system(size: 9, weight: .heavy))
                .tracking(1.2)
                .foregroundStyle(Paper.inkSoft)
                .lineLimit(1)
            Spacer(minLength: 4)
            if !entry.synced {
                Text("打开 App 同步")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Paper.vermilion)
            } else if entry.boards.allSatisfy({ $0.markets.isEmpty }) {
                Text("未来七日无圩")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Paper.inkSoft)
            } else {
                let total = entry.boards.reduce(0) { $0 + $1.markets.count }
                Text("七日 \(total) 场")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Paper.inkSoft)
            }
        }
        .padding(.top, 7)
    }
}

private struct AlmanacRow: View {
    let board: DayBoard

    private var isToday: Bool { Calendar.current.isDateInToday(board.date) }
    private var dayNumber: String { "\(Calendar.current.component(.day, from: board.date))" }

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Text(dayNumber)
                .font(.system(size: 17, weight: isToday ? .black : .semibold, design: .serif))
                .foregroundStyle(board.markets.isEmpty ? Paper.inkSoft.opacity(0.6) : Paper.ink)
                .frame(width: 24, alignment: .trailing)
                .lineLimit(1)

            VStack(alignment: .leading, spacing: 1) {
                Text(LunarCalendar.weekdayText(board.date))
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(isToday ? Paper.vermilion : Paper.inkSoft)
                Text(LunarCalendar.ganzhiName(board.date))
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(Paper.inkSoft.opacity(0.85))
            }
            .frame(width: 34, alignment: .leading)

            if board.markets.isEmpty {
                Text("休市")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Paper.inkSoft.opacity(0.7))
                Spacer(minLength: 0)
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text(namesLine)
                        .font(.system(size: 12, weight: isToday ? .bold : .medium))
                        .foregroundStyle(Paper.ink)
                        .lineLimit(1)
                    Text(rulesLine)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(Paper.inkSoft)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Text("\(board.markets.count)")
                    .font(.system(size: 11, weight: .bold, design: .serif))
                    .foregroundStyle(Paper.cream)
                    .frame(minWidth: 18)
                    .padding(.vertical, 2)
                    .background(
                        (isToday ? Paper.vermilion : Paper.jade).opacity(0.9),
                        in: RoundedRectangle(cornerRadius: 4, style: .continuous)
                    )
            }
        }
        .padding(.vertical, 4)
    }

    private var namesLine: String {
        board.markets.prefix(3).map(\.name).joined(separator: " · ")
    }

    private var rulesLine: String {
        let unique = Array(Set(board.markets.prefix(3).map { MarketSchedule.ruleText($0) })).sorted()
        return unique.joined(separator: " / ")
    }
}
