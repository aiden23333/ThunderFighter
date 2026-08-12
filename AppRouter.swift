import SwiftUI

/// Owns which top-level screen is showing and the live coordinator for the
/// current match. Switching screens here drives the SwiftUI flow; the coordinator
/// drives the SpriteKit match.
final class AppRouter: ObservableObject {
    enum Screen { case home, game, result }

    @Published var screen: Screen = .home
    @Published var lastResult: GameResult?
    var coordinator: GameCoordinator?
    private var lastMode: GameMode = .level

    func startGame(_ mode: GameMode = .level) {
        lastMode = mode
        coordinator = GameCoordinator(mode: mode) { [weak self] result in
            self?.finishGame(result)
        }
        screen = .game
    }

    func finishGame(_ result: GameResult) {
        lastResult = result
        screen = .result
    }

    func restart() {
        startGame(lastMode)
    }

    func backToHome() {
        coordinator = nil
        screen = .home
    }
}
