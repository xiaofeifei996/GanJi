import SwiftUI

/// 大卡片风视觉层。
///
/// 和前几版的区别：不再有「列表 + 圆点」的档案感，
/// 而是把「今天该去的圩」做成一张占满视觉重心的大卡片，
/// 信息像车票一样排：大站名、时间感的进度条、小注脚。
/// 底色故意选低饱和的暖灰，让蓝卡片跳出来。
enum Ink {
    static let page = Color(red: 0.93, green: 0.93, blue: 0.95)
    static let ticket = Color(red: 0.16, green: 0.40, blue: 0.90)
    static let ticketDeep = Color(red: 0.10, green: 0.30, blue: 0.72)
    static let onTicket = Color.white
    static let title = Color(red: 0.10, green: 0.11, blue: 0.13)
    static let secondary = Color(red: 0.42, green: 0.44, blue: 0.48)
    static let tertiary = Color(red: 0.60, green: 0.62, blue: 0.66)
    static let hairline = Color.white.opacity(0.55)
}

struct WidgetSurface: View {
    var body: some View {
        Ink.page
    }
}

extension View {
    @ViewBuilder
    func paperWidget() -> some View {
        if #available(iOS 17.0, *) {
            containerBackground(for: .widget) { WidgetSurface() }
        } else {
            background(WidgetSurface())
        }
    }
}

/// 今天开圩的那张「主卡」：蓝色、大圩名、白字。
/// 休市时整张卡转成灰色，语义立变。
struct TicketCard: View {
    let title: String
    let subtitle: String
    let isOpen: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(subtitle)
                .font(.system(size: 9, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(Ink.onTicket.opacity(0.75))
                .lineLimit(1)
            Text(title)
                .font(.system(size: 21, weight: .heavy, design: .rounded))
                .foregroundStyle(Ink.onTicket)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.top, 2)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(isOpen ? Ink.ticket : Color(red: 0.55, green: 0.57, blue: 0.61))
        )
    }
}

/// 七日的「进度感」：一排圆角小格，走过的是深色，今天是白色，未来是浅色。
struct DayMeter: View {
    let boards: [DayBoard]

    var body: some View {
        HStack(spacing: 3) {
            ForEach(Array(boards.prefix(7).enumerated()), id: \.offset) { index, board in
                let isToday = Calendar.current.isDateInToday(board.date)
                RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                    .fill(meterColor(board: board, isToday: isToday))
                    .frame(height: 5)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func meterColor(board: DayBoard, isToday: Bool) -> Color {
        if isToday { return .white }
        return board.markets.isEmpty
            ? Color.white.opacity(0.18)
            : Color.white.opacity(0.55)
    }
}

/// 打头的小栏名。
struct SectionLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .heavy))
            .tracking(1.1)
            .foregroundStyle(Ink.secondary)
            .lineLimit(1)
    }
}

struct HairLine: View {
    var body: some View {
        Rectangle()
            .fill(Ink.title.opacity(0.07))
            .frame(height: 1)
    }
}
