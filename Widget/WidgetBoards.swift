import SwiftUI

// 三个尺寸是三套版面：
//   小号 = 日历牌  —— 大号日期 + 今日圩名
//   中号 = 左今日右七日 —— 左侧今日详情，右侧七日刻度
//   大号 = 历书页  —— 七日逐行

// MARK: - 小号：日历牌

struct SealBoard: View {
    let entry: GanJiEntry

    private var markets: [MarketRule] { entry.boards.first?.markets ?? [] }
    private var dayNumber: String { "\(Calendar.current.component(.day, from: entry.date))" }
    private var monthNumber: String { "\(Calendar.current.component(.month, from: entry.date))" }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                SectionLabel(text: "今日")
                Spacer(minLength: 0)
                Text(LunarCalendar.weekdayText(entry.date))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Paper.inkSoft)
            }

            Spacer(minLength: 6)

            // 日期主体：巨大数字，月份作为上标跟在旁边
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(dayNumber)
                    .font(.system(size: 46, weight: .black, design: .serif))
                    .foregroundStyle(Paper.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text("\(monthNumber)月")
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(Paper.inkSoft)
                Spacer(minLength: 0)
            }

            Text("\(LunarCalendar.lunarText(entry.date)) · \(LunarCalendar.ganzhiName(entry.date))")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Paper.inkSoft)
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            Spacer(minLength: 8)

            HairLine()

            Spacer(minLength: 7)

            marketSection
        }
        .padding(13)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private var marketSection: some View {
        if markets.isEmpty {
            HStack(spacing: 5) {
                VermilionTick(height: 9).opacity(0.35)
                Text("今休")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Paper.ink)
                Spacer(minLength: 0)
            }
            if let next = nextMarketDay() {
                Text("\(next.label) \(next.name)")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Paper.inkSoft)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .padding(.top, 3)
            }
        } else {
            VStack(alignment: .leading, spacing: 3) {
                ForEach(Array(markets.prefix(2).indices), id: \.self) { index in
                    HStack(spacing: 5) {
                        VermilionTick(height: 9)
                            .opacity(index == 0 ? 1 : 0.35)
                        Text(markets[index].name)
                            .font(.system(size: index == 0 ? 12.5 : 11,
                                          weight: index == 0 ? .bold : .medium))
                            .foregroundStyle(index == 0 ? Paper.ink : Paper.inkSoft)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
                if markets.count > 2 {
                    Text("另有 \(markets.count - 2) 处")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(Paper.inkSoft.opacity(0.75))
                        .padding(.leading, 8)
                }
            }
        }
    }

    private func nextMarketDay() -> (label: String, name: String)? {
        for board in entry.boards.dropFirst() where !board.markets.isEmpty {
            let offset = Calendar.current.dateComponents(
                [.day], from: Calendar.current.startOfDay(for: entry.date),
                to: Calendar.current.startOfDay(for: board.date)
            ).day ?? 0
            let label = offset == 1 ? "明天" : LunarCalendar.weekdayText(board.date)
            return (label, board.markets[0].name)
        }
        return nil
    }
}

// MARK: - 中号：左今日 · 右七日

struct StripBoard: View {
    let entry: GanJiEntry

    private var today: [MarketRule] { entry.boards.first?.markets ?? [] }
    private var dayNumber: String { "\(Calendar.current.component(.day, from: entry.date))" }

    var body: some View {
        HStack(alignment: .top, spacing: 13) {
            todayColumn
                .frame(width: 96, alignment: .leading)

            Rectangle()
                .fill(Paper.rule)
                .frame(width: 1)

            weekColumn
        }
        .padding(13)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var todayColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                SectionLabel(text: "今日")
                Text(LunarCalendar.weekdayText(entry.date))
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Paper.inkSoft)
                Spacer(minLength: 0)
            }

            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(dayNumber)
                    .font(.system(size: 30, weight: .black, design: .serif))
                    .foregroundStyle(Paper.ink)
                    .lineLimit(1)
                Text(LunarCalendar.lunarText(entry.date))
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Paper.inkSoft)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 0)
            }
            .padding(.top, 1)

            Spacer(minLength: 4)

            if today.isEmpty {
                Text("收藏的圩今休")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Paper.inkSoft)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(today.prefix(2).indices), id: \.self) { i in
                        HStack(spacing: 4) {
                            VermilionTick(height: 8)
                                .opacity(i == 0 ? 1 : 0.35)
                            Text(today[i].name)
                                .font(.system(size: i == 0 ? 11 : 10, weight: i == 0 ? .bold : .medium))
                                .foregroundStyle(i == 0 ? Paper.ink : Paper.inkSoft)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                    }
                    if today.count > 2 {
                        Text("另有 \(today.count - 2) 处")
                            .font(.system(size: 8.5, weight: .medium))
                            .foregroundStyle(Paper.inkSoft.opacity(0.75))
                            .padding(.leading, 7)
                    }
                }
            }

            Spacer(minLength: 0)
        }
    }

    private var weekColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                SectionLabel(text: "未来七日")
                Spacer(minLength: 0)
                Text("收藏 \(entry.favoriteCount) 处")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Paper.inkSoft)
            }
            .padding(.bottom, 7)

            HStack(alignment: .top, spacing: 0) {
                ForEach(entry.boards.prefix(7)) { board in
                    StripColumn(board: board, isToday: Calendar.current.isDateInToday(board.date))
                }
                if entry.boards.count < 7 {
                    ForEach(entry.boards.count..<7, id: \.self) { _ in
                        Spacer(minLength: 0)
                    }
                }
            }

            Spacer(minLength: 0)
        }
    }
}

private struct StripColumn: View {
    let board: DayBoard
    let isToday: Bool

    private var weekday: String {
        let names = ["日", "一", "二", "三", "四", "五", "六"]
        let idx = Calendar.current.component(.weekday, from: board.date) - 1
        return names[min(max(idx, 0), 6)]
    }

    var body: some View {
        VStack(spacing: 4) {
            Text(weekday)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(isToday ? Paper.vermilion : Paper.inkSoft)
                .lineLimit(1)

            Text("\(Calendar.current.component(.day, from: board.date))")
                .font(.system(size: 14, weight: isToday ? .black : .medium, design: .serif))
                .foregroundStyle(board.markets.isEmpty ? Paper.inkSoft.opacity(0.5) : Paper.ink)
                .lineLimit(1)

            // 开圩实心、休市留白，形成刻度节奏
            Group {
                if board.markets.isEmpty {
                    Circle().fill(Paper.rule).frame(width: 4, height: 4)
                } else {
                    Circle()
                        .fill(isToday ? Paper.vermilion : Paper.jade)
                        .frame(width: 5, height: 5)
                }
            }
            .frame(height: 5)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 大号：历书页

struct AlmanacBoard: View {
    let entry: GanJiEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            HairLine().padding(.top, 9).padding(.bottom, 2)

            // 七日平摊剩余高度，避免末行与页脚之间留出大片空白。
            VStack(spacing: 0) {
                ForEach(Array(entry.boards.enumerated()), id: \.element.id) { index, board in
                    AlmanacRow(board: board)
                    if index < entry.boards.count - 1 {
                        Rectangle()
                            .fill(Paper.rule.opacity(0.55))
                            .frame(height: 1)
                            .padding(.leading, 43)
                    }
                }
            }
            .frame(maxHeight: .infinity)

            footer
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 7) {
            Text(monthTitle)
                .font(.system(size: 15, weight: .heavy, design: .serif))
                .foregroundStyle(Paper.ink)
                .lineLimit(1)
                .fixedSize()
            Spacer(minLength: 4)
            Text("\(LunarCalendar.ganzhiName(entry.date)) · \(LunarCalendar.lunarText(entry.date))")
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(Paper.inkSoft)
                .lineLimit(1)
        }
    }

    private var monthTitle: String {
        let c = Calendar.current.dateComponents([.month, .day], from: entry.date)
        return "\(c.month ?? 1)月\(c.day ?? 1)日"
    }

    private var footer: some View {
        HStack(spacing: 5) {
            SectionLabel(text: "收藏 \(entry.favoriteCount) 处", size: 9)
            Spacer(minLength: 4)
            if entry.boards.allSatisfy({ $0.markets.isEmpty }) {
                Text("七日内无开圩")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Paper.inkSoft)
            } else {
                let total = entry.boards.reduce(0) { $0 + $1.markets.count }
                Text("七日开 \(total) 场")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Paper.inkSoft)
            }
        }
        .padding(.top, 6)
    }
}

private struct AlmanacRow: View {
    let board: DayBoard

    private var isToday: Bool { Calendar.current.isDateInToday(board.date) }
    private var weekday: String { LunarCalendar.weekdayText(board.date).replacingOccurrences(of: "周", with: "") }

    var body: some View {
        HStack(alignment: .center, spacing: 9) {
            // 日期块：数字 + 星期，今天用朱砂点标出
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text("\(Calendar.current.component(.day, from: board.date))")
                    .font(.system(size: 16, weight: isToday ? .black : .semibold, design: .serif))
                    .foregroundStyle(board.markets.isEmpty ? Paper.inkSoft.opacity(0.55) : Paper.ink)
                    .frame(minWidth: 17, alignment: .trailing)
                    .lineLimit(1)
                Text(weekday)
                    .font(.system(size: 8.5, weight: .semibold))
                    .foregroundStyle(isToday ? Paper.vermilion : Paper.inkSoft)
            }
            .frame(width: 40, alignment: .leading)

            if board.markets.isEmpty {
                Text("休")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Paper.inkSoft.opacity(0.6))
                Spacer(minLength: 0)
            } else {
                VStack(alignment: .leading, spacing: 1) {
                    Text(namesLine)
                        .font(.system(size: 11.5, weight: isToday ? .bold : .medium))
                        .foregroundStyle(Paper.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.9)
                    if !rulesLine.isEmpty {
                        Text(rulesLine)
                            .font(.system(size: 8.5, weight: .medium))
                            .foregroundStyle(Paper.inkSoft.opacity(0.9))
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 3)
                Text("\(board.markets.count)")
                    .font(.system(size: 10, weight: .heavy, design: .serif))
                    .foregroundStyle(isToday ? Paper.cream : Paper.jade)
                    .frame(minWidth: 15, minHeight: 15)
                    .background(
                        isToday ? Paper.vermilion : Paper.jade.opacity(0.14),
                        in: RoundedRectangle(cornerRadius: 3, style: .continuous)
                    )
            }
        }
        .padding(.vertical, 5.5)
    }

    private var namesLine: String {
        board.markets.prefix(3).map(\.name).joined(separator: " · ")
    }

    private var rulesLine: String {
        let unique = Array(Set(board.markets.prefix(3).map { MarketSchedule.ruleText($0) })).sorted()
        return unique.joined(separator: " / ")
    }
}
