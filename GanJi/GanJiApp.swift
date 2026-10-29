import SwiftUI
import WidgetKit

@main
struct GanJiApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    WidgetCenter.shared.reloadAllTimelines()
                }
        }
    }
}
