import Foundation

struct Market: Codable, Identifiable {
    let id: String
    let name: String
    let area: String
    let group: String      // 属相四字，如 鼠兔马鸡
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
    var animals: String { market.group.map { String($0) }.joined(separator: "·") }
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

    /// 属相组对应的余数（三日一圩：同一组内相邻生肖差 3）
    private static func residue(_ group: String) -> Int? {
        guard let first = group.first,
              let idx = LunarCalendar.zodiac.firstIndex(of: String(first))
        else { return nil }
        return idx % 3
    }

    /// 从 from 起（含当天）最近一场的间隔天数
    static func daysUntilNext(_ market: Market, from fromDate: Date) -> Int {
        guard let r = residue(market.group) else { return -1 }
        let cal = Calendar(identifier: .gregorian)
        for offset in 0..<12 {
            guard let d = cal.date(byAdding: .day, value: offset, to: fromDate) else { continue }
            if LunarCalendar.zodiacIndex(d) % 3 == r { return offset }
        }
        return -1
    }

    static func nextDate(_ market: Market, from fromDate: Date) -> Date {
        let cal = Calendar(identifier: .gregorian)
        let n = max(daysUntilNext(market, from: fromDate), 0)
        return cal.date(byAdding: .day, value: n, to: cal.startOfDay(for: fromDate)) ?? fromDate
    }

    /// 按最近赶集日排序
    static func upcoming(from date: Date) -> [MarketDay] {
        let cal = Calendar(identifier: .gregorian)
        let today = cal.startOfDay(for: date)
        return load()
            .map { m -> MarketDay in
                let n = max(daysUntilNext(m, from: today), 0)
                let d = cal.date(byAdding: .day, value: n, to: today) ?? today
                return MarketDay(market: m, date: d, daysAhead: n)
            }
            .sorted { a, b in
                if a.daysAhead != b.daysAhead { return a.daysAhead < b.daysAhead }
                return a.market.name < b.market.name
            }
    }

    /// 某一天赶集的集市（用于小组件按天分栏）
    static func markets(on date: Date) -> [Market] {
        let cal = Calendar(identifier: .gregorian)
        let day = cal.startOfDay(for: date)
        return load().filter { m in
            guard let r = residue(m.group) else { return false }
            return LunarCalendar.zodiacIndex(day) % 3 == r
        }
    }

    /// 距离（公里），无坐标返回 nil
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
