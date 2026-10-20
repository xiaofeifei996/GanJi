import Foundation

/// 农历 / 生肖日换算
enum LunarCalendar {
    static let zodiac = ["鼠", "牛", "虎", "兔", "龙", "蛇", "马", "羊", "猴", "鸡", "狗", "猪"]
    static let monthNames = ["正月", "二月", "三月", "四月", "五月", "六月",
                             "七月", "八月", "九月", "十月", "冬月", "腊月"]
    static let dayNames = ["初一", "初二", "初三", "初四", "初五", "初六", "初七", "初八", "初九", "初十",
                           "十一", "十二", "十三", "十四", "十五", "十六", "十七", "十八", "十九", "二十",
                           "廿一", "廿二", "廿三", "廿四", "廿五", "廿六", "廿七", "廿八", "廿九", "三十"]

    /// 儒略日数
    static func julianDay(_ date: Date) -> Int {
        let cal = Calendar(identifier: .gregorian)
        let ordinal = cal.ordinality(of: .day, in: .era, for: date) ?? 1
        return ordinal + 1721425
    }

    /// 当日生肖序号，0 = 鼠
    static func zodiacIndex(_ date: Date) -> Int {
        ((julianDay(date) + 49) % 60) % 12
    }

    static func zodiacName(_ date: Date) -> String {
        zodiac[zodiacIndex(date)]
    }

    /// 农历月日文字，如 “九月十一”
    static func lunarText(_ date: Date) -> String {
        var cal = Calendar(identifier: .chinese)
        cal.timeZone = TimeZone.current
        let comps = cal.dateComponents([.month, .day], from: date)
        let m = comps.month ?? 1
        let d = comps.day ?? 1
        let mn = monthNames[min(max(m, 1), 12) - 1]
        let dn = dayNames[min(max(d, 1), 30) - 1]
        return mn + dn
    }

    static func shortDate(_ date: Date) -> String {
        let cal = Calendar(identifier: .gregorian)
        let comps = cal.dateComponents([.month, .day], from: date)
        return "\(comps.month ?? 1)月\(comps.day ?? 1)日"
    }

    static func weekdayText(_ date: Date) -> String {
        let names = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]
        let idx = Calendar(identifier: .gregorian).component(.weekday, from: date) - 1
        return names[min(max(idx, 0), 6)]
    }
}
