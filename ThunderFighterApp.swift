import SwiftUI

@main
struct ThunderFighterApp: App {
    @StateObject private var router = AppRouter()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(router)
        }
    }
}

/// Root switch between the three screens. The game scene only exists while we're
/// on the `game` screen, so the coordinator/scene are torn down on exit.
struct ContentView: View {
    @EnvironmentObject var router: AppRouter

    var body: some View {
        Group {
            switch router.screen {
            case .home:
                HomeView()
            case .game:
                if let coordinator = router.coordinator {
                    GameView(coordinator: coordinator)
                } else {
                    HomeView()
                }
            case .result:
                if let result = router.lastResult {
                    ResultView(result: result)
                } else {
                    HomeView()
                }
            }
        }
    }
}
