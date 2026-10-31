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
    @State private var refreshToken = 0
    @State private var smallSelection: PhotosPickerItem?
    @State private var mediumSelection: PhotosPickerItem?
    @State private var largeSelection: PhotosPickerItem?

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
        .onChange(of: smallSelection) { item in savePhoto(item, for: .small) }
        .onChange(of: mediumSelection) { item in savePhoto(item, for: .medium) }
        .onChange(of: largeSelection) { item in savePhoto(item, for: .large) }
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
        WidgetPhotoSlotCard(slot: .small, refreshToken: refreshToken, selection: $smallSelection, onReset: reset(.small))
    }

    private var mediumCard: some View {
        WidgetPhotoSlotCard(slot: .medium, refreshToken: refreshToken, selection: $mediumSelection, onReset: reset(.medium))
    }

    private var largeCard: some View {
        WidgetPhotoSlotCard(slot: .large, refreshToken: refreshToken, selection: $largeSelection, onReset: reset(.large))
    }

    private var privacyNote: some View {
        Text("照片只保存在本机 App Group 共享空间，不会上传到服务器。")
            .font(.system(size: 12))
            .foregroundColor(.secondary)
            .padding(.horizontal, 4)
    }

    private func savePhoto(_ item: PhotosPickerItem?, for slot: WidgetPhotoSlot) {
        guard let item else { return }
        Task {
            do {
                guard let data = try await item.loadTransferable(type: Data.self),
                      let image = UIImage(data: data),
                      let jpegData = image.jpegData(compressionQuality: 0.88),
                      let directory = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: widgetPhotoGroupID) else {
                    return
                }
                let destination = directory.appendingPathComponent(slot.fileName)
                try jpegData.write(to: destination, options: .atomic)
                await MainActor.run {
                    refreshToken += 1
                    WidgetCenter.shared.reloadAllTimelines()
                    switch slot {
                    case .small: smallSelection = nil
                    case .medium: mediumSelection = nil
                    case .large: largeSelection = nil
                    }
                }
            } catch {
                await MainActor.run {
                    switch slot {
                    case .small: smallSelection = nil
                    case .medium: mediumSelection = nil
                    case .large: largeSelection = nil
                    }
                }
            }
        }
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
    @Binding var selection: PhotosPickerItem?
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
            PhotosPicker(selection: $selection, matching: .images, photoLibrary: .shared()) {
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

