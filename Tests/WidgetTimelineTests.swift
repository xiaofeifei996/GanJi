import Foundation
import WidgetKit

@main
struct WidgetTimelineTests {
    static func main() {
        let rule = MarketRule(id: "test", name: "测试圩", area: "桂平",
                              repeatType: 6, repeatValue: ["兔"])
        let feed = WidgetFeed(source: WidgetFeed.favoriteSource,
                              updatedAt: Date(), rules: [rule])
        for (zone, year, month, day, expectedHours) in [
            ("Asia/Shanghai", 2026, 12, 31, 24.0),
            ("America/Los_Angeles", 2026, 3, 7, 23.0),
            ("America/Los_Angeles", 2026, 10, 31, 25.0)
        ] {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(identifier: zone)!
            let now = calendar.date(from: DateComponents(year: year, month: month, day: day,
                                                         hour: 23, minute: 59, second: 59))!
            let entries = GanJiProvider.timelineEntries(now: now, feed: feed, calendar: calendar)
            precondition(entries.count == 7)
            precondition(entries[0].date == now)
            precondition(entries[1].date.timeIntervalSince(now) == 1, "Must roll at midnight")
            precondition(entries[2].date.timeIntervalSince(entries[1].date) == expectedHours * 3600,
                         "Calendar days must survive DST: \(zone)")
            for (offset, entry) in entries.enumerated() {
                precondition(entry.synced && entry.favoriteCount == 1)
                precondition(entry.boards.count == 7)
                precondition(entry.boards[0].date == calendar.startOfDay(for: entry.date))
                for board in entry.boards {
                    precondition(board.markets == feed.rules.filter { MarketSchedule.opens($0, on: board.date) })
                }
                if offset > 0 { precondition(entry.date > entries[offset - 1].date) }
            }
            let missing = GanJiProvider.timelineEntries(now: now, feed: nil, calendar: calendar)
            precondition(missing.count == 7 && missing.allSatisfy { !$0.synced && $0.boards.isEmpty })
            let empty = WidgetFeed(source: WidgetFeed.favoriteSource, updatedAt: now, rules: [])
            let emptyEntries = GanJiProvider.timelineEntries(now: now, feed: empty, calendar: calendar)
            precondition(emptyEntries.allSatisfy { $0.synced && $0.favoriteCount == 0 && $0.boards.count == 7 })
            precondition(GanJiProvider.timelineEntries(now: now, feed: feed, dayCount: 1).count == 1)
        }
        print("Widget timeline regression tests passed")
    }
}
