import SwiftUI
import UIKit
import PhotosUI
import ImageIO
import UniformTypeIdentifiers
import WidgetKit

/// Present with `.sheet { WidgetAppearanceView() }`.
public struct WidgetAppearanceView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var editor = WidgetAppearanceEditor()
    @StateObject private var snapshot = WidgetAppearanceSnapshot()
    @State private var visible = false
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
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            if !editor.sharingChecked || editor.checkingSharing {
                                ProgressView().controlSize(.small)
                            }
                            Label(
                                !editor.sharingChecked || editor.checkingSharing ? "正在检查共享目录…" :
                                    (editor.sharingIssue == nil ? "检测到共享目录" : "共享目录不可用"),
                                systemImage: !editor.sharingChecked || editor.checkingSharing ? "icloud" :
                                    (editor.sharingIssue == nil ? "checkmark.icloud" : "exclamationmark.icloud")
                            )
                            .font(.footnote.weight(.medium))
                            .foregroundColor(editor.sharingIssue == nil ? .secondary : .orange)
                            .accessibilityIdentifier("widgetAppearance.sharingStatus")
                            Spacer(minLength: 4)
                            Button {
                                editor.refreshSharingIssue()
                            } label: {
                                Text(editor.checkingSharing ? "检查中" : "重新检查")
                                    .font(.footnote.weight(.medium))
                            }
                            .disabled(!editor.sharingChecked || editor.checkingSharing || editor.busy)
                        }
                        if let issue = editor.sharingIssue {
                            Text(issue)
                                .font(.footnote).foregroundColor(.secondary)
                                .accessibilityIdentifier("widgetAppearance.sharingIssue")
                        }
                        Text("保存时会再进行实际写入与回读验证；检测到目录不代表桌面组件已完成刷新。")
                            .font(.caption).foregroundColor(.secondary)
                    }
                    .padding(12)
                    .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
                    Picker("小组件尺寸", selection: Binding(get: { editor.size }, set: { editor.select($0) })) {
                        ForEach(WidgetPhotoSize.allCases) { size in
                            Text(size.displayName).tag(size)
                        }
                    }
                    .pickerStyle(.segmented)
                    .disabled(editor.isPerformingOperation || showingPicker || confirmingReset)
                    .accessibilityIdentifier("widgetAppearance.size")

                    VStack(spacing: 12) {
                        WidgetAppearancePreview(entry: snapshot.entry, size: editor.size, image: editor.image,
                                                darkness: editor.darkness,
                                                focalX: editor.focalX, focalY: editor.focalY)
                            .aspectRatio(editor.size.aspectRatio, contentMode: .fit)
                            .frame(maxWidth: editor.size == .small ? 180 : 340)
                            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(.white.opacity(0.4)))
                            .shadow(color: .black.opacity(0.09), radius: 12, y: 5)
                            .frame(maxWidth: .infinity)
                            // Clipping does not limit SwiftUI hit testing for oversized images.
                            .allowsHitTesting(false)
                        Text("与小组件相同的收藏圩日")
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
                    Button("完成") { dismiss() }.disabled(editor.isPerformingOperation)
                }
            }
            .tint(accent)
        }
        .navigationViewStyle(.stack)
        .interactiveDismissDisabled(editor.isPerformingOperation)
        .onAppear {
            visible = true
            if !editor.loaded { editor.load() }
            snapshot.start()
        }
        .onDisappear {
            visible = false
            snapshot.stop()
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active && visible {
                snapshot.start()
                editor.refreshSharingIssue()
            } else { snapshot.stop() }
        }
        .onReceive(NotificationCenter.default.publisher(for: WidgetFeed.didChange).receive(on: DispatchQueue.main)) { _ in
            snapshot.refresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
            snapshot.refresh()
        }
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

/// Production board content over the editable photo crop; the snapshot is loaded separately.
private struct WidgetAppearancePreview: View {
    let entry: GanJiEntry?
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
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(size.displayName)小组件背景预览，收藏圩日")
    }

    @ViewBuilder private var previewText: some View {
        Group {
            if let entry = entry {
                WidgetBoardContent(entry: entry, size: size)
            } else {
                ProgressView("正在读取收藏圩日…").tint(.white)
            }
        }.foregroundStyle(.white)
    }
}

private struct WidgetAppearanceFailure: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
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
