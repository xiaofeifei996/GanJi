import Foundation
import Combine

/// Main-queue UI state, independent of photo editing. Refresh only for lifecycle,
/// saved feed changes and day changes; slider redraws never read from disk.
final class WidgetAppearanceSnapshot: ObservableObject {
    struct Dependencies {
        var read: () -> WidgetFeed? = WidgetFeed.current
        var now: () -> Date = Date.init
        var calendar: () -> Calendar = { .current }
        var enqueue: (DispatchWorkItem) -> Void = { Dependencies.worker.async(execute: $0) }
        var schedule: (Date, @escaping () -> Void) -> Timer? = { date, refresh in
            let timer = Timer(fire: date, interval: 0, repeats: false) { _ in refresh() }
            RunLoop.main.add(timer, forMode: .common)
            return timer
        }
        private static let worker = DispatchQueue(label: "com.ganji.appearance.feed", qos: .userInitiated)
    }

    @Published private(set) var entry: GanJiEntry?
    private let dependencies: Dependencies
    private var active = false
    private var requestID = UUID()
    private var work: DispatchWorkItem?
    private var midnight: Timer?

    init(dependencies: Dependencies = Dependencies()) { self.dependencies = dependencies }

    func start() {
        active = true
        refresh()
    }

    func stop() {
        active = false
        requestID = UUID()
        work?.cancel()
        work = nil
        midnight?.invalidate()
        midnight = nil
    }

    func refresh() {
        guard active else { return }
        work?.cancel()
        let request = UUID()
        requestID = request
        scheduleMidnight()
        let io = dependencies
        let pending = DispatchWorkItem { [weak self] in
            let feed = io.read()
            // Capture time after I/O so a read spanning midnight uses the new day.
            let entry = GanJiProvider.entry(now: io.now(), feed: feed, calendar: io.calendar())
            DispatchQueue.main.async { [weak self] in
                guard let self = self, self.active, self.requestID == request else { return }
                self.entry = entry
                self.work = nil
                self.scheduleMidnight()
            }
        }
        work = pending
        io.enqueue(pending)
    }

    static func nextMidnight(after now: Date, calendar: Calendar) -> Date? {
        calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))
    }

    private func scheduleMidnight() {
        midnight?.invalidate()
        guard active, let next = Self.nextMidnight(after: dependencies.now(), calendar: dependencies.calendar()) else { return }
        midnight = dependencies.schedule(next) { [weak self] in self?.refresh() }
    }

    deinit {
        work?.cancel()
        midnight?.invalidate()
    }
}
