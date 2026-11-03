import SwiftUI

// 大卡片风：每张版面的主角都是「今天那张票」。
//   小号 = 一张票 —— 今天开圩的圩占满版面
//   中号 = 票 + 接下来 —— 主卡下方排「接下来去哪」
//   大号 = 票墙 —— 今天大卡 + 明后天小卡排开

// MARK: - 小号：一张票

struct SealBoard: View {
    let entry: GanJiEntry

    private var today: [MarketRule] { entry.boards.first?.markets ?? [] }
    private var dayNumber: String { "\(Calendar.current.component(.day, from: entry.date))" }
    private var weekday: String { LunarCalendar.weekdayText(entry.date) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(dayNumber)
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundStyle(Ink.title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                VStack(alignment: .leading, spacing: 0) {
                    Text(weekday)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Ink.title)
                    Text(LunarCalendar.lunarText(entry.date))
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(Ink.tertiary)
                        .lineLimit(1)
                }
                .padding(.leading, 3)
                Spacer(minLength: 0)
            }
            .padding(.bottom, 11)

            mainTicket

            Spacer(minLength: 7)

            DayMeter(boards: entry.boards)
        }
        .padding(13)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private var mainTicket: some View {
        if let first = today.first {
            TicketCard(
                title: first.name,
                subtitle: today.count == 1
                    ? "今天开圩"
                    : "今天开圩 · 另有 \(today.count - 1) 处",
                isOpen: true
            )
        } else if let next = nextMarketDay() {
            TicketCard(
                title: next.name,
                subtitle: "\(next.label)开圩 · 今天休",
                isOpen: false
            )
        } else {
            TicketCard(title: "七日内无圩", subtitle: "收藏的圩都还没排到", isOpen: false)
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

// MARK: - 中号：主卡 + 接下来

struct StripBoard: View {
    let entry: GanJiEntry

    private var today: [MarketRule] { entry.boards.first?.markets ?? [] }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                mainColumn
                Spacer(minLength: 10)
                upNextColumn
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Spacer(minLength: 8)
            DayMeter(boards: entry.boards)
                .padding(.bottom, 2)
        }
        .padding(13)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var mainColumn: some View {
        VStack(alignment: .leading, spacing: 7) {
            if let first = today.first {
                TicketCard(
                    title: first.name,
                    subtitle: today.count == 1 ? "今天" : "今天 · \(today.count) 场",
                    isOpen: true
                )
                .frame(width: 148)
            } else if let next = nextMarketDay() {
                TicketCard(title: next.name, subtitle: "今天休 · \(next.label)去这", isOpen: false)
                    .frame(width: 148)
            } else {
                TicketCard(title: "七日无圩", subtitle: "今天休", isOpen: false)
                    .frame(width: 148)
            }
        }
    }

    /// 右列：接下来两天，纯文字，紧凑。
    @ViewBuilder
    private var upNextColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionLabel(text: "接下来")
                .padding(.bottom, 6)
            let next = Array(entry.boards.dropFirst().prefix(2))
            ForEach(Array(next.enumerated()), id: \.offset) { index, board in
                UpNextRow(board: board)
                if index < next.count - 1 {
                    HairLine().padding(.vertical, 5)
                }
            }
            Spacer(minLength: 0)
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

private struct UpNextRow: View {
    let board: DayBoard

    private var label: String {
        let offset = Calendar.current.dateComponents(
            [.day], from: Calendar.current.startOfDay(for: Date()),
            to: Calendar.current.startOfDay(for: board.date)
        ).day ?? 0
        return offset == 1 ? "明天" : LunarCalendar.weekdayText(board.date)
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(label)
                .font(.system(size: 10, weight: .heavy))
                .foregroundStyle(Ink.secondary)
                .frame(width: 26, alignment: .leading)
            if board.markets.isEmpty {
                Text("休")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Ink.tertiary)
            } else {
                Text(board.markets.prefix(2).map(\.name).joined(separator: " "))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Ink.title)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            Spacer(minLength: 0)
        }
    }
}

// MARK: - 大号：票墙

struct AlmanacBoard: View {
    let entry: GanJiEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(headerDate)
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(Ink.title)
                Spacer(minLength: 0)
                Text("收藏 \(entry.favoriteCount) 处")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Ink.secondary)
            }
            .padding(.bottom, 9)

            todayTicket
                .padding(.bottom, 8)

            HStack(spacing: 8) {
                SectionLabel(text: "接下来七天")
                Spacer(minLength: 0)
                DayMeter(boards: entry.boards)
                    .frame(width: 120)
            }
            .padding(.bottom, 7)

            VStack(spacing: 10) {
                ForEach(Array(entry.boards.dropFirst().prefix(5).enumerated()), id: \.offset) { _, board in
                    NextDayRow(board: board)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var headerDate: String {
        let c = Calendar.current.dateComponents([.month, .day], from: entry.date)
        return "\(c.month ?? 1)月\(c.day ?? 1)日 " + LunarCalendar.weekdayText(entry.date)
    }

    @ViewBuilder
    private var todayTicket: some View {
        let today = entry.boards.first?.markets ?? []
        if let first = today.first {
            ZStack(alignment: .leading) {
                TicketCard(
                    title: first.name,
                    subtitle: today.count == 1 ? "今天开圩" : "今天开圩 · 共 \(today.count) 场",
                    isOpen: true
                )
                // 剩余的圩名收进卡片右侧，小字竖排
                VStack(alignment: .trailing, spacing: 2) {
                    ForEach(Array(today.dropFirst().prefix(3).enumerated()), id: \.offset) { _, m in
                        Text(m.name)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(Ink.onTicket.opacity(0.85))
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, 13)
            }
        } else if let next = nextMarketDay() {
            TicketCard(title: next.name, subtitle: "今天休 · \(next.label)开圩", isOpen: false)
        } else {
            TicketCard(title: "七日内无圩", subtitle: "收藏的圩都还没排到", isOpen: false)
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

/// 大号里「明天/后天…」的一行：左边日期徽章，右边圩名。
private struct NextDayRow: View {
    let board: DayBoard

    private var label: String {
        let offset = Calendar.current.dateComponents(
            [.day], from: Calendar.current.startOfDay(for: Date()),
            to: Calendar.current.startOfDay(for: board.date)
        ).day ?? 0
        return offset == 1 ? "明" : (offset == 2 ? "后" : LunarCalendar.weekdayText(board.date))
    }

    var body: some View {
        HStack(spacing: 9) {
            Text(label)
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundStyle(board.markets.isEmpty ? Ink.tertiary : Ink.ticket)
                .frame(width: 22, height: 22)
                .background(
                    Circle().fill((board.markets.isEmpty ? Ink.tertiary : Ink.ticket).opacity(0.12))
                )
            if board.markets.isEmpty {
                Text("休")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Ink.tertiary)
                Spacer(minLength: 0)
            } else {
                Text(board.markets.map(\.name).prefix(3).joined(separator: " · "))
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Ink.title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Spacer(minLength: 4)
                Text("\(board.markets.count)")
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .foregroundStyle(Ink.secondary)
            }
        }
    }
}
