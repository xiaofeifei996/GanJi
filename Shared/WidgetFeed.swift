import Foundation

/// 小组件只需要「这条圩按什么规则开」和「它叫什么」，不需要经纬度、地址这些 App 字段。
/// 因此这里单独定义一份极小的规则模型，App 与扩展各自编译时都只依赖它。
struct MarketRule: Codable, Hashable {
    let id: String
    let name: String
    let area: String
    let repeatType: Int
    let repeatValue: [String]

    /// 圩期规则是否可判定。false 表示 App 里也只会显示「圩期待核实」，
    /// 小组件因此不把它算进任何一天的开圩列表。
    var isResolved: Bool {
        switch repeatType {
        case 6: return !repeatValue.isEmpty
        case 1, 4: return repeatValue.contains { MarketSchedule.lunarDayNumber($0) != nil }
        default: return false
        }
    }
}

/// App 写给小组件的一份快照。
///
/// 内容只有「收藏的圩点」—— 小组件从不显示整个地区的圩日。
/// `source` 用来识别旧版本写下的快照（1.4.0 曾写全区圩点），
/// 遇到不认识的来源就当作尚未同步，避免升级后突然显示一堆没收藏的圩。
struct WidgetFeed: Codable {
    /// 当前语义：只含收藏。改语义时同步递增，旧快照会被丢弃。
    static let favoriteSource = "favorites"

    var source: String
    var updatedAt: Date
    var rules: [MarketRule]

    static let appGroupID = "group.com.ganji.diary"
    static let storageKey = "GanJiWidgetFeedV1"

    static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    func publish() {
        WidgetFeedStore.write(self)
    }

    /// 只返回确实由「收藏」生成的快照；旧版本或损坏的数据一律视为没有快照。
    static func current() -> WidgetFeed? {
        guard let data = WidgetFeedStore.read(),
              let feed = try? JSONDecoder().decode(WidgetFeed.self, from: data),
              feed.source == favoriteSource else { return nil }
        return feed
    }
}

/// 快照的实际存放位置。
///
/// 为什么不只用 `UserDefaults(suiteName:)`：在没有 provisioning profile 的
/// 自签名 / TrollStore 安装下，`UserDefaults(suiteName: "group...")`
/// 可能悄悄退化成 App 自己容器里的 plist —— 写不报错、读也没问题，
/// 但扩展进程读到的是另一份（空的），于是小组件永远显示「尚未同步」。
/// cfprefsd 还有缓存时机问题：App 刚写完就 `reloadAllTimelines()`，
/// 扩展可能还没看到落盘的值。
///
/// 因此改成「多通道写、多通道读」，任何一条通就够：
///   1. App Group 容器里的扁平 JSON（有 profile / 越狱环境下最正规）
///   2. 沙盒外的固定路径（配合 entitlements 的 absolute-path 例外）
///
/// 文件是直接读写，跨进程可见性不依赖 cfprefsd 的缓存时机。
enum WidgetFeedStore {
    static let fileName = "WidgetFeed.json"

    /// 沙盒外兜底目录。已写入 App 与扩展的 entitlements 例外清单。
    static let fallbackDirectory = "/var/mobile/Library/GanJi"

    static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: WidgetFeed.appGroupID)
    }

    /// 按优先级排列的读写位置。
    static var targets: [URL] {
        var urls = [URL]()
        if let container = containerURL {
            urls.append(container.appendingPathComponent(fileName))
        }
        urls.append(URL(fileURLWithPath: fallbackDirectory).appendingPathComponent(fileName))
        return urls
    }

    struct Report {
        var written: [String] = []
        var verified = false
        var ruleCount = 0
        var failure: String?

        /// 只写短名字，避免界面上出现一长串绝对路径。
        var summary: String {
            if let failure { return "小组件快照写入失败：\(failure)" }
            let where_ = written.map { ($0 as NSString).lastPathComponent }.joined(separator: "、")
            let verify = verified ? "，已回读确认" : ""
            return "小组件快照：\(ruleCount) 条已写入（\(where_)\(verify)）"
        }
    }

    @discardableResult
    static func write(_ feed: WidgetFeed) -> Report {
        var report = Report(ruleCount: feed.rules.count)
        guard let data = try? JSONEncoder().encode(feed) else {
            report.failure = "编码失败"
            return report
        }

        for url in targets {
            let dir = url.deletingLastPathComponent()
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            if (try? data.write(to: url, options: .atomic)) != nil {
                report.written.append(url.path)
            }
        }

        // UserDefaults 作为附加通道，读不到也不影响文件路径。
        WidgetFeed.sharedDefaults?.set(data, forKey: WidgetFeed.storageKey)

        if report.written.isEmpty {
            report.failure = "所有路径均不可写"
            return report
        }

        // 回读确认：写成功后立刻按扩展的读法再读一遍，
        // 这样「写进去了但读不出来」不会被误判成成功。
        report.verified = read() != nil
        if !report.verified {
            report.failure = "写入后回读失败"
        }
        return report
    }

    static func read() -> Data? {
        for url in targets {
            if let data = try? Data(contentsOf: url), !data.isEmpty {
                return data
            }
        }
        return WidgetFeed.sharedDefaults?.data(forKey: WidgetFeed.storageKey)
    }
}

/// 圩日排期判定。
///
/// 传统圩期按地支三日一轮，十二地支分成三组：
/// 子·午·卯·酉 / 辰·戌·丑·未 / 寅·申·巳·亥。
/// 组号正好等于地支下标对 3 取余，所以不需要查表。
/// 另一类圩期直接写农历日（初一、十五……），按农历日号匹配。
enum MarketSchedule {
    static func phase(forBranchIndex index: Int) -> Int {
        ((index % 3) + 3) % 3
    }

    /// 生肖名换成地支，例如「鼠」→「子」。
    static func branch(forAnimal animal: String) -> String? {
        guard let i = LunarCalendar.zodiac.firstIndex(of: animal) else { return nil }
        return LunarCalendar.branches[i]
    }

    static func phase(forAnimal animal: String) -> Int? {
        guard let branch = branch(forAnimal: animal),
              let index = LunarCalendar.branches.firstIndex(of: branch) else { return nil }
        return phase(forBranchIndex: index)
    }

    private static let lunarDayMap: [String: Int] = {
        var map = [String: Int]()
        for (index, name) in LunarCalendar.dayNames.enumerated() { map[name] = index + 1 }
        return map
    }()

    static func lunarDayNumber(_ text: String) -> Int? {
        if let n = Int(text), (1...30).contains(n) { return n }
        return lunarDayMap[text]
    }

    static func lunarDay(of date: Date) -> Int {
        var cal = Calendar(identifier: .chinese)
        cal.timeZone = TimeZone.current
        return cal.component(.day, from: date)
    }

    /// 当天是否开圩。
    /// 注意：type 6 只取第一个生肖，与 App 列表里的判定保持一致 ——
    /// 两边口径必须相同，否则会出现「App 说今天有圩、小组件说休市」。
    static func opens(_ rule: MarketRule, on day: Date) -> Bool {
        guard rule.isResolved else { return false }
        switch rule.repeatType {
        case 6:
            guard let first = rule.repeatValue.first,
                  let p = phase(forAnimal: first) else { return false }
            return p == phase(forBranchIndex: LunarCalendar.branchIndexForDate(day))
        case 1, 4:
            let wanted = Set(rule.repeatValue.compactMap { lunarDayNumber($0) })
            guard !wanted.isEmpty else { return false }
            return wanted.contains(lunarDay(of: day))
        default:
            return false
        }
    }

    /// 这条圩的规则文字，例如「鼠·龙」「农历初一·十五」。
    static func ruleText(_ rule: MarketRule) -> String {
        switch rule.repeatType {
        case 6: return rule.repeatValue.joined(separator: "·")
        case 1, 4: return "农历" + rule.repeatValue.joined(separator: "·")
        default: return "圩期待核实"
        }
    }
}
