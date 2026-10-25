import SwiftUI
@main
struct RiviSmartSortExampleApp: App {
    var body: some Scene {
        WindowGroup {
            TabView {
                SmartSortV2DemoView()
                    .tabItem { Label("Demo", systemImage: "square.grid.2x2") }
                // A full results screen wired to the Smart Sort V2 views: the reference for integrating.
                ReferenceSmartSortView()
                    .tabItem { Label("Reference", systemImage: "airplane") }
            }
        }
    }
}
