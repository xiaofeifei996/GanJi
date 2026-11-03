import SwiftUI

// 三个尺寸是三套版面。核心信息是「收藏的圩」：
//   小号 = 今日一览 —— 今天日期 + 今天开圩的收藏圩
//   中号 = 收藏的圩 · 七日分布 —— 每个收藏圩一行，圆点标出哪天开
//   大号 = 七日历 + 收藏圩 —— 上半七日历，下半收藏圩今天/最近开圩

// MARK: - 小号：今日一览

struct SealBoard: View {
    let entry: GanJiEntry

    private var markets: [MarketRule] { entry.boards.first?.markets ?? [] }
    private var dayNumber: String { "\(Calendar.current.component(.day, from: entry.date))" }
    private var weekday: String { LunarCalendar.weekdayText(entry.date) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 5) {
                SectionLabel(text: "赶集历")
                Spacer(minLength: 0)
                Text("\(monthDayText) \(weekday)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Ink.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }

            Spacer(minLength: 6)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(dayNumber)
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(Ink.title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(LunarCalendar.lunarText(entry.date))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Ink.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 0)
            }

            Spacer(minLength: 6)

            marketSection
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var monthDayText: String {
        let c = Calendar.current.dateComponents([.month, .day], from: entry.date)
        return "\(c.month ?? 1)月"
    }

    @ViewBuilder
    private var marketSection: some View {
        if markets.isEmpty {
            HStack(spacing: 6) {
                Image(systemName: "moon.zzz.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Ink.tertiary)
                Text("今日无圩")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Ink.secondary)
                Spacer(minLength: 0)
            }
            if let next = nextMarketDay() {
                Text("\(next.label) · \(next.name)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Ink.tertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .padding(.top, 3)
            }
        } else {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(markets.prefix(2).indices), id: \.self) { index in
                    HStack(spacing: 5) {
                        Circle()
                            .fill(Ink.blue)
                            .frame(width: index == 0 ? 5 : 4,
                                   height: index == 0 ? 5 : 4)
                        Text(markets[index].name)
                            .font(.system(size: index == 0 ? 12.5 : 11,
                                          weight: index == 0 ? .semibold : .regular))
                            .foregroundStyle(index == 0 ? Ink.title : Ink.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
                if markets.count > 2 {
                    Text("另有 \(markets.count - 2) 处")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(Ink.tertiary)
                        .padding(.leading, 10)
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

// MARK: - 中号：收藏的圩 · 七日分布

/// 每个收藏圩一行：圩名在左，七个圆点表示未来七天哪天开。
/// 这版版面直接回答「我收藏的这几个圩，最近哪天去哪家」。
struct StripBoard: View {
    let entry: GanJiEntry

    private var favoriteRules: [MarketRule] {
        var seen = Set<String>()
        return entry.boards.flatMap(\.markets).filter { seen.insert($0.id).inserted }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                SectionLabel(text: "收藏的圩 · 未来七日")
                Spacer(minLength: 0)
                Text("收藏 \(entry.favoriteCount) 处")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Ink.tertiary)
            }
            .padding(.bottom, 8)

            weekHeader

            VStack(spacing: 0) {
                let rows = Array(favoriteRules.prefix(3).enumerated())
                ForEach(rows, id: \.element.id) { index, rule in
                    MarketDotRow(rule: rule,
                                 entry: entry,
                                 dim: index >= 2 && favoriteRules.count > 3)
                    if index < rows.count - 1 {
                        HairLine().padding(.leading, 4)
                    }
                }
                if favoriteRules.count > 3 {
                    Text("另有 \(favoriteRules.count - 3) 处收藏圩")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(Ink.tertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 4)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var weekHeader: some View {
        HStack(spacing: 0) {
            Text("")
                .frame(width: 76, alignment: .leading)
            ForEach(entry.boards.prefix(7)) { board in
                let isToday = Calendar.current.isDateInToday(board.date)
                VStack(spacing: 1) {
                    Text(weekdayShort(board.date))
                        .font(.system(size: 9, weight: isToday ? .bold : .medium))
                        .foregroundStyle(isToday ? Ink.blue : Ink.tertiary)
                    Text("\(Calendar.current.component(.day, from: board.date))")
                        .font(.system(size: 10, weight: isToday ? .bold : .medium, design: .rounded))
                        .foregroundStyle(isToday ? Ink.blue : Ink.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.bottom, 6)
    }

    private func weekdayShort(_ date: Date) -> String {
        let names = ["日", "一", "二", "三", "四", "五", "六"]
        let idx = Calendar.current.component(.weekday, from: date) - 1
        return names[min(max(idx, 0), 6)]
    }
}

private struct MarketDotRow: View {
    let rule: MarketRule
    let entry: GanJiEntry
    let dim: Bool

    var body: some View {
        HStack(spacing: 0) {
            Text(rule.name)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(dim ? Ink.secondary : Ink.title)
                .lineLimit(1)
                .frame(width: 76, alignment: .leading)
            ForEach(entry.boards.prefix(7)) { board in
                let opens = board.markets.contains { $0.id == rule.id }
                let isToday = Calendar.current.isDateInToday(board.date)
                ZStack {
                    if opens {
                        Circle()
                            .fill(isToday ? Ink.blue : Ink.blue.opacity(0.45))
                            .frame(width: 6, height: 6)
                    } else {
                        Circle()
                            .fill(Ink.separator.opacity(0.5))
                            .frame(width: 3, height: 3)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 22)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - 大号：七日历 + 收藏圩

struct AlmanacBoard: View {
    let entry: GanJiEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            weekStrip
            HairLine().padding(.vertical, 9)
            favoritesSection
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("\(Calendar.current.component(.month, from: entry.date))月")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(Ink.title)
            SectionLabel(text: "未来七日")
            Spacer(minLength: 0)
            Text("收藏 \(entry.favoriteCount) 处")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Ink.tertiary)
        }
        .padding(.bottom, 8)
    }

    /// 七日历：横排日期格，开圩日下面挂蓝点。
    private var weekStrip: some View {
        HStack(spacing: 0) {
            ForEach(entry.boards.prefix(7)) { board in
                WeekCell(board: board, isToday: Calendar.current.isDateInToday(board.date))
            }
        }
        .padding(.vertical, 8)
        .background(Card(corner: 11))
    }

    /// 下方列出每个收藏圩 + 它的下一个开圩日。
    @ViewBuilder
    private var favoritesSection: some View {
        let rows = nextOpeningRows()
        if rows.isEmpty {
            Text("收藏的圩七日内无开圩")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Ink.tertiary)
        } else {
            VStack(spacing: 0) {
                ForEach(Array(rows.prefix(4).enumerated()), id: \.element.rule.id) { index, row in
                    FavoriteRow(row: row)
                    if index < min(rows.count, 4) - 1 {
                        HairLine()
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func nextOpeningRows() -> [(rule: MarketRule, date: Date?, daysAhead: Int?)] {
        var seen = Set<String>()
        var rows = [(rule: MarketRule, date: Date?, daysAhead: Int?)]()
        for board in entry.boards {
            for market in board.markets where seen.insert(market.id).inserted {
                let offset = Calendar.current.dateComponents(
                    [.day],
                    from: Calendar.current.startOfDay(for: entry.date),
                    to: Calendar.current.startOfDay(for: board.date)
                ).day
                rows.append((market, board.date, offset))
            }
        }
        // 没在七日内开圩的收藏也补进来，日期为空
        if let feed = WidgetFeed.current() {
            for rule in feed.rules where !seen.contains(rule.id) {
                rows.append((rule, nil, nil))
            }
        }
        return rows
    }
}

private struct WeekCell: View {
    let board: DayBoard
    let isToday: Bool

    var body: some View {
        VStack(spacing: 3) {
            Text(weekdayShort)
                .font(.system(size: 9, weight: isToday ? .bold : .medium))
                .foregroundStyle(isToday ? Ink.blue : Ink.tertiary)
            Text("\(Calendar.current.component(.day, from: board.date))")
                .font(.system(size: 15, weight: isToday ? .bold : .medium, design: .rounded))
                .foregroundStyle(isToday ? Ink.blue : Ink.title)
            ZStack {
                if board.markets.isEmpty {
                    Circle().fill(Ink.separator.opacity(0.6)).frame(width: 3, height: 3)
                } else {
                    BlueDot().frame(width: 5, height: 5)
                }
            }
            .frame(height: 6)
        }
        .frame(maxWidth: .infinity)
    }

    private var weekdayShort: String {
        let names = ["日", "一", "二", "三", "四", "五", "六"]
        let idx = Calendar.current.component(.weekday, from: board.date) - 1
        return names[min(max(idx, 0), 6)]
    }
}

private struct FavoriteRow: View {
    let row: (rule: MarketRule, date: Date?, daysAhead: Int?)

    var body: some View {
        HStack(spacing: 8) {
            Circle().fill(row.date == nil ? Ink.tertiary : Ink.blue)
                .frame(width: 5, height: 5)
            Text(row.rule.name)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(row.date == nil ? Ink.secondary : Ink.title)
                .lineLimit(1)
            Spacer(minLength: 4)
            if let date = row.date, let ahead = row.daysAhead {
                Text(ahead == 0 ? "今天" : (ahead == 1 ? "明天" : shortDate(date)))
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Ink.blue)
                    .lineLimit(1)
            } else {
                Text("七日外")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Ink.tertiary)
            }
        }
        .padding(.vertical, 5)
    }

    private func shortDate(_ date: Date) -> String {
        let c = Calendar.current.dateComponents([.month, .day], from: date)
        return "\(c.month ?? 1)/\(c.day ?? 1)"
    }
}
