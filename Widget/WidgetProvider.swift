import Foundation
import WidgetKit
import SwiftUI

/// 一天一行的版面数据。
struct DayBoard: Identifiable {
    let date: Date
    let markets: [MarketRule]
    var id: Double { date.timeIntervalSince1970 }
}

struct GanJiEntry: TimelineEntry {
    let date: Date
    let boards: [DayBoard]
    /// 是否已经收到过一份快照（用来区分「从未同步」和「同步了但没收藏」）。
    let synced: Bool
    /// 收藏的圩点数。为 0 时小组件应该提示去 App 里收藏，而不是说「今日休市」。
    let favoriteCount: Int

    var today: [MarketRule] { boards.first?.markets ?? [] }

    /// 预览与占位用。只在时间线还没能读到真实数据时出现。
    static func sample() -> GanJiEntry {
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        let rules = [
            MarketRule(id: "s1", name: "大妙圩", area: "桂平", repeatType: 6, repeatValue: ["兔"]),
            MarketRule(id: "s2", name: "登明圩", area: "桂平", repeatType: 6, repeatValue: ["马"]),
            MarketRule(id: "s3", name: "石龙圩", area: "平南", repeatType: 1, repeatValue: ["初一", "十五"])
        ]
        let boards = (0..<7).compactMap { offset -> DayBoard? in
            guard let day = cal.date(byAdding: .day, value: offset, to: start) else { return nil }
            let list = rules.filter { MarketSchedule.opens($0, on: day) }
            return DayBoard(date: day, markets: list)
        }
        return GanJiEntry(date: Date(), boards: boards,
                          synced: true, favoriteCount: rules.count)
    }
}

struct GanJiProvider: TimelineProvider {
    func placeholder(in context: Context) -> GanJiEntry { GanJiEntry.sample() }

    func getSnapshot(in context: Context, completion: @escaping (GanJiEntry) -> Void) {
        completion(context.isPreview ? GanJiEntry.sample() : build(now: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<GanJiEntry>) -> Void) {
        let now = Date()
        let entries = Self.timelineEntries(now: now, feed: WidgetFeed.current())
        // 预交付未来零点的版面；系统无需在跨日时重新启动扩展来计算。
        // 收藏变化仍由 App 主动 reload，最后一条显示后再申请下一批。
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    private func build(now: Date) -> GanJiEntry {
        Self.timelineEntries(now: now, feed: WidgetFeed.current(), dayCount: 1)[0]
    }

    static func timelineEntries(now: Date, feed: WidgetFeed?,
                                calendar: Calendar = .current,
                                dayCount: Int = 7) -> [GanJiEntry] {
        let count = max(1, dayCount)
        let start = calendar.startOfDay(for: now)
        // 每张版面向后看七天。重叠日期只算一次，七张版面共算十三天。
        let boards = (0..<(count + 6)).compactMap { offset -> DayBoard? in
            guard let day = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
            let markets = feed?.rules.filter { MarketSchedule.opens($0, on: day) } ?? []
            return DayBoard(date: day, markets: markets)
        }
        return (0..<count).map { offset in
            let date = offset == 0 ? now
                : (calendar.date(byAdding: .day, value: offset, to: start) ?? now)
            return GanJiEntry(date: date,
                              boards: feed == nil ? [] : Array(boards.dropFirst(offset).prefix(7)),
                              synced: feed != nil, favoriteCount: feed?.rules.count ?? 0)
        }
    }
}
