import SwiftUI

// 票根对切风：每个版面都是一张「撕开的票」。
//   小号 = 单张票 —— 左存根（日期）｜右主票（圩名）
//   中号 = 主票 + 三张票根联 —— 今天的票 + 明后天的存根联
//   大号 = 整版票据 —— 一张大票 + 七张日票排成两行

// MARK: - 票面通用组件

/// 左存根：竖排日期数字，票据左半。
struct StubDate: View {
    let entry: GanJiEntry
    var daySize: CGFloat = 30

    var body: some View {
        VStack(alignment: .center, spacing: 1) {
            Text("\(Calendar.current.component(.month, from: entry.date))月")
                .font(.system(size: 8, weight: .black))
                .tracking(1)
                .foregroundStyle(Ink.stamp)
            Text("\(Calendar.current.component(.day, from: entry.date))")
                .font(.system(size: daySize, weight: .black, design: .serif))
                .foregroundStyle(Ink.title)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(LunarCalendar.weekdayText(entry.date))
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(Ink.secondary)
        }
    }
}

/// 打孔分隔：上下两个半圆缺口 + 中间一列孔点。
struct Perforation: View {
    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            PunchLine()
            Spacer(minLength: 0)
        }
        .frame(width: 14)
    }
}

// MARK: - 小号：单张票

struct SealBoard: View {
    let entry: GanJiEntry

    private var today: [MarketRule] { entry.boards.first?.markets ?? [] }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                SectionLabel(text: "赶集历")
                Spacer(minLength: 0)
                Postmark(text: "圩", size: 22)
                    .offset(y: -2)
            }
            .padding(.top, 11)
            .padding(.horizontal, 12)

            Spacer(minLength: 3)

            HStack(spacing: 0) {
                // 左：日期存根
                StubDate(entry: entry)
                    .frame(width: 58)

                Perforation()

                // 右：圩名主票
                VStack(alignment: .leading, spacing: 3) {
                    Text(mainTitle)
                        .font(.system(size: 17, weight: .black, design: .serif))
                        .foregroundStyle(Ink.title)
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                    Text(mainDetail)
                        .font(.system(size: 8.5, weight: .semibold))
                        .tracking(0.5)
                        .foregroundStyle(Ink.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 8)
                .padding(.trailing, 10)
            }
            .frame(maxHeight: .infinity)

            Spacer(minLength: 3)

            TornEdge()
                .padding(.bottom, 6)
        }
    }

    private var mainTitle: String {
        if let first = today.first { return first.name }
        if let next = nextMarketDay() { return next.name }
        return "七日无圩"
    }

    private var mainDetail: String {
        if today.isEmpty {
            if let next = nextMarketDay() { return "今日休 · \(next.label)开" }
            return "今日休"
        }
        return today.count == 1 ? "今日开圩" : "今日开圩 · \(today.count) 场"
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

// MARK: - 中号：主票 + 存根联

struct StripBoard: View {
    let entry: GanJiEntry

    private var today: [MarketRule] { entry.boards.first?.markets ?? [] }

    var body: some View {
        HStack(spacing: 0) {
            // 主票：今天
            VStack(spacing: 0) {
                HStack {
                    SectionLabel(text: "今日")
                    Spacer(minLength: 0)
                    Postmark(text: "圩", size: 24)
                        .offset(x: 4, y: -2)
                }
                .padding(.top, 11)
                .padding(.leading, 12)

                Spacer(minLength: 0)

                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text("\(Calendar.current.component(.day, from: entry.date))")
                        .font(.system(size: 34, weight: .black, design: .serif))
                        .foregroundStyle(Ink.title)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(LunarCalendar.weekdayText(entry.date))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Ink.secondary)
                }
                .padding(.leading, 12)

                Text(mainLine)
                    .font(.system(size: 12, weight: .black, design: .serif))
                    .foregroundStyle(today.isEmpty ? Ink.secondary : Ink.stamp)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.top, 3)

                Spacer(minLength: 0)

                TornEdge()
                    .padding(.bottom, 6)
                    .padding(.trailing, 8)
            }
            .frame(width: 150)

            // 撕开
            Perforation()

            // 右侧：三张存根联（明天/后天/大后天）
            VStack(alignment: .leading, spacing: 0) {
                SectionLabel(text: "存根")
                    .padding(.top, 11)
                    .padding(.leading, 9)
                let stubs = Array(entry.boards.dropFirst().prefix(3))
                ForEach(Array(stubs.enumerated()), id: \.offset) { index, board in
                    StubRow(board: board)
                    if index < stubs.count - 1 {
                        HairLine().padding(.vertical, 3).padding(.leading, 9)
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var mainLine: String {
        if let first = today.first {
            return today.count == 1 ? first.name : "\(first.name) 等\(today.count)场"
        }
        if let next = nextMarketDay() { return "\(next.label) · \(next.name)" }
        return "七日无圩"
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

/// 存根联一行：日期小票根 + 圩名。
private struct StubRow: View {
    let board: DayBoard

    private var label: String {
        let offset = Calendar.current.dateComponents(
            [.day], from: Calendar.current.startOfDay(for: Date()),
            to: Calendar.current.startOfDay(for: board.date)
        ).day ?? 0
        return offset == 1 ? "明" : (offset == 2 ? "后" : LunarCalendar.weekdayText(board.date))
    }

    var body: some View {
        HStack(spacing: 7) {
            Text(label)
                .font(.system(size: 9, weight: .black))
                .foregroundStyle(board.markets.isEmpty ? Ink.tertiary : Ink.stamp)
                .frame(width: 18, height: 18)
                .background(Circle().fill(Ink.paperDeep))
            if board.markets.isEmpty {
                Text("休")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Ink.tertiary)
            } else {
                Text(board.markets.prefix(2).map(\.name).joined(separator: " "))
                    .font(.system(size: 11.5, weight: .bold, design: .serif))
                    .foregroundStyle(Ink.title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            Spacer(minLength: 0)
        }
        .padding(.top, 6)
        .padding(.leading, 9)
        .padding(.trailing, 6)
    }
}

// MARK: - 大号：整版票据

struct AlmanacBoard: View {
    let entry: GanJiEntry

    var body: some View {
        VStack(spacing: 0) {
            // 顶部：票头
            HStack(alignment: .center) {
                SectionLabel(text: "赶集历 · 七日券")
                Spacer(minLength: 0)
                Text("No. \(Calendar.current.component(.day, from: entry.date))")
                    .font(.system(size: 9, weight: .black, design: .serif))
                    .foregroundStyle(Ink.stamp)
            }
            .padding(.top, 12)
            .padding(.horizontal, 14)
            .padding(.bottom, 4)

            // 主票：今天
            HStack(spacing: 0) {
                StubDate(entry: entry, daySize: 26)
                    .frame(width: 46)
                Perforation()
                VStack(alignment: .leading, spacing: 2) {
                    Text(mainTitle)
                        .font(.system(size: 16, weight: .black, design: .serif))
                        .foregroundStyle(Ink.title)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(mainDetail)
                        .font(.system(size: 8.5, weight: .semibold))
                        .tracking(0.5)
                        .foregroundStyle(Ink.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 9)
                .padding(.trailing, 10)
            }
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Ink.paperDeep.opacity(0.6))
            )
            .padding(.horizontal, 12)

            // 撕孔分隔
            HStack(spacing: 3) {
                ForEach(0..<40, id: \.self) { _ in
                    Circle().fill(Ink.punch).frame(width: 3, height: 3)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)

            // 七张日票：两行（4 + 3）
            let boards = Array(entry.boards.prefix(7))
            VStack(spacing: 7) {
                HStack(spacing: 7) {
                    ForEach(boards.prefix(4)) { board in
                        DayTicket(board: board, isToday: Calendar.current.isDateInToday(board.date))
                    }
                }
                if boards.count > 4 {
                    HStack(spacing: 7) {
                        ForEach(boards.dropFirst(4)) { board in
                            DayTicket(board: board, isToday: Calendar.current.isDateInToday(board.date))
                        }
                    }
                }
            }
            .padding(.horizontal, 12)

            Spacer(minLength: 0)
        }
    }

    private var mainTitle: String {
        let today = entry.boards.first?.markets ?? []
        if let first = today.first { return first.name }
        if let next = nextMarketDay() { return next.name }
        return "七日无圩"
    }

    private var mainDetail: String {
        let today = entry.boards.first?.markets ?? []
        if today.isEmpty {
            if let next = nextMarketDay() { return "今日休 · \(next.label)开" }
            return "今日休"
        }
        return today.count == 1 ? "今日开圩" : "今日开圩 · \(today.count) 场"
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

/// 一张「日票」：小方票，日期 + 圩名缩写 + 开圩印记。
private struct DayTicket: View {
    let board: DayBoard
    let isToday: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 3) {
                Text("\(Calendar.current.component(.day, from: board.date))")
                    .font(.system(size: 14, weight: .black, design: .serif))
                    .foregroundStyle(board.markets.isEmpty ? Ink.tertiary : Ink.title)
                    .lineLimit(1)
                Text(weekday)
                    .font(.system(size: 7.5, weight: .bold))
                    .foregroundStyle(Ink.secondary)
            }
            if board.markets.isEmpty {
                Text("休")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Ink.tertiary)
            } else {
                Text(board.markets.prefix(2).map(\.name).joined(separator: " "))
                    .font(.system(size: 9.5, weight: .black, design: .serif))
                    .foregroundStyle(isToday ? Ink.stamp : Ink.title)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
            }
            Spacer(minLength: 0)
            // 票根上的小孔印记：开圩日打孔，休市日是实心灰
            HStack(spacing: 2) {
                ForEach(0..<3, id: \.self) { _ in
                    Circle()
                        .fill(board.markets.isEmpty ? Ink.tertiary.opacity(0.4) : Ink.stamp.opacity(0.75))
                        .frame(width: 2.5, height: 2.5)
                }
            }
        }
        .padding(7)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Ink.paperDeep.opacity(0.55))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(isToday ? Ink.stamp.opacity(0.7) : Color.clear,
                                      lineWidth: isToday ? 1.2 : 0)
                )
        )
    }

    private var weekday: String {
        let names = ["日", "一", "二", "三", "四", "五", "六"]
        let idx = Calendar.current.component(.weekday, from: board.date) - 1
        return names[min(max(idx, 0), 6)]
    }
}
