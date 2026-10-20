import Foundation

@main struct ScheduleTests {
    static func main() throws {
        NSTimeZone.default = TimeZone(identifier: "Asia/Shanghai")!
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        struct Input: Decodable { let markets: [Market] }
        let data = try Data(contentsOf: URL(fileURLWithPath: "Shared/markets.json"))
        let markets = try JSONDecoder().decode(Input.self, from: data).markets
        let expected = [["damiao", "dengming"], ["luoxiu"], ["liuchen", "pingshan", "madong"]]
        for day in 20...31 {
            for hour in [0, 1, 8, 18, 23] {
                let d = cal.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour))!
                let ids = markets.filter { MarketStore.daysUntilNext($0, from: d) == 0 }.map { $0.id }
                precondition(ids == expected[(day - 20) % 3], "Schedule/order mismatch: \(d): \(ids)")
                precondition(LunarCalendar.branchName(d) == LunarCalendar.branchName(cal.startOfDay(for: d)))
            }
        }
        let d = cal.date(from: DateComponents(year: 2026, month: 10, day: 20))!
        precondition(LunarCalendar.ganzhiName(d) == "丁卯")
        print("PASS: 60 checks across midnight/daytime and 12 branches; 六陈→平山→麻垌 order verified.")
    }
}
