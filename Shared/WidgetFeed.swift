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
        guard let data = try? JSONEncoder().encode(self) else { return }
        WidgetFeed.sharedDefaults?.set(data, forKey: WidgetFeed.storageKey)
    }

    /// 只返回确实由「收藏」生成的快照；旧版本或损坏的数据一律视为没有快照。
    static func current() -> WidgetFeed? {
        guard let data = sharedDefaults?.data(forKey: storageKey),
              let feed = try? JSONDecoder().decode(WidgetFeed.self, from: data),
              feed.source == favoriteSource else { return nil }
        return feed
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
