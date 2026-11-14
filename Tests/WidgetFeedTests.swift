import Foundation

// Run on macOS without accessing App Group containers or UserDefaults:
// swiftc Shared/LunarCalendar.swift Shared/WidgetFeed.swift Tests/WidgetFeedTests.swift -o /tmp/widget-feed-tests
// /tmp/widget-feed-tests
@main struct WidgetFeedTests {
    static func main() throws {
        var checks = 0
        func expect(_ condition: Bool, _ message: String) {
            guard condition else { fatalError(message) }
            checks += 1
        }

        func snapshot(_ timestamp: Double, id: String = "fixture", source: String = WidgetFeed.favoriteSource,
                      empty: Bool = false) throws -> Data {
            let rule = MarketRule(id: id, name: "测试圩", area: "测试区", repeatType: 1, repeatValue: ["初一"])
            return try JSONEncoder().encode(WidgetFeed(
                source: source,
                updatedAt: Date(timeIntervalSinceReferenceDate: timestamp),
                rules: empty ? [] : [rule]
            ))
        }

        // Widget names are presentation-only; existing saved snapshots need no migration.
        for (input, expected) in [("贵港市桂平市罗秀镇", "罗秀圩"),
                                  ("六陈镇", "六陈圩"), ("麻垌镇", "麻垌圩"),
                                  ("大秒村", "大秒圩"), ("大妙村", "大妙圩"),
                                  ("六陈圩", "六陈圩"), ("某县三江口镇", "江口圩"),
                                  (" 罗秀镇 ", "罗秀圩"), ("镇", "镇"),
                                  ("西村", "西村"), ("中心市场", "中心市场"), ("", "")] {
            let rule = MarketRule(id: "name-test", name: input, area: "测试区", repeatType: 6, repeatValue: ["兔"])
            expect(rule.widgetDisplayName == expected, "Widget name conversion: \(input)")
            let restored = try JSONDecoder().decode(MarketRule.self, from: JSONEncoder().encode(rule))
            expect(restored.name == input && restored.id == rule.id && restored.repeatValue == rule.repeatValue,
                   "Display formatting must preserve saved identity, original name and schedule")
        }

        // Candidate order models App Group file, fallback file, then defaults.
        let primary = try snapshot(100, id: "primary")
        let fallback = try snapshot(200, id: "fallback")
        let defaults = try snapshot(300, id: "defaults")
        let corrupt = Data("{truncated".utf8)
        let legacy = try snapshot(900, source: "region")
        let missingSource = Data(#"{"updatedAt":900,"rules":[]}"#.utf8)

        expect(WidgetFeedStore.selectCandidate(from: [corrupt, fallback]) == fallback,
               "Corrupt primary must not hide a valid fallback file")
        expect(WidgetFeedStore.selectCandidate(from: [legacy, fallback]) == fallback,
               "Legacy primary must not hide a valid favorites fallback")
        expect(WidgetFeedStore.selectCandidate(from: [missingSource, fallback]) == fallback,
               "Snapshots without source must be skipped")
        expect(WidgetFeedStore.selectCandidate(from: [Data(), fallback]) == fallback,
               "Empty primary must be skipped")
        expect(WidgetFeedStore.selectCandidate(from: [corrupt, legacy, defaults]) == defaults,
               "Defaults must remain available when both file candidates are invalid")
        expect(WidgetFeedStore.selectCandidate(from: [primary, fallback]) == fallback,
               "Newer fallback must supersede a readable stale primary")
        expect(WidgetFeedStore.selectCandidate(from: [primary, fallback, defaults]) == defaults,
               "Newest defaults candidate must supersede both files")
        expect(WidgetFeedStore.selectCandidate(from: [defaults, fallback, primary]) == defaults,
               "Newest primary must retain precedence over older fallbacks")

        let tiedFallback = try snapshot(100, id: "tied-fallback")
        let tiedDefaults = try snapshot(100, id: "tied-defaults")
        expect(WidgetFeedStore.selectCandidate(from: [primary, tiedFallback, tiedDefaults]) == primary,
               "Equal timestamps must prefer the App Group file")
        expect(WidgetFeedStore.selectCandidate(from: [corrupt, tiedFallback, tiedDefaults]) == tiedFallback,
               "Equal timestamps must prefer the fallback file over defaults")
        expect(WidgetFeedStore.selectCandidate(from: [tiedDefaults, primary]) == tiedDefaults,
               "Tie priority must follow candidate order, not payload contents")
        expect(WidgetFeedStore.selectCandidate(from: []) == nil,
               "No candidates must return nil")
        expect(WidgetFeedStore.selectCandidate(from: [Data(), corrupt, legacy, missingSource]) == nil,
               "No valid favorites candidates must return nil")

        // Empty favorites is a valid newer snapshot: clearing favorites must propagate.
        let cleared = try snapshot(400, empty: true)
        expect(WidgetFeedStore.selectCandidate(from: [primary, cleared, defaults]) == cleared,
               "An empty favorites snapshot must supersede older nonempty favorites")
        let beforeReferenceDate = try snapshot(-100)
        expect(WidgetFeedStore.selectCandidate(from: [beforeReferenceDate]) == beforeReferenceDate,
               "Finite timestamps before the reference date remain valid")

        // JSONDecoder rejects malformed/missing dates and non-finite representations;
        // selection additionally rejects any decoded non-finite Date.
        for timestamp in ["null", "\"invalid\"", "\"NaN\"", "\"Infinity\"", "1e999", "-1e999"] {
            let invalidDate = Data("{\"source\":\"favorites\",\"updatedAt\":\(timestamp),\"rules\":[]}".utf8)
            expect(WidgetFeedStore.selectCandidate(from: [invalidDate]) == nil,
                   "Invalid/non-finite timestamp must not become a snapshot: \(timestamp)")
            expect(WidgetFeedStore.selectCandidate(from: [invalidDate, fallback]) == fallback,
                   "Invalid/non-finite timestamp must not hide fallback: \(timestamp)")
        }
        let missingDate = Data(#"{"source":"favorites","rules":[]}"#.utf8)
        let invalidRules = Data(#"{"source":"favorites","updatedAt":900,"rules":[{}]}"#.utf8)
        expect(WidgetFeedStore.selectCandidate(from: [missingDate, invalidRules, fallback]) == fallback,
               "Missing dates and malformed rules must not hide a valid fallback")

        expect(WidgetFeedStore.verifiesWrite(fallback, candidates: [primary, fallback]),
               "The exact new snapshot selected by readers must verify")
        expect(!WidgetFeedStore.verifiesWrite(fallback, candidates: [primary]),
               "A readable old snapshot must not verify a new write")
        expect(!WidgetFeedStore.verifiesWrite(fallback, candidates: []),
               "No readable snapshot must fail verification")
        expect(!WidgetFeedStore.verifiesWrite(fallback, candidates: [fallback, defaults]),
               "An exact copy hidden by a newer snapshot must not verify")
        expect(!WidgetFeedStore.verifiesWrite(tiedFallback, candidates: [primary, tiedFallback]),
               "An exact copy hidden by a higher-priority timestamp tie must not verify")
        expect(!WidgetFeedStore.verifiesWrite(corrupt, candidates: [corrupt]),
               "Matching corrupt bytes must not verify")
        expect(!WidgetFeedStore.verifiesWrite(legacy, candidates: [legacy]),
               "Matching legacy bytes must not verify")

        var reformatted = Data(" \n".utf8)
        reformatted.append(fallback)
        expect(WidgetFeedStore.selectCandidate(from: [reformatted]) == reformatted,
               "Selection must preserve the original bytes")
        expect(!WidgetFeedStore.verifiesWrite(fallback, candidates: [reformatted]),
               "Semantically equivalent but different bytes must not verify an exact write")
        expect(WidgetFeedStore.verifiesWrite(fallback, candidates: [corrupt, legacy, fallback]),
               "An exact selected defaults copy must verify even when files are invalid")

        print("PASS: \(checks) WidgetFeed candidate selection and write verification checks.")
    }
}
