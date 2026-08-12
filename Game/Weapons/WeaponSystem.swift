import SpriteKit

/// The coordinator asks the weapon system to apply laser (column) damage.
/// Kept as a protocol so `WeaponSystem` does not need a hard dependency on the
/// coordinator / boss types.
protocol LaserDamageTarget: AnyObject {
    func laserHitEnemy(_ enemy: Enemy, amount: Int)
    func laserHitBoss(_ boss: Boss, amount: Int)
}

/// Owns the three weapons. Each frame it ticks cooldown timers, charges the
/// laser, and spawns projectiles. Weapon *levels* live in `GameSession` (so the
/// HUD and pickups share one source of truth); this system just reads them.
final class WeaponSystem {

    private var mainTimer: TimeInterval = 0
    private var missileTimer: TimeInterval = 0
    private var laserCharge: CGFloat = 1.0

    weak var scene: SKScene?
    weak var player: Player?
    weak var session: GameSession?
    weak var laserTarget: LaserDamageTarget?
    let audio: AudioManager

    /// Supplies the current live enemies (+ boss) for missile homing.
    var targetProvider: (() -> [SKNode])?

    init(audio: AudioManager) {
        self.audio = audio
    }

    func reset() {
        mainTimer = 0
        missileTimer = 0
        laserCharge = 1.0
    }

    // MARK: Per-frame update
    func update(deltaTime dt: TimeInterval) {
        guard let scene, let player, let session else { return }

        let mainLevel = session.weaponLevels[.main] ?? 1
        let missileLevel = session.weaponLevels[.missile] ?? 1
        let laserLevel = session.weaponLevels[.laser] ?? 1

        // Main cannon: steady stream, level adds streams + damage.
        mainTimer -= dt
        if mainTimer <= 0 {
            fireMain(level: mainLevel, at: player.position, in: scene)
            mainTimer = GameConfig.baseMainCooldown
        }

        // Homing missiles: level adds count + blast radius.
        missileTimer -= dt
        if missileTimer <= 0 {
            fireMissile(level: missileLevel, at: player.position, in: scene)
            missileTimer = GameConfig.baseMissileCooldown
        }

        // Laser: charge up, then release a full-column pierce.
        let chargeTime = GameConfig.laserChargeTimeByLevel[laserLevel]
        laserCharge += dt / chargeTime
        if laserCharge >= 1 {
            fireLaser(level: laserLevel, at: player.position, in: scene)
            laserCharge = 0
        }
        session.setLaserCharge(laserCharge)
    }

    // MARK: Firing
    private func fireMain(level: Int, at origin: CGPoint, in scene: SKScene) {
        let damage = GameConfig.mainDamageByLevel[level]
        let color = WeaponType.main.coreColor
        let speed: CGFloat = 580
        let count = level
        for i in 0..<count {
            let bullet = Bullet.make(damage: damage, color: color)
            bullet.position = origin
            let dx = (CGFloat(i) - CGFloat(count - 1) / 2) * 46
            bullet.velocity = CGVector(dx: dx, dy: speed)
            scene.addChild(bullet)
        }
        audio.play(.mainFire)
    }

    private func fireMissile(level: Int, at origin: CGPoint, in scene: SKScene) {
        let damage = GameConfig.missileDamageByLevel[level]
        let radius = GameConfig.missileBlastRadiusByLevel[level]
        let color = WeaponType.missile.coreColor
        let count = level
        let targets = targetProvider?() ?? []
        for i in 0..<count {
            let missile = Missile.make(damage: damage, blastRadius: radius, color: color)
            missile.position = CGPoint(x: origin.x + (CGFloat(i) - CGFloat(count - 1) / 2) * 18,
                                       y: origin.y)
            missile.velocity = CGVector(dx: 0, dy: 320)
            if let t = nearestTarget(from: targets, to: missile.position, skip: i) {
                missile.target = t
            }
            scene.addChild(missile)
        }
        audio.play(.missileLock)
    }

    private func fireLaser(level: Int, at origin: CGPoint, in scene: SKScene) {
        let width = GameConfig.laserWidthByLevel[level]
        let damage = GameConfig.laserDamageByLevel[level]
        let color = WeaponType.laser.coreColor
        let top = scene.frame.maxY
        let height = top - origin.y

        let beam = LaserBeam.make(width: width, height: height, color: color)
        beam.position = CGPoint(x: origin.x, y: (origin.y + top) / 2)
        scene.addChild(beam)
        beam.run(SKAction.sequence([.fadeOut(withDuration: 0.28), .removeFromParent()]))

        // Column damage resolved geometrically (laser has no physics body).
        let minX = origin.x - width / 2
        let maxX = origin.x + width / 2
        for node in scene.children {
            if let enemy = node as? Enemy,
               enemy.position.x >= minX, enemy.position.x <= maxX,
               enemy.position.y > origin.y {
                laserTarget?.laserHitEnemy(enemy, amount: damage)
            } else if let boss = node as? Boss,
                      boss.position.x >= minX, boss.position.x <= maxX {
                laserTarget?.laserHitBoss(boss, amount: damage)
            }
        }
        audio.play(.laserFire)
    }

    // MARK: Helpers
    private func nearestTarget(from targets: [SKNode], to point: CGPoint, skip offset: Int) -> SKNode? {
        let alive = targets.filter { $0.parent != nil }
        guard !alive.isEmpty else { return nil }
        // Round-robin a bit so multiple missiles don't all chase one target.
        if alive.count > 1 {
            let idx = offset % alive.count
            return alive[idx]
        }
        return alive.min(by: { distance($0.position, point) < distance($1.position, point) })
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        hypot(a.x - b.x, a.y - b.y)
    }
}
