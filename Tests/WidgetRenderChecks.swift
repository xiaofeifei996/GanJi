import SwiftUI
import UIKit

@main
struct WidgetRenderChecks {
    @MainActor static func main() throws {
        guard #available(iOS 16.0, *) else { return }
        let folder = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let date = Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: 14, hour: 12))!
        let rules = ["六陈圩", "平山圩", "麻垌圩"].enumerated().map {
            MarketRule(id: String($0.offset), name: $0.element, area: "平南", repeatType: 6, repeatValue: ["虎"])
        }
        let boards = (0..<7).map { index in
            DayBoard(date: Calendar.current.date(byAdding: .day, value: index, to: date)!,
                     markets: index % 3 == 1 ? [] : rules)
        }
        let entry = GanJiEntry(date: date, boards: boards, synced: true, favoriteCount: rules.count)
        for (name, width, height) in [("small", 158.0, 158.0), ("medium", 338.0, 158.0),
                                       ("large", 338.0, 354.0)] {
            let view = Group {
                switch name {
                case "small": SealBoard(entry: entry)
                case "medium": StripBoard(entry: entry)
                default: AlmanacBoard(entry: entry)
                }
            }
            .foregroundStyle(.white)
            .frame(width: width, height: height)
            .background(LinearGradient(colors: [Color(red: 0.16, green: 0.32, blue: 0.31),
                                                 Color(red: 0.04, green: 0.12, blue: 0.16)],
                                        startPoint: .topLeading, endPoint: .bottomTrailing))
            .clipShape(RoundedRectangle(cornerRadius: 23))
            let renderer = ImageRenderer(content: view)
            renderer.scale = 3
            guard let image = renderer.uiImage, let data = image.pngData() else {
                fatalError("Unable to render \(name)")
            }
            try data.write(to: folder.appendingPathComponent(name + ".png"))
        }
        print("SwiftUI widget renders completed")
    }
}
