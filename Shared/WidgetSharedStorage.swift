import Foundation

/// One resolver for both processes. A profile is a discovery hint, never a grant:
/// FileManager and the installed code signature remain the authority for access.
enum WidgetSharedStorage {
    static let defaultGroupID = "group.com.ganji.diary"
    static let configurationKey = "GanJiAppGroupID"
    static let legacyDirectory = "/var/mobile/Library/GanJi"
    static let signingHelp = "请用支持 App Groups 的签名配置重新签名：主 App 和小组件扩展必须保留同一个共享组，并各自使用包含该组的描述文件。仅添加路径权限、重新选择照片或刷新小组件无法修复签名权限。"

    struct GroupContainer {
        let id: String
        let url: URL
    }

    static var container: GroupContainer? {
        resolve(candidates: installedCandidates) {
            FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: $0)
        }
    }

    /// Never fall back to a private directory and report it as widget sync.
    static var directories: [URL] {
        var result = container.map { [$0.url] } ?? []
        result.append(URL(fileURLWithPath: legacyDirectory, isDirectory: true))
        return result
    }

    static var sharingIssue: String? {
        if container != nil { return nil }
        // Existing TrollStore installations can continue using their legacy files.
        if FileManager.default.isWritableFile(atPath: legacyDirectory) { return nil }
        return "未取得小组件共享目录，背景可预览但可能无法同步。请检查重签名是否为主 App 和小组件保留了同一个 App Group 及各自描述文件。"
    }

    static func resolve(candidates: [String], lookup: (String) -> URL?) -> GroupContainer? {
        for id in candidates {
            if let url = lookup(id) { return GroupContainer(id: id, url: url) }
        }
        return nil
    }

    /// Re-signers may rename groups. Only auto-discover a single common group;
    /// guessing among unrelated groups could split the app and widget's storage.
    static func candidates(configured: [String], profiles: [[String]]) -> [String] {
        var result = [String]()
        func append(_ id: String) {
            guard id.hasPrefix("group."), id.count > 6,
                  !id.contains("*"), !id.contains("/"),
                  !result.contains(id) else { return }
            result.append(id)
        }
        configured.forEach(append)
        append(defaultGroupID)
        if profiles.count > 1, let first = profiles.first {
            let common = profiles.dropFirst().reduce(Set(first)) { $0.intersection($1) }
            let valid = common.filter { $0.hasPrefix("group.") && !$0.contains("*") && !$0.contains("/") }
            if valid.count == 1, let id = valid.first { append(id) }
        }
        return result
    }

    /// A bounded XML extraction from Apple's CMS-wrapped mobileprovision.
    /// No trust is placed in these bytes; OS container lookup still enforces access.
    static func profileGroups(_ data: Data) -> [String]? {
        guard data.count <= 1024 * 1024,
              let start = data.range(of: Data("<?xml".utf8)),
              let end = data.range(of: Data("</plist>".utf8), in: start.lowerBound..<data.endIndex),
              let plist = try? PropertyListSerialization.propertyList(
                from: data.subdata(in: start.lowerBound..<end.upperBound), options: [], format: nil) as? [String: Any],
              let entitlements = plist["Entitlements"] as? [String: Any] else { return nil }
        return entitlements["com.apple.security.application-groups"] as? [String] ?? []
    }

    private static let installedCandidates: [String] = {
        let current = Bundle.main
        let appURL: URL
        if current.bundleURL.pathExtension == "appex",
           current.bundleURL.deletingLastPathComponent().lastPathComponent == "PlugIns" {
            appURL = current.bundleURL.deletingLastPathComponent().deletingLastPathComponent()
        } else { appURL = current.bundleURL }
        let app = Bundle(url: appURL) ?? current
        let plugins = appURL.appendingPathComponent("PlugIns", isDirectory: true)
        let urls = (try? FileManager.default.contentsOfDirectory(at: plugins,
            includingPropertiesForKeys: nil)) ?? []
        let widgets = urls.compactMap { Bundle(url: $0) }.filter {
            ($0.infoDictionary?["NSExtension"] as? [String: Any])?["NSExtensionPointIdentifier"] as? String == "com.apple.widgetkit-extension"
        }.sorted { $0.bundleURL.path < $1.bundleURL.path }
        let bundles = [app] + widgets
        // Both processes inspect exactly the same bundles and candidate order.
        let configured = bundles.compactMap { $0.object(forInfoDictionaryKey: configurationKey) as? String }
        let profiles: [[String]] = bundles.map { bundle in
            let url = bundle.bundleURL.appendingPathComponent("embedded.mobileprovision")
            guard let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize,
                  size <= 1024 * 1024, let data = try? Data(contentsOf: url) else { return [] }
            return profileGroups(data) ?? []
        }
        return candidates(configured: configured, profiles: profiles)
    }()
}
