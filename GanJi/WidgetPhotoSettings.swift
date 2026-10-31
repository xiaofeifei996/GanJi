import SwiftUI
import PhotosUI
import WidgetKit
import UIKit

private let widgetPhotoGroupID = "group.com.ganji.diary"

private enum WidgetPhotoSlot: String, CaseIterable, Identifiable {
    case small
    case medium
    case large

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
        case .small: return "适合突出日期和今日集市"
        case .medium: return "适合横向照片与三日安排"
        case .large: return "适合展示完整照片和行程"
        }
    }
    var fileName: String { "GanJiWidgetPhoto-\(rawValue).jpg" }
    var image: UIImage? {
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: widgetPhotoGroupID) else { return nil }
        return UIImage(contentsOfFile: container.appendingPathComponent(fileName).path)
    }
    func removeImage() {
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: widgetPhotoGroupID) else { return }
        try? FileManager.default.removeItem(at: container.appendingPathComponent(fileName))
    }
}

struct WidgetPhotoSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var activeSlot: WidgetPhotoSlot?
    @State private var refreshID = UUID()

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("为每种尺寸选择不同的照片。更换后会自动刷新桌面小组件。")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .padding(.bottom, 4)

                    ForEach(WidgetPhotoSlot.allCases) { slot in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(slot.title)
                                    .font(.system(size: 17, weight: .bold))
                                Spacer()
                                Text(slot.detail)
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }

                            ZStack {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.secondary.opacity(0.12))
                                if let image = slot.image {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(height: 132)
                                        .frame(maxWidth: .infinity)
                                        .clipped()
                                        .clipShape(RoundedRectangle(cornerRadius: 16))
                                } else {
                                    VStack(spacing: 7) {
                                        Image(systemName: "photo")
                                            .font(.system(size: 28))
                                        Text("使用默认集市照片")
                                            .font(.system(size: 12, weight: .medium))
                                    }
                                    .foregroundColor(.secondary)
                                    .frame(height: 132)
                                }
                            }
                            .frame(height: 132)

                            HStack(spacing: 10) {
                                Button {
                                    activeSlot = slot
                                } label: {
                                    Label(slot.image == nil ? "从相册选择" : "更换照片", systemImage: "photo.on.rectangle")
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 11)
                                        .background(Color.ganjiBlue, in: RoundedRectangle(cornerRadius: 12))
                                        .foregroundColor(.white)
                                }
                                Button {
                                    slot.removeImage()
                                    refreshID = UUID()
                                    WidgetCenter.shared.reloadAllTimelines()
                                } label: {
                                    Label("恢复默认", systemImage: "arrow.counterclockwise")
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 11)
                                        .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                                        .foregroundColor(.primary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(14)
                        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
                    }

                    Text("照片只保存在本机 App Group 共享空间，不会上传到服务器。")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 4)
                }
                .padding(16)
            }
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
                refreshID = UUID()
                WidgetCenter.shared.reloadAllTimelines()
                activeSlot = nil
            }
        }
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

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let slot: WidgetPhotoSlot
        let onFinished: () -> Void

        init(slot: WidgetPhotoSlot, onFinished: @escaping () -> Void) {
            self.slot = slot
            self.onFinished = onFinished
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard let provider = results.first?.itemProvider,
                  provider.canLoadObject(ofClass: UIImage.self) else {
                picker.dismiss(animated: true) { self.onFinished() }
                return
            }

            provider.loadObject(ofClass: UIImage.self) { [slot, onFinished] object, _ in
                guard let image = object as? UIImage,
                      let data = image.jpegData(compressionQuality: 0.88),
                      let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: widgetPhotoGroupID) else {
                    DispatchQueue.main.async {
                        picker.dismiss(animated: true) { onFinished() }
                    }
                    return
                }

                let destination = container.appendingPathComponent(slot.fileName)
                do {
                    try data.write(to: destination, options: .atomic)
                } catch {
                    // Keep the previous selection if writing the new image fails.
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
