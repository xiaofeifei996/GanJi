import SwiftUI

// 江南水墨风：画作为容器背景，文字浮在磨砂白卡上。
//   小号 = 左今日右三日（仿参考图小号：日期区 + 今日开圩绿签）
//   中号 = 三栏（仿参考图中号：今天/明天/后天 各带棚icon+开圩签）
//   大号 = 左日期区 + 右三栏（仿参考图大号的左右分区）

// MARK: - 小号

struct SealBoard: View {
    let entry: GanJiEntry

    private var today: [MarketRule] { entry.boards.first?.markets ?? [] }

    var body: some View {
        VStack(spacing: 7) {
            Spacer(minLength: 2)
            // 日期区
            VStack(spacing: 1) {
                Text(LunarCalendar.weekdayText(entry.date))
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(Ink.title)
                Text(dateText)
                    .font(.system(size: 21, weight: .heavy))
                    .foregroundStyle(Ink.title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                // 云纹分隔：简化为一条带端点的细线
                HStack(spacing: 3) {
                    Circle().fill(Ink.secondary.opacity(0.5)).frame(width: 2.5, height: 2.5)
                    Rectangle().fill(Ink.secondary.opacity(0.4)).frame(width: 44, height: 0.8)
                    Circle().fill(Ink.secondary.opacity(0.5)).frame(width: 2.5, height: 2.5)
                }
            }

            // 今日状态卡
            HStack(spacing: 6) {
                StallIcon(size: 17, open: !today.isEmpty)
                Text(today.isEmpty ? "今日休圩" : "今日开圩")
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(today.isEmpty ? Ink.secondary : Ink.greenDeep)
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 7)
            .background(GlassCard(strong: true, radius: 15))

            // 农历行
            HStack(spacing: 5) {
                SealMark(size: 13)
                Text("农历" + LunarCalendar.lunarText(entry.date))
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Ink.title)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(GlassCard(radius: 9))

            if let first = today.first {
                Text(first.name)
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(Ink.greenDeep)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .background(GlassCard(radius: 8))
            } else if let next = nextMarketDay() {
                Text("\(next.label)·\(next.name)")
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(Ink.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .background(GlassCard(radius: 8))
            }

            Spacer(minLength: 2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 13)
    }

    private var dateText: String {
        let c = Calendar.current.dateComponents([.month, .day], from: entry.date)
        return "\(c.month ?? 1)月\(c.day ?? 1)日"
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

// MARK: - 中号：今天 / 明天 / 后天 三栏

struct StripBoard: View {
    let entry: GanJiEntry

    var body: some View {
        HStack(spacing: 0) {
            dayColumn(entry.boards[0], label: "今天")
            divider
            dayColumn(entry.boards.count > 1 ? entry.boards[1] : nil, label: "明天")
            divider
            dayColumn(entry.boards.count > 2 ? entry.boards[2] : nil, label: "后天")
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 6)
    }

    private var divider: some View {
        VStack(spacing: 2) {
            Rectangle()
                .fill(Ink.secondary.opacity(0.55))
                .frame(width: 1, height: 8)
            Circle()
                .strokeBorder(Ink.secondary.opacity(0.55), lineWidth: 1)
                .frame(width: 4, height: 4)
            Rectangle()
                .fill(Ink.secondary.opacity(0.55))
                .frame(width: 1, height: 8)
        }
        .frame(width: 13)
    }

    @ViewBuilder
    private func dayColumn(_ board: DayBoard?, label: String) -> some View {
        VStack(spacing: 5) {
            Text(label)
                .font(.system(size: 12, weight: .black))
                .foregroundStyle(.white)
                .padding(.horizontal, 11)
                .padding(.vertical, 3.5)
                .background(
                    Capsule().fill(board?.markets.isEmpty == false
                        ? Ink.green
                        : Color(red: 0.45, green: 0.48, blue: 0.47))
                )
            if let board {
                Text(shortDate(board.date))
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(Ink.title)
                StallIcon(size: 22, open: !board.markets.isEmpty)
                GreenBadge(
                    text: board.markets.isEmpty ? "不开圩" : "开圩",
                    isOpen: !board.markets.isEmpty
                )
                if !board.markets.isEmpty {
                    Text(board.markets.prefix(2).map(\.name).joined(separator: " "))
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundStyle(Ink.greenDeep)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .padding(.horizontal, 6)
                }
            } else {
                Text("—")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(Ink.tertiary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func shortDate(_ date: Date) -> String {
        let c = Calendar.current.dateComponents([.month, .day], from: date)
        return "\(c.month ?? 1)月\(c.day ?? 1)日"
    }
}

// MARK: - 大号：左日期 + 右三栏

struct AlmanacBoard: View {
    let entry: GanJiEntry

    private var today: [MarketRule] { entry.boards.first?.markets ?? [] }

    var body: some View {
        HStack(spacing: 0) {
            // 左：日期区（仿参考图：星期 + 大日期 + 云纹 + 今日卡 + 农历）
            VStack(spacing: 7) {
                Spacer(minLength: 0)
                Text(LunarCalendar.weekdayText(entry.date))
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(Ink.title)
                Text(dateText)
                    .font(.system(size: 30, weight: .heavy))
                    .foregroundStyle(Ink.title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                HStack(spacing: 3) {
                    Circle().fill(Ink.secondary.opacity(0.5)).frame(width: 2.5, height: 2.5)
                    Rectangle().fill(Ink.secondary.opacity(0.4)).frame(width: 54, height: 0.8)
                    Circle().fill(Ink.secondary.opacity(0.5)).frame(width: 2.5, height: 2.5)
                }
                HStack(spacing: 6) {
                    StallIcon(size: 19, open: !today.isEmpty)
                    Text(today.isEmpty ? "今日休圩" : "今日开圩")
                        .font(.system(size: 15, weight: .black))
                        .foregroundStyle(today.isEmpty ? Ink.secondary : Ink.greenDeep)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(GlassCard(strong: true, radius: 16))
                HStack(spacing: 5) {
                    SealMark(size: 13)
                    Text("农历" + LunarCalendar.lunarText(entry.date))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Ink.title)
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(GlassCard(radius: 9))
                if let first = today.first {
                    Text(first.name)
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundStyle(Ink.greenDeep)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 3)
                        .background(GlassCard(radius: 8))
                }
                Spacer(minLength: 0)
            }
            .frame(width: 148)

            // 中缝云纹分隔
            VStack(spacing: 2) {
                Rectangle()
                    .fill(Ink.secondary.opacity(0.5))
                    .frame(width: 1, height: 10)
                Circle()
                    .strokeBorder(Ink.secondary.opacity(0.5), lineWidth: 1)
                    .frame(width: 5, height: 5)
                Rectangle()
                    .fill(Ink.secondary.opacity(0.5))
                    .frame(width: 1, height: 10)
            }
            .frame(width: 15)

            // 右：未来三天赶集安排
            VStack(spacing: 6) {
                // 题签
                Text("未来三天赶集安排")
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(1)
                    .foregroundStyle(Ink.title)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(GlassCard(strong: true, radius: 7))
                    .overlay(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .strokeBorder(Ink.secondary.opacity(0.45), lineWidth: 0.8)
                    )

                HStack(spacing: 0) {
                    planColumn(entry.boards[0], label: "今天")
                    miniDivider
                    planColumn(entry.boards.count > 1 ? entry.boards[1] : nil, label: "明天")
                    miniDivider
                    planColumn(entry.boards.count > 2 ? entry.boards[2] : nil, label: "后天")
                }
                .frame(maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity)
            .padding(.leading, 6)
            .padding(.trailing, 10)
            .padding(.vertical, 10)
        }
        .padding(.vertical, 10)
        .padding(.leading, 12)
    }

    private var miniDivider: some View {
        Rectangle()
            .fill(Ink.secondary.opacity(0.35))
            .frame(width: 0.8, height: 64)
            .frame(maxHeight: .infinity)
    }

    @ViewBuilder
    private func planColumn(_ board: DayBoard?, label: String) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .black))
                .foregroundStyle(Ink.title)
            if let board {
                Text(shortDate(board.date))
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(Ink.secondary)
                StallIcon(size: 19, open: !board.markets.isEmpty)
                GreenBadge(
                    text: board.markets.isEmpty ? "不开圩" : "开圩",
                    isOpen: !board.markets.isEmpty,
                    size: 11
                )
                if !board.markets.isEmpty {
                    Text(board.markets.first?.name ?? "")
                        .font(.system(size: 8.5, weight: .heavy))
                        .foregroundStyle(Ink.greenDeep)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .padding(.horizontal, 4)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var dateText: String {
        let c = Calendar.current.dateComponents([.month, .day], from: entry.date)
        return "\(c.month ?? 1)月\(c.day ?? 1)日"
    }

    private func shortDate(_ date: Date) -> String {
        let c = Calendar.current.dateComponents([.month, .day], from: date)
        return "\(c.month ?? 1)月\(c.day ?? 1)日"
    }
}
