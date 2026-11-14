import SwiftUI
import UIKit
import PhotosUI
import ImageIO
import UniformTypeIdentifiers
import WidgetKit

/// Present with `.sheet { WidgetAppearanceView() }`.
public struct WidgetAppearanceView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var editor = WidgetAppearanceEditor()
    @State private var showingPicker = false
    @State private var confirmingReset = false
    private let accent = Color(red: 0.16, green: 0.39, blue: 0.32)

    public init() {}

    public var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("让赶集日历，也有你的风景")
                            .font(.title3.weight(.semibold))
                        Text("三种尺寸分别设置，只保存当前选中的尺寸。系统染色或透明外观可能隐藏照片，查看原图请使用全彩外观。")
                            .font(.footnote).foregroundColor(.secondary)
                    }
                    Picker("小组件尺寸", selection: $editor.size) {
                        ForEach(WidgetPhotoSize.allCases) { size in
                            Text(size.displayName).tag(size)
                        }
                    }
                    .pickerStyle(.segmented)
                    .disabled(editor.busy || showingPicker)
                    .onChange(of: editor.size) { _ in editor.load() }

                    VStack(spacing: 12) {
                        WidgetAppearancePreview(size: editor.size, image: editor.image,
                                                darkness: editor.darkness,
                                                focalX: editor.focalX, focalY: editor.focalY)
                            .aspectRatio(editor.size.aspectRatio, contentMode: .fit)
                            .frame(maxWidth: editor.size == .small ? 180 : 340)
                            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(.white.opacity(0.4)))
                            .shadow(color: .black.opacity(0.09), radius: 12, y: 5)
                            .frame(maxWidth: .infinity)
                        Text("真实布局 · 示例圩点")
                            .font(.caption).foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)

                    VStack(alignment: .leading, spacing: 18) {
                        Button { showingPicker = true } label: {
                            Label(editor.image == nil ? "选择背景照片" : "更换背景照片", systemImage: "photo.on.rectangle")
                                .font(.body.weight(.semibold))
                                .frame(maxWidth: .infinity).padding(.vertical, 4)
                        }
                        .disabled(editor.busy)
                        if editor.image != nil {
                            Divider()
                            DisclosureGroup("调整背景", isExpanded: $editor.adjustmentsExpanded) {
                                VStack(alignment: .leading, spacing: 18) {
                                    if editor.sourceData != nil {
                                        adjustment("水平取景", value: $editor.focalX, leading: "偏左", trailing: "偏右")
                                        adjustment("垂直取景", value: $editor.focalY, leading: "偏上", trailing: "偏下")
                                        Text("照片自动铺满画面；某个方向没有多余画面时，调整该方向不会移动。保存后可再次展开调整，重新打开页面也会保留取景参数。")
                                            .font(.caption).foregroundColor(.secondary)
                                    } else {
                                        Text("这张旧版背景只保存了裁剪图，仍可调整压暗。若要改变取景，请重新选择原照片；原先裁掉的画面无法恢复。")
                                            .font(.caption).foregroundColor(.secondary)
                                    }
                                    adjustment("背景压暗", value: $editor.darkness, leading: "原图", trailing: "更暗")
                                }
                                .padding(.top, 14)
                            }
                            .font(.body.weight(.semibold))
                        } else {
                            Text("当前使用默认背景。选择一张照片，让文字与风景相伴。")
                                .font(.footnote).foregroundColor(.secondary)
                        }
                    }
                    .padding(18)
                    .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
                    .disabled(editor.busy)

                    VStack(spacing: 12) {
                        Button { editor.save() } label: {
                            HStack(spacing: 8) {
                                if editor.busy { ProgressView().tint(.white) }
                                Text(editor.busy ? editor.activity : "保存\(editor.size.displayName)背景")
                            }
                            .font(.body.weight(.semibold))
                            .frame(maxWidth: .infinity).padding(.vertical, 14)
                            .foregroundColor(.white)
                            .background(accent, in: RoundedRectangle(cornerRadius: 15))
                        }
                        .disabled(editor.busy || editor.image == nil)
                        .opacity(editor.image == nil && !editor.busy ? 0.5 : 1)
                        Button("恢复\(editor.size.displayName)默认背景", role: .destructive) {
                            confirmingReset = true
                        }
                        .font(.subheadline).disabled(editor.busy)
                        if let status = editor.status {
                            Text(status).font(.footnote).foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        Text("切换尺寸或关闭页面会放弃未保存的调整。")
                            .font(.caption).foregroundColor(.secondary)
                    }
                }
                .padding(20)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("小组件外观")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }.disabled(editor.busy)
                }
            }
            .tint(accent)
        }
        .navigationViewStyle(.stack)
        .interactiveDismissDisabled(editor.busy)
        .onAppear { if !editor.loaded { editor.load() } }
        .sheet(isPresented: $showingPicker) {
            WidgetAppearancePhotoPicker(onCancel: { showingPicker = false }, onStart: {
                editor.beginPhotoImport()
                showingPicker = false
            }, onResult: { editor.finishPhotoImport($0) })
        }
        .confirmationDialog("恢复\(editor.size.displayName)默认背景？", isPresented: $confirmingReset, titleVisibility: .visible) {
            Button("恢复默认", role: .destructive) { editor.reset() }
            Button("取消", role: .cancel) {}
        } message: {
            Text("只清除这个尺寸的照片背景，其他尺寸不受影响。")
        }
        .alert("暂时无法完成", isPresented: Binding(get: { editor.error != nil }, set: { if !$0 { editor.error = nil } })) {
            Button("好", role: .cancel) { editor.error = nil }
        } message: { Text(editor.error ?? "请稍后重试。") }
    }

    private func adjustment(_ title: String, value: Binding<Double>, leading: String, trailing: String) -> some View {
        VStack(spacing: 6) {
            HStack {
                Text(title).font(.subheadline.weight(.medium))
                Spacer()
                Text("\(Int((value.wrappedValue * 100).rounded()))%")
                    .font(.caption.monospacedDigit()).foregroundColor(.secondary)
            }
            Slider(value: Binding(get: { value.wrappedValue }, set: {
                value.wrappedValue = $0
                editor.status = "有未保存的调整，仅影响当前尺寸的预览。"
            }), in: 0...1)
                .accessibilityLabel(title)
                .accessibilityValue("\(Int((value.wrappedValue * 100).rounded()))%")
            HStack {
                Text(leading)
                Spacer()
                Text(trailing)
            }.font(.caption2).foregroundColor(.secondary)
        }
    }
}

private final class WidgetAppearanceEditor: ObservableObject {
    @Published var size: WidgetPhotoSize = .small
    @Published var image: UIImage?
    @Published var sourceData: Data?
    @Published var adjustmentsExpanded = false
    @Published var focalX = 0.5
    @Published var focalY = 0.5
    @Published var darkness = 0.25
    @Published var busy = false
    @Published var activity = "正在读取…"
    @Published var status: String?
    @Published var error: String?
    var loaded = false

    func load() {
        guard !busy else { return }
        begin("正在读取…")
        let selectedSize = size
        // Discard every transient edit when changing families, including imported data.
        image = nil
        sourceData = nil
        focalX = 0.5
        focalY = 0.5
        adjustmentsExpanded = false
        DispatchQueue.global(qos: .userInitiated).async {
            let state = WidgetBackgroundStore.editorState(for: selectedSize)
            DispatchQueue.main.async {
                self.apply(state)
                self.loaded = true
                self.busy = false
            }
        }
    }

    func beginPhotoImport() { begin("正在导入照片…") }

    func finishPhotoImport(_ result: Result<WidgetAppearancePhoto, Error>) {
        busy = false
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
        begin("正在保存…")
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                if let original = original {
                    try WidgetBackgroundStore.save(imageData: original, for: selectedSize,
                                                   darkness: dim, focalX: x, focalY: y)
                } else {
                    try WidgetBackgroundStore.updateDarkness(for: selectedSize, darkness: dim)
                }
                let state = WidgetBackgroundStore.editorState(for: selectedSize)
                WidgetCenter.shared.reloadAllTimelines()
                DispatchQueue.main.async {
                    // Keep the current editable source if a subsequent read is temporarily unavailable.
                    if state.image != nil { self.apply(state) }
                    self.adjustmentsExpanded = false
                    self.busy = false
                    self.status = "已保存\(selectedSize.displayName)背景。点开「调整背景」可继续编辑；已请求刷新小组件，桌面显示可能稍有延迟。"
                }
            } catch { self.finishFailure(error) }
        }
    }

    func reset() {
        guard !busy else { return }
        let selectedSize = size
        begin("正在恢复…")
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try WidgetBackgroundStore.reset(for: selectedSize)
                let dim = WidgetBackgroundStore.darkness(for: selectedSize)
                WidgetCenter.shared.reloadAllTimelines()
                DispatchQueue.main.async {
                    self.image = nil
                    self.sourceData = nil
                    self.focalX = 0.5
                    self.focalY = 0.5
                    self.darkness = Self.clamped(dim)
                    self.busy = false
                    self.status = "已恢复\(selectedSize.displayName)默认背景，并请求刷新。桌面显示可能稍有延迟。"
                }
            } catch { self.finishFailure(error) }
        }
    }

    private func apply(_ state: WidgetBackgroundStore.EditorState) {
        image = state.sourceImage ?? state.image
        sourceData = state.sourceData
        focalX = state.focalX
        focalY = state.focalY
        darkness = Self.clamped(state.darkness)
    }

    private func begin(_ label: String) {
        busy = true
        activity = label
        status = nil
        error = nil
    }

    private func finishFailure(_ failure: Error) {
        DispatchQueue.main.async {
            self.busy = false
            self.error = failure.localizedDescription
        }
    }

    private static func clamped(_ value: Double) -> Double {
        value.isFinite ? min(1, max(0, value)) : 0.25
    }
}

/// Deliberately uses sample text rather than loading live market/location data.
private struct WidgetAppearancePreview: View {
    let size: WidgetPhotoSize
    let image: UIImage?
    let darkness: Double
    let focalX: Double
    let focalY: Double
    private let ink = Color(red: 0.15, green: 0.27, blue: 0.23)

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if let image = image {
                    let scale = max(geometry.size.width / max(1, image.size.width),
                                    geometry.size.height / max(1, image.size.height))
                    let width = image.size.width * scale
                    let height = image.size.height * scale
                    let offsetX = max(0, min(width - geometry.size.width,
                                             CGFloat(focalX) * width - geometry.size.width / 2))
                    let offsetY = max(0, min(height - geometry.size.height,
                                             CGFloat(focalY) * height - geometry.size.height / 2))
                    Color.black // Match the store's backing for transparent photos.
                    Image(uiImage: image)
                        .resizable()
                        .frame(width: width, height: height)
                        .position(x: width / 2 - offsetX, y: height / 2 - offsetY)
                    Color.black.opacity(darkness)
                } else {
                    LinearGradient(colors: [Color(red: 0.16, green: 0.32, blue: 0.31),
                                            Color(red: 0.04, green: 0.12, blue: 0.16)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                }
                LinearGradient(colors: [.black.opacity(0.05), .black.opacity(0.48)],
                               startPoint: .top, endPoint: .bottom)
                previewText
                    .frame(width: geometry.size.width, height: geometry.size.height)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(size.displayName)小组件背景预览，示例赶集日历")
    }

    @ViewBuilder private var previewText: some View {
        let entry = GanJiEntry.sample()
        Group {
            switch size {
            case .small: SealBoard(entry: entry)
            case .medium: StripBoard(entry: entry)
            case .large: AlmanacBoard(entry: entry)
            }
        }.foregroundStyle(.white)
    }
}

private struct WidgetAppearanceFailure: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}

private struct WidgetAppearancePhoto {
    let data: Data
    let preview: UIImage
}

private struct WidgetAppearancePhotoPicker: UIViewControllerRepresentable {
    let onCancel: () -> Void
    let onStart: () -> Void
    let onResult: (Result<WidgetAppearancePhoto, Error>) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIViewController(context: Context) -> PHPickerViewController {
        // The system picker grants access only to the selected file. No library
        // authorization request or PHPhotoLibrary access is needed.
        var configuration = PHPickerConfiguration()
        configuration.filter = .images
        configuration.selectionLimit = 1
        configuration.preferredAssetRepresentationMode = .current
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        private let parent: WidgetAppearancePhotoPicker
        private var finished = false
        private static let byteLimit = 40 * 1024 * 1024

        init(parent: WidgetAppearancePhotoPicker) { self.parent = parent }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard !finished else { return }
            finished = true
            guard let provider = results.first?.itemProvider else {
                parent.onCancel()
                return
            }
            let start = parent.onStart
            let completion = parent.onResult
            start()
            // Start outside the main queue; NSItemProvider calls its file handler
            // on a background queue. Its temporary URL is valid ONLY in that handler.
            DispatchQueue.global(qos: .userInitiated).async {
                provider.loadFileRepresentation(forTypeIdentifier: UTType.image.identifier) { url, error in
                    let result: Result<WidgetAppearancePhoto, Error> = autoreleasepool {
                        do {
                            if let error = error { throw error }
                            guard let url = url else {
                                throw WidgetAppearanceFailure("未能读取照片，请重试。若照片在 iCloud，请先确认网络可用。")
                            }
                            let metadata = try url.resourceValues(forKeys: [.fileSizeKey])
                            if let count = metadata.fileSize, count > Self.byteLimit {
                                throw WidgetAppearanceFailure("照片超过 40 MB，请选择较小的图片。")
                            }
                            let handle = try FileHandle(forReadingFrom: url)
                            defer { try? handle.close() }
                            // A bounded loop also handles unavailable/stale file-size
                            // metadata and short reads without allocating the full file.
                            var data = Data()
                            while data.count <= Self.byteLimit {
                                let count = min(1024 * 1024, Self.byteLimit + 1 - data.count)
                                guard let chunk = try handle.read(upToCount: count), !chunk.isEmpty else { break }
                                data.append(chunk)
                            }
                            guard data.count <= Self.byteLimit else {
                                throw WidgetAppearanceFailure("照片超过 40 MB，请选择较小的图片。")
                            }
                            guard !data.isEmpty,
                                  let source = CGImageSourceCreateWithData(data as CFData,
                                      [kCGImageSourceShouldCache: false] as CFDictionary),
                                  let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                                      kCGImageSourceCreateThumbnailFromImageAlways: true,
                                      kCGImageSourceCreateThumbnailWithTransform: true,
                                      kCGImageSourceThumbnailMaxPixelSize: 1400,
                                      kCGImageSourceShouldCacheImmediately: true
                                  ] as CFDictionary) else {
                                throw WidgetAppearanceFailure("无法预览这张照片，请选择 JPEG、PNG 或 HEIC 图片。")
                            }
                            return .success(WidgetAppearancePhoto(data: data, preview: UIImage(cgImage: thumbnail)))
                        } catch { return .failure(error) }
                    }
                    DispatchQueue.main.async { completion(result) }
                }
            }
        }
    }
}
