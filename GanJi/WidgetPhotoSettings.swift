import SwiftUI
import PhotosUI
import WidgetKit
import UIKit

private let widgetPhotoGroupID = "group.com.ganji.diary"

private enum WidgetPhotoSlot: String, CaseIterable, Identifiable {
    case small, medium, large

    var id: String { rawValue }
    var title: String {
        switch self {
        case .small: return "小号小组件"
        case .medium: return "中号小组件"
        case .large: return "大号小组件"
        }
    }
    var detail: String {
        switch self {
        case .small: return "突出日期和今日集市"
        case .medium: return "横向照片与三日安排"
        case .large: return "完整照片和行程"
        }
    }
    var fileName: String { "GanJiWidgetPhoto-\(rawValue).jpg" }

    var image: UIImage? {
        guard let directory = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: widgetPhotoGroupID) else { return nil }
        let url = directory.appendingPathComponent(fileName)
        return UIImage(contentsOfFile: url.path)
    }

    func removeImage() {
        guard let directory = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: widgetPhotoGroupID) else { return }
        let url = directory.appendingPathComponent(fileName)
        try? FileManager.default.removeItem(at: url)
    }
}

struct WidgetPhotoSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var activeSlot: WidgetPhotoSlot?
    @State private var refreshToken = 0

    var body: some View {
        NavigationView {
            settingsList
                .background(Color(uiColor: .systemGroupedBackground))
                .navigationTitle("小组件背景")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("完成") { dismiss() }
                    }
                }
        }
        .sheet(item: $activeSlot) { slot in
            WidgetPhotoLibraryPicker(slot: slot) {
                refreshToken += 1
                WidgetCenter.shared.reloadAllTimelines()
                activeSlot = nil
            }
        }
    }

    private var settingsList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                introText
                smallCard
                mediumCard
                largeCard
                privacyNote
            }
            .padding(16)
        }
    }

    private var introText: some View {
        Text("为每种尺寸选择不同的照片。更换后会自动刷新桌面小组件。")
            .font(.system(size: 14))
            .foregroundColor(.secondary)
    }

    private var smallCard: some View {
        WidgetPhotoSlotCard(slot: .small, refreshToken: refreshToken, onPick: { activeSlot = .small }, onReset: reset(.small))
    }

    private var mediumCard: some View {
        WidgetPhotoSlotCard(slot: .medium, refreshToken: refreshToken, onPick: { activeSlot = .medium }, onReset: reset(.medium))
    }

    private var largeCard: some View {
        WidgetPhotoSlotCard(slot: .large, refreshToken: refreshToken, onPick: { activeSlot = .large }, onReset: reset(.large))
    }

    private var privacyNote: some View {
        Text("照片只保存在本机 App Group 共享空间，不会上传到服务器。")
            .font(.system(size: 12))
            .foregroundColor(.secondary)
            .padding(.horizontal, 4)
    }

    private func reset(_ slot: WidgetPhotoSlot) -> () -> Void {
        return {
            slot.removeImage()
            refreshToken += 1
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
}

private struct WidgetPhotoSlotCard: View {
    let slot: WidgetPhotoSlot
    let refreshToken: Int
    let onPick: () -> Void
    let onReset: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            titleRow
            photoPreview
            actionRow
        }
        .padding(14)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
        .id(refreshToken)
    }

    private var titleRow: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(slot.title).font(.system(size: 17, weight: .bold))
            Spacer()
            Text(slot.detail).font(.system(size: 11)).foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private var photoPreview: some View {
        if let image = slot.image {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 132)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 16))
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
        VStack(spacing: 7) {
            Image(systemName: "photo").font(.system(size: 28))
            Text("使用默认集市照片").font(.system(size: 12, weight: .medium))
        }
        .foregroundColor(.secondary)
        .frame(maxWidth: .infinity)
        .frame(height: 132)
        .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
    }

    private var actionRow: some View {
        HStack(spacing: 10) {
            Button(action: onPick) {
                Label(slot.image == nil ? "从相册选择" : "更换照片", systemImage: "photo.on.rectangle")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(Color(red: 0.16, green: 0.43, blue: 0.94), in: RoundedRectangle(cornerRadius: 12))
                    .foregroundColor(.white)
            }
            Button(action: onReset) {
                Label("恢复默认", systemImage: "arrow.counterclockwise")
                    .padding(.horizontal, 12)
                    .padding(.vertical, 11)
                    .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                    .foregroundColor(.primary)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct WidgetPhotoLibraryPicker: UIViewControllerRepresentable {
    let slot: WidgetPhotoSlot
    let onFinished: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(slot: slot, onFinished: onFinished)
    }

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .images
        configuration.selectionLimit = 1
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: PHPickerViewController, context: Context) {}

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        private let slot: WidgetPhotoSlot
        private let onFinished: () -> Void

        init(slot: WidgetPhotoSlot, onFinished: @escaping () -> Void) {
            self.slot = slot
            self.onFinished = onFinished
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard let provider = results.first?.itemProvider,
                  provider.canLoadObject(ofClass: UIImage.self) else {
                picker.dismiss(animated: true, completion: onFinished)
                return
            }

            provider.loadObject(ofClass: UIImage.self) { [slot, onFinished] object, _ in
                let image = object as? UIImage
                let data = image?.jpegData(compressionQuality: 0.88)
                let directory = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: widgetPhotoGroupID)

                if let data, let directory {
                    let destination = directory.appendingPathComponent(slot.fileName)
                    try? data.write(to: destination, options: .atomic)
                }

                DispatchQueue.main.async {
                    picker.dismiss(animated: true) {
                        WidgetCenter.shared.reloadAllTimelines()
                        onFinished()
                    }
                }
            }
        }
    }
}
