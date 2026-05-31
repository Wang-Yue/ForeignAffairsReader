import SwiftUI

@main
struct ForeignAffairsReaderApp: App {
  var body: some Scene {
    WindowGroup {
      ContentView()
        #if os(macOS)
          .frame(minWidth: 850, minHeight: 600)
        #endif
    }
    #if os(macOS)
      .windowStyle(.hiddenTitleBar)
    #endif
  }
}
