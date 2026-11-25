import SwiftUI
import UIKit
import WidgetKit

// UI state is main-queue confined. Disk I/O and image decoding run on a serial
// worker; cancelled pending reads are skipped and in-flight results are versioned.
final class WidgetAppearanceEditor: ObservableObject {
    enum Operation { case importing, saving, resetting }

    struct Dependencies {
        var sharingIssue: () -> String? = { WidgetSharedStorage.sharingIssue }
        var read: (WidgetPhotoSize) -> WidgetBackgroundStore.EditorState = WidgetBackgroundStore.editorState
        var save: (Data, WidgetPhotoSize, Double, Double, Double) throws -> Void = {
            try WidgetBackgroundStore.save(imageData: $0, for: $1, darkness: $2, focalX: $3, focalY: $4)
        }
        var updateDarkness: (WidgetPhotoSize, Double) throws -> Void = {
            try WidgetBackgroundStore.updateDarkness(for: $0, darkness: $1)
        }
        var reset: (WidgetPhotoSize) throws -> Void = WidgetBackgroundStore.reset
        var reload: () -> Void = { WidgetCenter.shared.reloadAllTimelines() }
        var enqueue: (DispatchWorkItem) -> Void = { Dependencies.worker.async(execute: $0) }
        private static let worker = DispatchQueue(label: "com.ganji.appearance", qos: .userInitiated)
    }

    @Published private(set) var size: WidgetPhotoSize = .small
    @Published var image: UIImage?
    @Published var sourceData: Data?
    @Published var adjustmentsExpanded = false
    @Published var focalX = 0.5
    @Published var focalY = 0.5
    @Published var darkness = 0.35
    @Published private(set) var loading = false
    @Published private(set) var operation: Operation?
    @Published var status: String?
    @Published var error: String?
    @Published private(set) var sharingIssue: String?
    private(set) var loaded = false
    private let dependencies: Dependencies
    private var loadID = UUID()
    private var loadWork: DispatchWorkItem?

    init(dependencies: Dependencies = Dependencies()) { self.dependencies = dependencies }

    var isPerformingOperation: Bool { operation != nil }
    var busy: Bool { loading || isPerformingOperation }
    var activity: String {
        switch operation {
        case .importing: return "正在导入照片…"
        case .saving: return "正在保存…"
        case .resetting: return "正在恢复…"
        case nil: return "正在读取…"
        }
    }

    // The Picker setter changes family and invalidates the old state together,
    // rather than waiting for SwiftUI's deferred onChange delivery.
    func select(_ selectedSize: WidgetPhotoSize) {
        guard !isPerformingOperation, selectedSize != size else { return }
        size = selectedSize
        load()
    }

    func load() {
        guard !isPerformingOperation else { return }
        loadWork?.cancel()
        let request = UUID()
        loadID = request
        let selectedSize = size
        loading = true
        status = nil
        error = nil
        // Switching always discards unsaved edits, including an imported original.
        image = nil
        sourceData = nil
        focalX = 0.5
        focalY = 0.5
        darkness = 0.35
        adjustmentsExpanded = false
        let read = dependencies.read
        let diagnose = dependencies.sharingIssue
        let work = DispatchWorkItem { [weak self] in
            let state = autoreleasepool { read(selectedSize) }
            let issue = diagnose()
            DispatchQueue.main.async { [weak self] in
                guard let self = self, self.loadID == request, self.size == selectedSize,
                      !self.isPerformingOperation else { return }
                self.apply(state)
                self.sharingIssue = issue
                self.loaded = true
                self.loading = false
                self.loadWork = nil
            }
        }
        loadWork = work
        dependencies.enqueue(work)
    }

    @discardableResult func beginPhotoImport() -> Bool {
        guard !busy else { return false }
        begin(.importing)
        return true
    }

    func finishPhotoImport(_ result: Result<WidgetAppearancePhoto, Error>) {
        guard operation == .importing else { return }
        operation = nil
        switch result {
        case .success(let photo):
            sourceData = photo.data
            image = photo.preview
            adjustmentsExpanded = true
            focalX = 0.5
            focalY = 0.5
            status = "预览已更新，保存后才会用于当前尺寸。"
        case .failure(let failure): error = failure.localizedDescription
        }
    }

    func save() {
        guard !busy, image != nil else { return }
        let selectedSize = size
        let original = sourceData
        let dim = Self.clamped(darkness)
        let x = focalX
        let y = focalY
        begin(.saving)
        let io = dependencies
        io.enqueue(DispatchWorkItem {
            do {
                if let original = original {
                    try io.save(original, selectedSize, dim, x, y)
                } else {
                    try io.updateDarkness(selectedSize, dim)
                }
                let state = io.read(selectedSize)
                io.reload()
                DispatchQueue.main.async {
                    guard self.operation == .saving, self.size == selectedSize else { return }
                    // Preserve the editable source if read-back is temporarily unavailable.
                    if state.image != nil { self.apply(state) }
                    self.adjustmentsExpanded = false
                    self.operation = nil
                    self.status = "已保存\(selectedSize.displayName)背景。点开「调整背景」可继续编辑；已请求刷新小组件，桌面显示可能稍有延迟。"
                }
            } catch { self.finishFailure(error) }
        })
    }

    func reset() {
        guard !busy else { return }
        let selectedSize = size
        begin(.resetting)
        let io = dependencies
        io.enqueue(DispatchWorkItem {
            do {
                try io.reset(selectedSize)
                let state = io.read(selectedSize)
                io.reload()
                DispatchQueue.main.async {
                    guard self.operation == .resetting, self.size == selectedSize else { return }
                    self.apply(state)
                    self.adjustmentsExpanded = false
                    self.operation = nil
                    self.status = "已恢复\(selectedSize.displayName)默认背景，并请求刷新。桌面显示可能稍有延迟。"
                }
            } catch { self.finishFailure(error) }
        })
    }

    private func apply(_ state: WidgetBackgroundStore.EditorState) {
        image = state.sourceImage ?? state.image
        sourceData = state.sourceData
        focalX = state.focalX
        focalY = state.focalY
        darkness = Self.clamped(state.darkness)
    }

    private func begin(_ operation: Operation) {
        loadID = UUID()
        loadWork?.cancel()
        loadWork = nil
        self.operation = operation
        status = nil
        error = nil
    }

    private func finishFailure(_ failure: Error) {
        DispatchQueue.main.async {
            self.operation = nil
            self.error = failure.localizedDescription
        }
    }

    private static func clamped(_ value: Double) -> Double {
        value.isFinite ? min(1, max(0, value)) : 0.35
    }
}

struct WidgetAppearancePhoto {
    let data: Data
    let preview: UIImage
}
