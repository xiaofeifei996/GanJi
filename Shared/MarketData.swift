import Foundation

struct Market: Codable, Identifiable {
    let id: String
    let name: String
    let area: String
    let branches: String   // 地支四字，如 子午卯酉
    let lat: Double
    let lon: Double
    let size: String       // 大集 / 小集
}

private struct MarketFile: Codable {
    let updated: String?
    let source: String?
    let markets: [Market]
}

/// 一个集市在某天的状态
struct MarketDay: Identifiable {
    let market: Market
    let date: Date
    let daysAhead: Int     // 0 = 今天

    var id: String { market.id + "-\(daysAhead)" }
    var branches: String { market.branches.map { String($0) }.joined(separator: "·") }
    var animals: String { market.branches.map { LunarCalendar.zodiacOfBranch(String($0)) }.joined(separator: "·") }
    var dayLabel: String {
        switch daysAhead {
        case 0: return "今天"
        case 1: return "明天"
        case 2: return "后天"
        default: return "\(daysAhead)天后"
        }
    }
}

enum MarketStore {
    static func load() -> [Market] {
        guard let url = Bundle.main.url(forResource: "markets", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(MarketFile.self, from: data)
        else { return [] }
        return file.markets
    }

    /// 圩期相位：子午卯酉 = 0，辰戌丑未 = 1，寅申巳亥 = 2
    /// 显式对照表，不再用取模推导，杜绝偏移
    private static let phaseTable: [Character: Int] = [
        "子": 0, "卯": 0, "午": 0, "酉": 0,
        "辰": 1, "戌": 1, "丑": 1, "未": 1,
        "寅": 2, "申": 2, "巳": 2, "亥": 2
    ]

    /// 某个圩所属相位
    static func phase(ofBranches branches: String) -> Int? {
        guard let first = branches.first else { return nil }
        return phaseTable[first]
    }

    /// 当天相位 —— 与界面头部显示的干支同源，保证两者永远一致
    static func dayPhase(_ date: Date) -> Int? {
        guard let first = LunarCalendar.branchName(date).first else { return nil }
        return phaseTable[first]
    }

    /// 从 from 起（含当天）最近一场的间隔天数
    static func daysUntilNext(_ market: Market, from fromDate: Date) -> Int {
        guard let phase = phase(ofBranches: market.branches) else { return -1 }
        let cal = Calendar(identifier: .gregorian)
        for offset in 0..<12 {
            guard let d = cal.date(byAdding: .day, value: offset, to: fromDate) else { continue }
            if dayPhase(d) == phase { return offset }
        }
        return -1
    }

    static func nextDate(_ market: Market, from fromDate: Date) -> Date {
        let cal = Calendar(identifier: .gregorian)
        let n = max(daysUntilNext(market, from: fromDate), 0)
        return cal.date(byAdding: .day, value: n, to: cal.startOfDay(for: fromDate)) ?? fromDate
    }

    /// 按最近赶集日排序（同日保持数据文件里的顺序）
    static func upcoming(from date: Date) -> [MarketDay] {
        let cal = Calendar(identifier: .gregorian)
        let today = cal.startOfDay(for: date)
        return load()
            .enumerated()
            .map { i, m -> (Int, MarketDay) in
                let n = max(daysUntilNext(m, from: today), 0)
                let d = cal.date(byAdding: .day, value: n, to: today) ?? today
                return (i, MarketDay(market: m, date: d, daysAhead: n))
            }
            .sorted { a, b in
                if a.1.daysAhead != b.1.daysAhead { return a.1.daysAhead < b.1.daysAhead }
                return a.0 < b.0
            }
            .map { $0.1 }
    }

    /// 某一天赶集的集市（用于小组件按天分栏）
    static func markets(on date: Date) -> [Market] {
        let cal = Calendar(identifier: .gregorian)
        let day = cal.startOfDay(for: date)
        return load().filter { m in
            guard let r = residue(m.branches) else { return false }
            return LunarCalendar.branchIndexForDate(day) % 3 == r
        }
    }

    /// 距离（公里）
    static func distanceKm(_ market: Market, from lat: Double, lon: Double) -> Double {
        let rad = Double.pi / 180
        let dLat = (market.lat - lat) * rad
        let dLon = (market.lon - lon) * rad
        let a = sin(dLat / 2) * sin(dLat / 2)
            + cos(lat * rad) * cos(market.lat * rad) * sin(dLon / 2) * sin(dLon / 2)
        return 6371 * 2 * atan2(sqrt(a), sqrt(1 - a))
    }
}

func kmText(_ km: Double) -> String {
    if km < 1 { return String(format: "%.0f米", km * 1000) }
    return String(format: "%.1f公里", km)
}
