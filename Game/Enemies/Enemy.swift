import SpriteKit

/// Base enemy. Holds HP, score, the weapon core it may drop, and a movement /
/// firing loop. Concrete kinds (normal / elite) subclass and override `update`.
class Enemy: SKSpriteNode {

    var hp: Int
    let maxHP: Int
    let scoreValue: Int
    /// Weapon core dropped on death (nil = no drop). Set by the spawner so it
    /// can choreograph *which* weapon each wave teaches.
    let coreType: WeaponType?
    let isElite: Bool
    /// Damage dealt to the player when ramming.
    let contactDamage: Int

    var velocity: CGVector = .zero
    var fireTimer: TimeInterval = 0
    var fireInterval: TimeInterval = 1.8

    init(hp: Int,
         scoreValue: Int,
         coreType: WeaponType?,
         size: CGSize,
         color: UIColor,
         isElite: Bool = false,
         contactDamage: Int = 1,
         textureAsset: SpriteAsset? = nil) {
        self.hp = hp
        self.maxHP = hp
        self.scoreValue = scoreValue
        self.coreType = coreType
        self.isElite = isElite
        self.contactDamage = contactDamage

        super.init(texture: nil, color: .clear, size: size)

        if let asset = textureAsset, let tex = SpriteTextures.texture(asset) {
            SpriteTextures.fit(self, texture: tex, into: size)
        } else {
            let shape = SKShapeNode(ellipseIn: CGRect(origin: CGPoint(x: -size.width/2, y: -size.height/2),
                                                      size: size))
            shape.fillColor = color
            shape.strokeColor = .white
            shape.lineWidth = isElite ? 3 : 1.5
            addChild(shape)
        }

        let body = SKPhysicsBody(circleOfRadius: min(self.size.width, self.size.height) / 2)
        body.categoryBitMask = PhysicsCategory.enemy.rawValue
        body.contactTestBitMask = PhysicsCategory.playerBullet.rawValue | PhysicsCategory.player.rawValue
        body.collisionBitMask = 0
        physicsBody = body
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Apply damage. Returns true when the enemy should die.
    @discardableResult
    func takeDamage(_ amount: Int) -> Bool {
        hp -= amount
        // brief flash
        run(SKAction.sequence([.fadeAlpha(to: 0.4, duration: 0.05),
                               .fadeAlpha(to: 1, duration: 0.05)]))
        return hp <= 0
    }

    /// Per-frame behaviour. Subclasses override.
    func update(dt: TimeInterval, scene: SKScene, playerPos: CGPoint) {
        position.x += velocity.dx * dt
        position.y += velocity.dy * dt
        maybeFire(dt: dt, scene: scene, playerPos: playerPos)
    }

    /// Spawn one bullet aimed at the player.
    func maybeFire(dt: TimeInterval, scene: SKScene, playerPos: CGPoint) {
        fireTimer -= dt
        if fireTimer <= 0 {
            fireTimer = fireInterval
            spawnAimedBullet(scene: scene, playerPos: playerPos, speed: 220)
        }
    }

    func spawnAimedBullet(scene: SKScene, playerPos: CGPoint, speed: CGFloat, damage: Int = 1) {
        let bullet = EnemyBullet.make(damage: damage)
        bullet.position = position
        let dx = playerPos.x - position.x
        let dy = playerPos.y - position.y
        let len = max(1, sqrt(dx*dx + dy*dy))
        bullet.velocity = CGVector(dx: dx/len * speed, dy: dy/len * speed)
        scene.addChild(bullet)
    }
}

// MARK: - Normal enemy (three flavours)

final class NormalEnemy: Enemy {
    let flavor: Int          // 0, 1, 2
    private var elapsed: TimeInterval = 0
    var baseX: CGFloat = 0   // set by spawner to anchor the sine sway

    init(flavor: Int, coreType: WeaponType?) {
        self.flavor = flavor
        let (hp, score, size, color, interval, speed) = NormalEnemy.preset(for: flavor)
        let asset: SpriteAsset? = {
            switch flavor { case 0: return .enemyNormal0; case 1: return .enemyNormal1; default: return .enemyNormal2 }
        }()
        super.init(hp: hp, scoreValue: score, coreType: coreType, size: size, color: color, textureAsset: asset)
        self.fireInterval = interval
        self.velocity = CGVector(dx: 0, dy: -speed)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func update(dt: TimeInterval, scene: SKScene, playerPos: CGPoint) {
        elapsed += dt
        velocity.dy = (flavor == 2 ? -260 : -140)   // flavour 2 dives
        switch flavor {
        case 1:
            // sine sway
            position.y += velocity.dy * dt
            position.x = baseX + sin(elapsed * 2.2) * 38
        default:
            position.y += velocity.dy * dt
        }
        maybeFire(dt: dt, scene: scene, playerPos: playerPos)
        if position.y < scene.frame.minY - 80 { removeFromParent() }
    }

    private static func preset(for flavor: Int) -> (Int, Int, CGSize, UIColor, TimeInterval, CGFloat) {
        switch flavor {
        case 0: return (GameConfig.normalEnemyHP[0], GameConfig.baseKillScore,
                        CGSize(width: 30, height: 30), .systemRed, 2.0, 140)
        case 1: return (GameConfig.normalEnemyHP[1], GameConfig.baseKillScore,
                        CGSize(width: 34, height: 34), .systemPurple, 1.6, 140)
        default: return (GameConfig.normalEnemyHP[2], GameConfig.baseKillScore,
                         CGSize(width: 26, height: 26), .systemOrange, 2.4, 140)
        }
    }
}

// MARK: - Elite enemy

final class EliteEnemy: Enemy {
    private var elapsed: TimeInterval = 0
    var baseX: CGFloat = 0   // set by spawner

    init(coreType: WeaponType?) {
        super.init(hp: GameConfig.eliteEnemyHP,
                   scoreValue: GameConfig.eliteKillScore,
                   coreType: coreType,
                   size: CGSize(width: 56, height: 56),
                   color: .systemYellow,
                   isElite: true,
                   contactDamage: 2,
                   textureAsset: .elite)
        self.fireInterval = 1.1
        self.velocity = CGVector(dx: 0, dy: -90)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func update(dt: TimeInterval, scene: SKScene, playerPos: CGPoint) {
        elapsed += dt
        // slow descent then hover near the top, sweeping side to side
        if position.y > scene.frame.maxY - 160 {
            position.y += velocity.dy * dt
        } else {
            position.x = baseX + sin(elapsed * 1.4) * 90
        }
        fireTimer -= dt
        if fireTimer <= 0 {
            fireTimer = fireInterval
            fireSpread(scene: scene, playerPos: playerPos)
        }
        if position.y < scene.frame.minY - 80 { removeFromParent() }
    }

    /// 5-way spread shot.
    private func fireSpread(scene: SKScene, playerPos: CGPoint) {
        let baseAng = atan2(playerPos.y - position.y, playerPos.x - position.x)
        for i in -2...2 {
            let ang = baseAng + CGFloat(i) * 0.18
            let bullet = EnemyBullet.make(damage: 1, color: .systemYellow)
            bullet.position = position
            bullet.velocity = CGVector(dx: cos(ang) * 240, dy: sin(ang) * 240)
            scene.addChild(bullet)
        }
    }
}
