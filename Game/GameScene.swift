import SpriteKit
import UIKit

/// SpriteKit battle scene. This class deliberately contains *no* gameplay rules
/// — it only: builds the player, forwards the per-frame `update` to the
/// coordinator, routes physics contacts through `CollisionSystem`, and reacts to
/// backgrounding by freezing the match. Everything else lives in the systems.
final class GameScene: SKScene {

    weak var coordinator: GameCoordinator?

    private var lastUpdateTime: TimeInterval = 0
    private var player: Player?

    // Notification observer token for background freeze.
    private var bgObserver: NSObjectProtocol?

    override func didMove(to view: SKView) {
        backgroundColor = .black
        scaleMode = .resizeFill

        let ship = Player.make()
        ship.position = CGPoint(x: frame.midX, y: frame.minY + 120)
        addChild(ship)
        self.player = ship

        coordinator?.attach(scene: self, player: ship)

        // Freeze immediately when the app leaves the foreground.
        bgObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.coordinator?.pause()
        }
    }

    deinit {
        if let token = bgObserver {
            NotificationCenter.default.removeObserver(token)
        }
    }

    // MARK: Main loop — only coordinates.
    override func update(_ currentTime: TimeInterval) {
        if lastUpdateTime == 0 { lastUpdateTime = currentTime }
        // Clamp dt so a long pause / hitch can't teleport everything.
        var dt = currentTime - lastUpdateTime
        lastUpdateTime = currentTime
        dt = min(dt, 0.05)
        coordinator?.update(dt: dt)
    }

    // MARK: Touches — relative drag
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let point = touches.first?.location(in: self) else { return }
        coordinator?.beginTouch(at: point)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let point = touches.first?.location(in: self) else { return }
        coordinator?.moveTouch(to: point)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        coordinator?.endTouch()
    }

    // MARK: Contacts — translate then hand off.
    func didBegin(_ contact: SKPhysicsContact) {
        guard let event = CollisionSystem.route(contact) else { return }
        coordinator?.handleCollision(event)
    }
}
