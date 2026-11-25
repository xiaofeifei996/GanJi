import Foundation

@main struct WidgetSharedStorageTests {
    static func main() throws {
        var checks = 0
        func expect(_ condition: Bool, _ message: String) {
            precondition(condition, message)
            checks += 1
        }
        let original = WidgetSharedStorage.defaultGroupID
        let renamed = "group.resigned.ganji"
        func ids(_ configured: [String] = [], _ profiles: [[String]] = []) -> [String] {
            WidgetSharedStorage.candidates(configured: configured, profiles: profiles)
        }
        expect(ids() == [original], "Unprovisioned legacy installs retain the original group")
        expect(ids([renamed]) == [renamed, original], "Explicit build configuration takes priority")
        expect(ids([original, original]) == [original], "No duplicate lookups")
        expect(ids(["", "*", "group.*", "private", "group.", "group.bad/path"]) == [original],
               "Reject malformed group IDs")
        expect(ids([], [[renamed], [renamed]]) == [original, renamed], "Discover renamed shared group")
        expect(ids([], [[renamed, "group.app.only"], [renamed]]) == [original, renamed],
               "Only the intersection can be discovered")
        expect(ids([], [["group.app.only"], ["group.widget.only"]]) == [original],
               "Never guess across mismatched profiles")
        expect(ids([], [[renamed], []]) == [original], "Missing widget authorization must not be inferred")
        expect(ids([], [[renamed, "group.other"], [renamed, "group.other"]]) == [original],
               "Multiple common groups require explicit configuration")
        expect(ids([renamed], [[renamed], [renamed]]) == [renamed, original], "Deduplicate discovery")
        expect(ids([], [["group.*"], ["group.*"]]) == [original], "Wildcards are not containers")
        expect(ids([], [[renamed], [renamed], []]) == [original], "Every widget participates")

        var lookups = [String]()
        let url = URL(fileURLWithPath: "/test/shared")
        let resolved = WidgetSharedStorage.resolve(candidates: [original, renamed]) { id in
            lookups.append(id)
            return id == renamed ? url : nil
        }
        expect(resolved?.id == renamed && resolved?.url == url, "Skip unavailable default group")
        expect(lookups == [original, renamed], "Stable lookup order in app and widget")
        expect(WidgetSharedStorage.resolve(candidates: [original], lookup: { _ in nil }) == nil,
               "Denied groups do not become private fallbacks")
        expect(WidgetSharedStorage.resolve(candidates: [], lookup: { _ in url }) == nil,
               "No candidates means no container")

        func profile(_ entitlements: [String: Any]) throws -> Data {
            let plist = try PropertyListSerialization.data(fromPropertyList: ["Entitlements": entitlements],
                                                           format: .xml, options: 0)
            return Data([0x30, 0x82, 0, 0]) + plist + Data([0, 0xff])
        }
        let key = "com.apple.security.application-groups"
        expect(WidgetSharedStorage.profileGroups(try profile([key: [renamed]])) == [renamed],
               "Discover group from CMS-wrapped XML without trusting it")
        expect(WidgetSharedStorage.profileGroups(try profile([:])) == [], "No group entitlement stays empty")
        expect(WidgetSharedStorage.profileGroups(try profile([key: renamed])) == [], "Reject non-array group value")
        expect(WidgetSharedStorage.profileGroups(Data()) == nil, "Reject empty profile")
        expect(WidgetSharedStorage.profileGroups(Data("<?xml incomplete".utf8)) == nil, "Reject truncation")
        expect(WidgetSharedStorage.profileGroups(Data(repeating: 0, count: 1024 * 1024 + 1)) == nil,
               "Bound profile input")
        expect(WidgetSharedStorage.sharingHelpContainsNoFalseSuccess, "Help explains signature constraints")
        print("WidgetSharedStorageTests: \(checks) checks passed")
    }
}

private extension WidgetSharedStorage {
    static var sharingHelpContainsNoFalseSuccess: Bool {
        signingHelp.contains("主 App 和小组件") && signingHelp.contains("描述文件")
    }
}
