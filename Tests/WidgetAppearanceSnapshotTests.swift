import Foundation

@main struct WidgetAppearanceSnapshotTests {
    static var checks = 0
    static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        precondition(condition(), message)
        checks += 1
    }
    static func drain() {
        var done = false
        DispatchQueue.main.async { done = true }
        let deadline = Date().addingTimeInterval(5)
        while !done && Date() < deadline { RunLoop.main.run(until: Date().addingTimeInterval(0.001)) }
        expect(done, "Main queue timed out")
    }
    static func equal(_ actual: GanJiEntry, _ expected: GanJiEntry) {
        expect(actual.date == expected.date && actual.synced == expected.synced && actual.favoriteCount == expected.favoriteCount,
               "Preview metadata differs from production timeline")
        expect(actual.boards.map(\.date) == expected.boards.map(\.date), "Preview dates differ")
        expect(actual.boards.map(\.markets) == expected.boards.map(\.markets), "Preview markets differ")
    }
    final class IO {
        var jobs: [DispatchWorkItem] = []
        var feed: WidgetFeed?
        var now = Date()
        var calendar = Calendar.current
        var reads = 0
        var scheduled: Date?
        var midnight: (() -> Void)?
        func dependencies() -> WidgetAppearanceSnapshot.Dependencies {
            var d = WidgetAppearanceSnapshot.Dependencies()
            d.read = {
                precondition(!Thread.isMainThread, "Feed disk reads must stay off main")
                self.reads += 1
                return self.feed
            }
            d.now = { self.now }
            d.calendar = { self.calendar }
            d.enqueue = { self.jobs.append($0) }
            d.schedule = { date, callback in
                self.scheduled = date
                self.midnight = callback
                return nil
            }
            return d
        }
        func run(_ index: Int) {
            let job = jobs[index]
            let done = DispatchSemaphore(value: 0)
            DispatchQueue.global().async { job.perform(); done.signal() }
            expect(done.wait(timeout: .now() + 5) == .success, "Worker timed out")
        }
    }
    static func main() {
        let io = IO()
        io.calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        io.now = io.calendar.date(from: DateComponents(year: 2026, month: 12, day: 31, hour: 23, minute: 59, second: 59))!
        let realRule = MarketRule(id: "favorite-unique", name: "广西麻垌镇", area: "桂平",
                                  repeatType: 1, repeatValue: (1...30).map(String.init))
        let realFeed = WidgetFeed(source: WidgetFeed.favoriteSource, updatedAt: io.now, rules: [realRule])
        let preview = WidgetAppearanceSnapshot(dependencies: io.dependencies())
        expect(preview.entry == nil && io.reads == 0, "Initialization must not fake data or read disk")
        preview.refresh()
        expect(io.jobs.isEmpty, "Hidden preview should not load")
        preview.start(); io.run(0); drain()
        equal(preview.entry!, GanJiProvider.timelineEntries(now: io.now, feed: nil, calendar: io.calendar)[0])
        expect(!preview.entry!.synced && preview.entry!.boards.isEmpty, "Nil must remain unsynced")
        io.feed = WidgetFeed(source: WidgetFeed.favoriteSource, updatedAt: io.now, rules: [])
        preview.refresh(); io.run(1); drain()
        equal(preview.entry!, GanJiProvider.timelineEntries(now: io.now, feed: io.feed, calendar: io.calendar)[0])
        expect(preview.entry!.synced && preview.entry!.favoriteCount == 0, "Empty favorites must remain empty")
        io.feed = realFeed
        preview.refresh(); io.run(2); drain()
        equal(preview.entry!, GanJiProvider.timelineEntries(now: io.now, feed: realFeed, calendar: io.calendar)[0])
        expect(preview.entry!.today.map(\.id) == ["favorite-unique"], "Real favorites replaced by samples")
        expect(preview.entry!.today.map(\.widgetDisplayName) == ["麻垌圩"], "Names must match normalized widget names")
        for _ in 0..<100 { _ = preview.entry }
        expect(io.reads == 3, "Rendering should use cached data")

        // An older completion is already on the main queue when a new saved feed arrives.
        io.feed = nil
        preview.refresh(); io.run(3)
        io.feed = realFeed
        preview.refresh()
        drain()
        expect(preview.entry!.favoriteCount == 1, "Older completion replaced current snapshot")
        io.run(4); drain()
        expect(preview.entry!.today.map(\.id) == ["favorite-unique"], "Latest request failed")

        let tomorrow = GanJiProvider.timelineEntries(now: io.now, feed: realFeed, calendar: io.calendar)[1]
        expect(io.scheduled == io.now.addingTimeInterval(1), "Refresh must be scheduled at the next midnight")
        io.now = io.now.addingTimeInterval(1)
        io.midnight!(); io.run(5); drain()
        equal(preview.entry!, tomorrow)
        expect(io.calendar.component(.year, from: preview.entry!.date) == 2027, "Year rollover failed")
        preview.refresh(); io.run(6)
        preview.stop(); drain()
        let count = io.jobs.count
        preview.refresh()
        expect(io.jobs.count == count, "Stopped view scheduled work")
        io.feed = nil
        preview.start(); io.run(7); drain()
        expect(!preview.entry!.synced, "Return to active did not reload feed")
        preview.stop()

        for (zone, year, month, day, hours) in [
            ("Asia/Shanghai", 2026, 12, 31, 24.0),
            ("America/Los_Angeles", 2026, 3, 8, 23.0),
            ("America/Los_Angeles", 2026, 11, 1, 25.0)
        ] {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(identifier: zone)!
            let start = calendar.date(from: DateComponents(year: year, month: month, day: day))!
            let next = WidgetAppearanceSnapshot.nextMidnight(after: start, calendar: calendar)!
            expect(next.timeIntervalSince(start) == hours * 3600, "Midnight must respect DST and year changes")
        }
        // Production worker coverage: wait for the published real entry.
        var timed = WidgetAppearanceSnapshot.Dependencies()
        timed.read = { precondition(!Thread.isMainThread); return realFeed }
        let background = WidgetAppearanceSnapshot(dependencies: timed)
        background.start()
        let deadline = Date().addingTimeInterval(5)
        while background.entry == nil && Date() < deadline { RunLoop.main.run(until: Date().addingTimeInterval(0.001)) }
        expect(background.entry?.favoriteCount == 1, "Production worker did not deliver real feed")
        background.stop()
        print("WidgetAppearanceSnapshotTests: \(checks) checks passed")
    }
}
