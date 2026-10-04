import SwiftUI
import CodexAppearanceUI

@main
@MainActor
struct CodexAppearanceApp: App {
    @StateObject private var viewModel = AppearanceViewModel.makeDefault()

    var body: some Scene {
        WindowGroup("Codex 外观") {
            ContentView(viewModel: viewModel)
        }
        .windowResizability(.contentMinSize)
    }
}
