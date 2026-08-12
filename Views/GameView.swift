import SwiftUI
import SpriteKit

/// Hosts the SpriteKit scene and overlays the HUD + pause / resume controls.
/// The scene instance is created once and wired to the coordinator.
struct GameView: View {
    @EnvironmentObject var router: AppRouter
    @ObservedObject var coordinator: GameCoordinator
    @State private var scene: GameScene

    init(coordinator: GameCoordinator) {
        self._coordinator = ObservedObject(initialValue: coordinator)
        let s = GameScene()
        s.coordinator = coordinator
        self._scene = State(initialValue: s)
    }

    var body: some View {
        ZStack {
            SpriteView(scene: scene)
                .ignoresSafeArea()

            HUDView(session: coordinator.session)

            // Pause control (top-right). Sits above the HUD; the HUD itself is
            // non-interactive so drags still reach the gameplay layer.
            VStack {
                HStack {
                    Spacer()
                    Button {
                        coordinator.pause()
                    } label: {
                        Image(systemName: "pause.circle.fill")
                            .font(.system(size: 34))
                            .foregroundStyle(.white.opacity(0.85))
                            .background(Circle().fill(Color.black.opacity(0.35)))
                    }
                    .padding([.top, .trailing], 14)
                }
                Spacer()
            }

            if coordinator.paused {
                resumeOverlay
            }
        }
    }

    /// Shown after returning from the background (or manual pause). Tapping
    /// "继续作战" resumes; the match was already frozen, so no sneak attack.
    private var resumeOverlay: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            VStack(spacing: 22) {
                Text("已暂停")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)
                Button {
                    coordinator.resume()
                } label: {
                    Text("继续作战")
                        .font(.title3.bold())
                        .frame(width: 200, height: 54)
                        .background(Capsule().fill(Color.cyan))
                        .foregroundStyle(.black)
                }
            }
        }
    }
}
