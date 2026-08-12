import SpriteKit

/// The player's ship. Pure data + a renderable body; all behaviour (movement,
/// shield, invincibility) lives in `PlayerController`.
final class Player: SKSpriteNode {

    var shield: Int = GameConfig.shieldMax
    private var invincibleUntil: TimeInterval = 0

    var isInvincible: Bool {
        CACurrentMediaTime() < invincibleUntil
    }

    /// Marks the ship briefly invincible after a hit.
    func grantInvincibility(_ duration: TimeInterval = GameConfig.invincibleDuration) {
        invincibleUntil = CACurrentMediaTime() + duration
    }

    /// Visual feedback: blink while invincible.
    func refreshInvincibleVisual() {
        let target = isInvincible ? 0.35 : 1.0
        if abs(self.alpha - target) > 0.01 {
            self.alpha = target
        }
    }

    static func make() -> Player {
        let size = CGSize(width: 34, height: 42)
        let node = Player(texture: nil, color: .clear, size: size)
        node.name = "player"
        node.anchorPoint = CGPoint(x: 0.5, y: 0.5)

        // Prefer an authored sprite; fall back to a vector hull.
        if let tex = SpriteTextures.texture(.player) {
            SpriteTextures.fit(node, texture: tex, into: size)
        } else {
            let hull = SKShapeNode(path: Player.hullPath(size: size))
            hull.fillColor = .systemCyan
            hull.strokeColor = .white
            hull.lineWidth = 2
            node.addChild(hull)
        }

        let body = SKPhysicsBody(rectangleOf: node.size)
        body.isDynamic = true
        body.categoryBitMask = PhysicsCategory.player.rawValue
        body.contactTestBitMask = PhysicsCategory.enemy.rawValue
            | PhysicsCategory.enemyBullet.rawValue
            | PhysicsCategory.boss.rawValue
            | PhysicsCategory.item.rawValue
        body.collisionBitMask = 0   // we resolve collisions ourselves
        body.usesPreciseCollisionDetection = true
        node.physicsBody = body
        return node
    }

    private static func hullPath(size: CGSize) -> CGPath {
        let w = size.width / 2
        let h = size.height / 2
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: h))            // nose
        path.addLine(to: CGPoint(x: -w, y: -h))       // bottom-left
        path.addLine(to: CGPoint(x: 0, y: -h * 0.5))  // notch
        path.addLine(to: CGPoint(x: w, y: -h))        // bottom-right
        path.closeSubpath()
        return path
    }
}
