import SpriteKit

/// What flavour of player projectile this is (used for visuals / behaviour).
enum ProjectileKind {
    case main, missile, laser
}

/// Base class for everything the player fires. Enemies' bullets subclass this
/// too so a single list can be ticked each frame, but they are given a distinct
/// physics category so contacts route correctly.
class Projectile: SKSpriteNode {
    var damage: Int = 0
    var kind: ProjectileKind = .main
    /// Laser pierces, so it must not be consumed by a contact.
    var pierces: Bool = false
    /// Seconds alive; used to auto-expire missiles / beams.
    var life: TimeInterval = 0

    /// Per-frame motion. Overridden by subclasses.
    func tick(_ dt: TimeInterval) {
        life += dt
    }
}

// MARK: - Main cannon bullet

final class Bullet: Projectile {
    var velocity: CGVector = .zero

    override func tick(_ dt: TimeInterval) {
        life += dt
        position.x += velocity.dx * dt
        position.y += velocity.dy * dt
    }

    static func make(damage: Int, color: UIColor) -> Bullet {
        let node = Bullet(texture: nil, color: color, size: CGSize(width: 6, height: 16))
        node.kind = .main
        node.damage = damage
        node.name = "bullet"
        let body = SKPhysicsBody(rectangleOf: node.size)
        body.categoryBitMask = PhysicsCategory.playerBullet.rawValue
        body.contactTestBitMask = PhysicsCategory.enemy.rawValue | PhysicsCategory.boss.rawValue
        body.collisionBitMask = 0
        body.usesPreciseCollisionDetection = true
        node.physicsBody = body
        return node
    }
}

// MARK: - Homing missile

final class Missile: Projectile {
    var velocity: CGVector = .zero
    var missileSpeed: CGFloat = 380
    var blastRadius: CGFloat = 70
    weak var target: SKNode?

    override func tick(_ dt: TimeInterval) {
        life += dt
        if let t = target, t.parent != nil {
            let dx = t.position.x - position.x
            let dy = t.position.y - position.y
            let ang = atan2(dy, dx)
            let desired = CGVector(dx: cos(ang) * missileSpeed, dy: sin(ang) * missileSpeed)
            let k = min(1, 7 * dt)   // steering responsiveness
            velocity.dx += (desired.dx - velocity.dx) * k
            velocity.dy += (desired.dy - velocity.dy) * k
        }
        position.x += velocity.dx * dt
        position.y += velocity.dy * dt
        zRotation = atan2(velocity.dy, velocity.dx) - .pi / 2
    }

    static func make(damage: Int, blastRadius: CGFloat, color: UIColor) -> Missile {
        let node = Missile(texture: nil, color: color, size: CGSize(width: 12, height: 20))
        node.kind = .missile
        node.damage = damage
        node.blastRadius = blastRadius
        node.name = "missile"
        let body = SKPhysicsBody(circleOfRadius: 8)
        body.categoryBitMask = PhysicsCategory.playerBullet.rawValue
        body.contactTestBitMask = PhysicsCategory.enemy.rawValue | PhysicsCategory.boss.rawValue
        body.collisionBitMask = 0
        node.physicsBody = body
        return node
    }
}

// MARK: - Piercing laser (visual beam; damage applied at spawn)

final class LaserBeam: Projectile {
    let halfWidth: CGFloat

    init(width: CGFloat, height: CGFloat, color: UIColor) {
        self.halfWidth = width / 2
        super.init(texture: nil, color: color, size: CGSize(width: width, height: height))
        self.kind = .laser
        self.pierces = true
        self.name = "laser"
        self.alpha = 0.85
        // No physics body: damage is resolved geometrically at spawn time.
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    static func make(width: CGFloat, height: CGFloat, color: UIColor) -> LaserBeam {
        LaserBeam(width: width, height: height, color: color)
    }
}

// MARK: - Enemy bullet

final class EnemyBullet: Projectile {
    var velocity: CGVector = .zero

    override func tick(_ dt: TimeInterval) {
        life += dt
        position.x += velocity.dx * dt
        position.y += velocity.dy * dt
    }

    static func make(damage: Int, color: UIColor = .systemRed) -> EnemyBullet {
        let node = EnemyBullet(texture: nil, color: color, size: CGSize(width: 10, height: 10))
        node.damage = damage
        node.name = "enemyBullet"
        let body = SKPhysicsBody(circleOfRadius: 5)
        body.categoryBitMask = PhysicsCategory.enemyBullet.rawValue
        body.contactTestBitMask = PhysicsCategory.player.rawValue
        body.collisionBitMask = 0
        node.physicsBody = body
        return node
    }
}
