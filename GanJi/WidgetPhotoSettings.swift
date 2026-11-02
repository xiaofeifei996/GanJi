import SwiftUI
import PhotosUI
import WidgetKit
import UIKit

// 全新实现：App 内的相册选择，写真实照片到 App Group。
private let photoGroupID = "group.com.ganji.diary"

struct PhotoSlot: Identifiable {
    enum Kind: String, CaseIterable { case small, medium, large }
    let kind: Kind
    var id: String { kind.rawValue }
    var title: String {
        switch kind {
        case .small: return "小号"
        case .medium: return "中号"
        case .large: return "大号"
        }
    }
    var fileName: String { "GanJiWidgetPhoto-\(kind.rawValue).jpg" }
}

struct BackdropPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    var onPick: (PhotoSlot.Kind) -> Void

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 12) {
                    Text("为三种尺寸各选一张真实照片作为小组件背景。")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    ForEach(PhotoSlot.Kind.allCases, id: \.self) { kind in
                        BackdropSlotCard(kind: kind, onPick: { onPick(kind) })
                    }
                    Text("照片仅保存在本机 App Group 共享空间，不会上传。")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .padding(16)
            }
            .navigationTitle("小组件背景")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } }
            }
        }
    }
}

private struct BackdropSlotCard: View {
    let kind: PhotoSlot.Kind
    let onPick: () -> Void

    private var image: UIImage? {
        guard let dir = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: photoGroupID) else { return nil }
        return UIImage(contentsOfFile: dir.appendingPathComponent("GanJiWidgetPhoto-\(kind.rawValue).jpg").path)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(kind == .small ? "小号小组件" : kind == .medium ? "中号小组件" : "大号小组件")
                    .font(.system(size: 17, weight: .bold))
                Spacer()
            }
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
                    .frame(maxWidth: .infinity).frame(height: 120).clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            } else {
                Label("尚未选择照片", systemImage: "photo")
                    .frame(maxWidth: .infinity).frame(height: 120)
                    .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
            }
            Button(action: onPick) {
                Label(image == nil ? "从相册选择" : "更换照片", systemImage: "photo.on.rectangle")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color(red: 0.16, green: 0.43, blue: 0.94), in: RoundedRectangle(cornerRadius: 12))
                    .foregroundColor(.white)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
    }
}

/// 在 App 根上常驻的 UIKit 相册宿主，避免 SwiftUI sheet 嵌套导致的选择器失效。
struct PhotoPickerHost: UIViewControllerRepresentable {
    @Binding var active: PhotoSlot.Kind?
    var done: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(active: $active, done: done) }

    func makeUIViewController(context: Context) -> Host {
        let host = Host()
        host.onAppear = { [weak coordinator = context.coordinator] h in
            coordinator?.present(from: h)
        }
        return host
    }

    func updateUIViewController(_ controller: Host, context: Context) {
        context.coordinator.active = $active
        context.coordinator.done = done
        context.coordinator.host = controller
        context.coordinator.present(from: controller)
    }

    final class Host: UIViewController {
        var onAppear: ((UIViewController) -> Void)?
        override func viewDidAppear(_ animated: Bool) { super.viewDidAppear(animated); onAppear?(self) }
    }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        var active: Binding<PhotoSlot.Kind?>
        var done: () -> Void
        weak var host: UIViewController?
        private var presenting = false
        private var picker: PHPickerViewController?
        private var current: PhotoSlot.Kind?

        init(active: Binding<PhotoSlot.Kind?>, done: @escaping () -> Void) {
            self.active = active
            self.done = done
        }

        func present(from host: UIViewController) {
            guard !presenting, let kind = active.wrappedValue,
                  let window = host.viewIfLoaded?.window,
                  let root = window.rootViewController else { return }
            var top = root
            while let next = top.presentedViewController { top = next }
            guard !(top is PHPickerViewController), top.viewIfLoaded?.window != nil else { return }

            presenting = true
            current = kind
            var config = PHPickerConfiguration(photoLibrary: .shared())
            config.filter = .images
            config.selectionLimit = 1
            let controller = PHPickerViewController(configuration: config)
            controller.delegate = self
            picker = controller
            active.wrappedValue = nil
            top.present(controller, animated: true)
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard let provider = results.first?.itemProvider,
                  provider.canLoadObject(ofClass: UIImage.self) else {
                finish(picker); return
            }
            provider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
                guard let self else { return }
                let data = (object as? UIImage)?.jpegData(compressionQuality: 0.88)
                if let data, let kind = self.current,
                   let dir = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: photoGroupID) {
                    try? data.write(to: dir.appendingPathComponent("GanJiWidgetPhoto-\(kind.rawValue).jpg"), options: .atomic)
                }
                DispatchQueue.main.async { self.finish(picker) }
            }
        }

        private func finish(_ picker: PHPickerViewController) {
            picker.dismiss(animated: true) { [weak self] in
                guard let self else { return }
                self.picker = nil
                self.presenting = false
                self.current = nil
                WidgetCenter.shared.reloadAllTimelines()
                self.done()
                if let host = self.host { DispatchQueue.main.async { self.present(from: host) } }
            }
        }
    }
}
