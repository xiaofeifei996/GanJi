import Foundation
import UIKit

// Exercise the production editor with controlled worker scheduling and temporary
// in-memory backgrounds. No app-group data or real WidgetCenter calls are used.
@main struct WidgetAppearanceEditorTests {
    static var checks = 0
    static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        precondition(condition(), message)
        checks += 1
    }

    static func drainMain() {
        var done = false
        DispatchQueue.main.async { done = true }
        let deadline = Date().addingTimeInterval(5)
        while !done && Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.001))
        }
        expect(done, "Main queue did not drain")
    }

    static func state(_ size: WidgetPhotoSize, empty: Bool = false) -> WidgetBackgroundStore.EditorState {
        let value: Double = size == .small ? 0.1 : size == .medium ? 0.4 : 0.8
        return .init(image: empty ? nil : UIImage(),
                     sourceData: empty ? nil : Data(size.rawValue.utf8),
                     sourceImage: empty ? nil : UIImage(),
                     focalX: value, focalY: 1 - value, darkness: value)
    }

    final class IO {
        var jobs: [DispatchWorkItem] = []
        var backgrounds = Dictionary(uniqueKeysWithValues: WidgetPhotoSize.allCases.map { ($0, state($0)) })
        var writes: [(WidgetPhotoSize, Data?, Double, Double, Double)] = []
        var resets: [WidgetPhotoSize] = []
        var failWrite = false
        var readsOffMain = true
        var beforeRead: ((WidgetPhotoSize) -> Void)?

        func dependencies() -> WidgetAppearanceEditor.Dependencies {
            var io = WidgetAppearanceEditor.Dependencies()
            io.read = { size in
                self.readsOffMain = self.readsOffMain && !Thread.isMainThread
                let snapshot = self.backgrounds[size]!
                self.beforeRead?(size)
                return snapshot
            }
            io.save = { data, size, dim, x, y in
                if self.failWrite { throw NSError(domain: "test", code: 1) }
                self.writes.append((size, data, dim, x, y))
                self.backgrounds[size] = .init(image: UIImage(), sourceData: data, sourceImage: UIImage(),
                                               focalX: x, focalY: y, darkness: dim)
            }
            io.updateDarkness = { size, dim in self.writes.append((size, nil, dim, 0.5, 0.5)) }
            io.reset = { size in
                if self.failWrite { throw NSError(domain: "test", code: 2) }
                self.resets.append(size)
                self.backgrounds[size] = state(size, empty: true)
            }
            io.reload = {}
            io.enqueue = { self.jobs.append($0) }
            return io
        }

        func run(_ index: Int) {
            let job = jobs[index]
            let done = DispatchSemaphore(value: 0)
            DispatchQueue.global(qos: .userInitiated).async { job.perform(); done.signal() }
            expect(done.wait(timeout: .now() + 5) == .success, "Worker timed out")
        }
    }

    static func main() {
        expect(Thread.isMainThread, "Editor tests must run on the UI thread")
        latestWins()
        discardAndGateWrites()
        failuresUnlock()
        print("WidgetAppearanceEditorTests: \(checks) checks passed")
    }

    static func latestWins() {
        let io = IO()
        let editor = WidgetAppearanceEditor(dependencies: io.dependencies())
        let entered = DispatchSemaphore(value: 0)
        let release = DispatchSemaphore(value: 0)
        let finished = DispatchSemaphore(value: 0)
        io.beforeRead = { size in
            if size == .small {
                entered.signal()
                precondition(release.wait(timeout: .now() + 5) == .success)
            }
        }
        editor.load()
        let first = io.jobs[0]
        DispatchQueue.global().async { first.perform(); finished.signal() }
        expect(entered.wait(timeout: .now() + 5) == .success, "Slow read did not start")
        editor.select(.medium)
        editor.select(.large)
        expect(editor.size == .large && editor.loading && !editor.isPerformingOperation,
               "Routine reads must accept every size selection immediately")
        expect(editor.image == nil && editor.sourceData == nil, "Old family content leaked during load")
        editor.save(); editor.reset()
        expect(!editor.beginPhotoImport() && io.jobs.count == 3, "Writes/import must wait for selected read")
        io.run(2)
        drainMain()
        expect(editor.size == .large && editor.darkness == 0.8 && !editor.loading, "Latest selection must win")
        release.signal()
        expect(finished.wait(timeout: .now() + 5) == .success, "Old read did not finish")
        drainMain()
        expect(editor.size == .large && editor.sourceData == Data("large".utf8) && editor.darkness == 0.8,
               "Late small read overwrote large background")
        io.run(1) // A cancelled queued medium read must not change the result.
        drainMain()
        expect(editor.focalX == 0.8 && !editor.loading && io.readsOffMain, "Cancelled read or main-thread decoding")

        // ABA: an old result for the same family is still stale. It must not
        // prematurely unlock actions while the newer visit is loading.
        io.beforeRead = nil
        editor.select(.small)
        io.run(3) // completion is queued, but intentionally not delivered yet
        editor.select(.medium)
        editor.select(.small)
        drainMain()
        expect(editor.loading && editor.image == nil, "Old small completion unlocked a newer small request")
        io.run(5)
        drainMain()
        expect(!editor.loading && editor.darkness == 0.1, "Newest small request failed")
    }

    static func discardAndGateWrites() {
        let io = IO()
        let editor = WidgetAppearanceEditor(dependencies: io.dependencies())
        editor.load(); io.run(0); drainMain()
        expect(editor.beginPhotoImport(), "Import should start after load")
        editor.select(.large); editor.save(); editor.reset()
        expect(editor.size == .small && io.jobs.count == 1, "Import must lock family and writes")
        editor.finishPhotoImport(.success(.init(data: Data("import".utf8), preview: UIImage())))
        editor.focalX = 0.91; editor.darkness = 0.99
        editor.select(.medium)
        expect(editor.sourceData == nil && !editor.adjustmentsExpanded && editor.focalX == 0.5,
               "Switch did not discard unsaved imported source and focus")
        io.run(1); drainMain()
        expect(editor.darkness == 0.4 && editor.sourceData == Data("medium".utf8), "Wrong per-size saved state")
        editor.focalX = 0.23; editor.focalY = 0.67; editor.darkness = 0.61
        editor.save()
        editor.select(.large); editor.load(); editor.reset()
        expect(editor.size == .medium && io.jobs.count == 3 && editor.operation == .saving,
               "Save must hold family and reject overlapping operations")
        io.run(2); drainMain()
        expect(io.writes.count == 1 && io.writes[0].0 == .medium && io.writes[0].1 == Data("medium".utf8)
               && io.writes[0].2 == 0.61 && io.writes[0].3 == 0.23 && io.writes[0].4 == 0.67,
               "Save wrote wrong family/source/edit snapshot")
        editor.select(.small); io.run(3); drainMain()
        expect(editor.sourceData == Data("small".utf8) && editor.darkness == 0.1, "Unsaved small import persisted")
        editor.select(.medium); io.run(4); drainMain()
        expect(editor.darkness == 0.61 && editor.focalX == 0.23, "Saved medium edits were lost")
        editor.reset(); editor.select(.large)
        expect(editor.size == .medium && editor.operation == .resetting, "Reset must hold its selected family")
        io.run(5); drainMain()
        expect(io.resets == [.medium] && editor.image == nil && editor.sourceData == nil && !editor.busy,
               "Reset did not clear only selected family")
        editor.select(.large); io.run(6); drainMain()
        expect(editor.darkness == 0.8 && editor.sourceData == Data("large".utf8), "Other family was modified")
    }

    static func failuresUnlock() {
        let io = IO()
        let editor = WidgetAppearanceEditor(dependencies: io.dependencies())
        editor.load(); io.run(0); drainMain()
        io.failWrite = true
        editor.save(); io.run(1); drainMain()
        expect(!editor.busy && editor.error != nil && editor.sourceData == Data("small".utf8),
               "Failed save must unlock without losing editable source")
        editor.select(.medium); io.run(2); drainMain()
        expect(editor.error == nil && editor.size == .medium, "Failed save left selection locked")
        editor.reset(); io.run(3); drainMain()
        expect(!editor.busy && editor.error != nil && editor.image != nil, "Failed reset discarded source or stayed locked")
        expect(editor.beginPhotoImport(), "Import after failure did not start")
        editor.finishPhotoImport(.failure(NSError(domain: "test", code: 3)))
        expect(!editor.busy && editor.error != nil, "Import error left editor locked")
        editor.select(.large); io.run(4); drainMain()
        expect(editor.size == .large && !editor.busy, "Import failure prevented size switching")
    }
}
