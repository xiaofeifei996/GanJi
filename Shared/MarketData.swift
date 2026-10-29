import Foundation

struct Market: Codable, Identifiable {
    let id: String
    let name: String
    let area: String
    let branches: String
    let lat: Double
    let lon: Double
    let size: String
    var province: String? = nil
    var city: String? = nil
    var provinceCode: Int? = nil
    var cityCode: Int? = nil
    var areaCode: Int? = nil
    var repeatType: Int? = nil
    var repeatValue: [String]? = nil
    var remark: String? = nil
    var place: String? = nil
    var address: String? = nil
    var status: Int? = nil
}

private struct MarketFile: Codable {
    let updated: String?
    let source: String?
    let markets: [Market]
}

struct MarketDay: Identifiable {
    let market: Market
    let date: Date
    let daysAhead: Int
    var id: String { market.id + "-\(daysAhead)" }
    var branches: String { market.branches.map { String($0) }.joined(separator: "·") }
    var animals: String {
        if market.repeatType == 6, let values = market.repeatValue, !values.isEmpty {
            return values.joined(separator: "·")
        }
        return market.branches.map { LunarCalendar.zodiacOfBranch(String($0)) }.joined(separator: "·")
    }
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
        return file.markets.filter { $0.status == nil || $0.status == 1 }
    }

    private static let phaseTable: [Character: Int] = [
        "子": 0, "卯": 0, "午": 0, "酉": 0,
        "辰": 1, "戌": 1, "丑": 1, "未": 1,
        "寅": 2, "申": 2, "巳": 2, "亥": 2
    ]

    static func phase(ofBranches branches: String) -> Int? {
        guard let first = branches.first else { return nil }
        return phaseTable[first]
    }

    static func dayPhase(_ date: Date) -> Int? {
        guard let first = LunarCalendar.branchName(date).first else { return nil }
        return phaseTable[first]
    }

    private static func lunarDay(_ date: Date) -> Int {
        var cal = Calendar(identifier: .chinese)
        cal.timeZone = TimeZone.current
        return cal.component(.day, from: date)
    }

    private static func lunarDayNumber(_ value: String) -> Int? {
        if let number = Int(value), (1...30).contains(number) { return number }
        let names = ["初一":1,"初二":2,"初三":3,"初四":4,"初五":5,"初六":6,"初七":7,"初八":8,"初九":9,"初十":10,
                     "十一":11,"十二":12,"十三":13,"十四":14,"十五":15,"十六":16,"十七":17,"十八":18,"十九":19,"二十":20,
                     "廿一":21,"廿二":22,"廿三":23,"廿四":24,"廿五":25,"廿六":26,"廿七":27,"廿八":28,"廿九":29,"三十":30]
        return names[value]
    }

    static func daysUntilNext(_ market: Market, from fromDate: Date) -> Int {
        let cal = Calendar.current
        for offset in 0..<40 {
            guard let day = cal.date(byAdding: .day, value: offset, to: cal.startOfDay(for: fromDate)) else { continue }
            switch market.repeatType {
            case 6:
                guard let phase = phase(ofBranches: market.branches), dayPhase(day) == phase else { continue }
                return offset
            case 1, 4:
                let wanted = (market.repeatValue ?? []).compactMap(lunarDayNumber)
                if wanted.contains(lunarDay(day)) { return offset }
            default:
                guard let phase = phase(ofBranches: market.branches), dayPhase(day) == phase else { continue }
                return offset
            }
        }
        return -1
    }

    static func nextDate(_ market: Market, from fromDate: Date) -> Date {
        let count = max(daysUntilNext(market, from: fromDate), 0)
        return Calendar.current.date(byAdding: .day, value: count, to: Calendar.current.startOfDay(for: fromDate)) ?? fromDate
    }

    static func upcoming(from date: Date) -> [MarketDay] {
        upcoming(from: date, markets: load())
    }

    static func upcoming(from date: Date, markets source: [Market]) -> [MarketDay] {
        let today = Calendar.current.startOfDay(for: date)
        return source.enumerated().compactMap { index, market -> (Int, MarketDay)? in
            let count = daysUntilNext(market, from: today)
            guard count >= 0 else { return nil }
            let day = Calendar.current.date(byAdding: .day, value: count, to: today) ?? today
            return (index, MarketDay(market: market, date: day, daysAhead: count))
        }.sorted { lhs, rhs in
            lhs.1.daysAhead == rhs.1.daysAhead ? lhs.0 < rhs.0 : lhs.1.daysAhead < rhs.1.daysAhead
        }.map { $0.1 }
    }

    static func markets(on date: Date) -> [Market] {
        let day = Calendar.current.startOfDay(for: date)
        return load().filter { daysUntilNext($0, from: day) == 0 }
    }

    static func distanceKm(_ market: Market, from lat: Double, lon: Double) -> Double {
        let radians = Double.pi / 180
        let dLat = (market.lat - lat) * radians
        let dLon = (market.lon - lon) * radians
        let a = sin(dLat / 2) * sin(dLat / 2)
            + cos(lat * radians) * cos(market.lat * radians) * sin(dLon / 2) * sin(dLon / 2)
        return 6371 * 2 * atan2(sqrt(a), sqrt(1 - a))
    }
}

func kmText(_ km: Double) -> String {
    if km < 1 { return String(format: "%.0f米", km * 1000) }
    return String(format: "%.1f公里", km)
}