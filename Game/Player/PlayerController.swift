import SpriteKit

/// Handles: relative (delta) drag movement, movement bounds, shield bookkeeping
/// and the post-hit invincibility window. Does not decide what happens on death
/// — it reports it and the coordinator ends the game.
final class PlayerController {

    let player: Player
    private weak var scene: SKScene?
    private var bounds: CGRect = .zero
    private var lastTouch: CGPoint?

    var shield: Int { player.shield }

    init(player: Player, scene: SKScene) {
        self.player = player
        self.scene = scene
        self.bounds = scene.frame.insetBy(dx: GameConfig.playerMargin,
                                          dy: GameConfig.playerMargin)
    }

    // MARK: Relative drag
    /// Touch began: remember the anchor so movement is relative to it.
    func beginTouch(at point: CGPoint) {
        lastTouch = point
    }

    /// Touch moved: ship follows the *same delta* as the finger.
    func moveTouch(to point: CGPoint) {
        guard let last = lastTouch else {
            lastTouch = point
            return
        }
        let dx = point.x - last.x
        let dy = point.y - last.y

        var next = CGPoint(x: player.position.x + dx,
                           y: player.position.y + dy)
        next.x = min(max(next.x, bounds.minX), bounds.maxX)
        next.y = min(max(next.y, bounds.minY), bounds.maxY)
        player.position = next
        lastTouch = point
    }

    func endTouch() {
        lastTouch = nil
    }

    // MARK: Shield / invincibility
    /// Apply one hit. Returns `true` if the last shield point was lost.
    /// While invincible the hit is ignored entirely (no double-counting).
    @discardableResult
    func takeHit() -> Bool {
        if player.isInvincible { return false }
        player.shield -= 1
        player.grantInvincibility()
        return player.shield <= 0
    }

    func repair() {
        player.shield = min(GameConfig.shieldMax, player.shield + 1)
    }

    /// Refill the shield to full — used on respawn after spending a life.
    func refillShield() {
        player.shield = GameConfig.shieldMax
    }

    func tick() {
        player.refreshInvincibleVisual()
    }

    /// Push shield state into the session for the HUD.
    func syncShield(to session: GameSession) {
        session.pushShield(player.shield)
    }
}
