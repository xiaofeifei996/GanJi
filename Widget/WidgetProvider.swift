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
    let region: String
    let boards: [DayBoard]
    let synced: Bool

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
        return GanJiEntry(date: Date(), region: "桂平市", boards: boards, synced: true)
    }
}

struct GanJiProvider: TimelineProvider {
    func placeholder(in context: Context) -> GanJiEntry { GanJiEntry.sample() }

    func getSnapshot(in context: Context, completion: @escaping (GanJiEntry) -> Void) {
        completion(context.isPreview ? GanJiEntry.sample() : build(now: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<GanJiEntry>) -> Void) {
        let now = Date()
        let entry = build(now: now)
        // 版面以「日」为单位变化，唯一必须刷新的时刻是跨过零点。
        // 多留一分钟，避免正好卡在日界上取到前一天。
        let midnight = Calendar.current.nextDate(
            after: now,
            matching: DateComponents(hour: 0, minute: 1),
            matchingPolicy: .nextTime
        ) ?? now.addingTimeInterval(3600)
        completion(Timeline(entries: [entry], policy: .after(midnight)))
    }

    private func build(now: Date) -> GanJiEntry {
        let cal = Calendar.current
        let start = cal.startOfDay(for: now)
        guard let feed = WidgetFeed.current() else {
            return GanJiEntry(date: now, region: "", boards: [], synced: false)
        }
        let boards = (0..<7).compactMap { offset -> DayBoard? in
            guard let day = cal.date(byAdding: .day, value: offset, to: start) else { return nil }
            return DayBoard(date: day, markets: feed.rules.filter { MarketSchedule.opens($0, on: day) })
        }
        return GanJiEntry(date: now, region: feed.regionName, boards: boards, synced: true)
    }
}
