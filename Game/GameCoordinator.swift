import SpriteKit
import Combine

/// The brain of a single match. Owns every subsystem, advances them once per
/// frame, turns collisions into damage/drops, and pushes results into the
/// `GameSession` (which the HUD reads). The data flow is strictly one-directional:
///
///   input → player → systems → session → HUD
///
/// `GameScene` only calls `update(dt:)` and forwards contacts; it contains no
/// gameplay rules itself.
final class GameCoordinator: ObservableObject {

    let session = GameSession()
    let audio = AudioManager.shared

    private let weaponSystem: WeaponSystem
    private let spawner: EnemySpawner
    private let bossStateMachine = BossStateMachine()

    private(set) weak var scene: GameScene?
    private var playerController: PlayerController!
    private var boss: Boss?
    private var bossActive = false
    private var bossDead = false

    private var ended = false
    @Published var paused = false

    let mode: GameMode

    let onGameEnd: (GameResult) -> Void

    init(mode: GameMode = .level, onGameEnd: @escaping (GameResult) -> Void) {
        self.mode = mode
        self.onGameEnd = onGameEnd
        self.weaponSystem = WeaponSystem(audio: audio)
        self.spawner = EnemySpawner(mode: mode)
        weaponSystem.laserTarget = self
    }

    // MARK: Lifecycle
    func attach(scene: GameScene, player: Player) {
        self.scene = scene
        self.playerController = PlayerController(player: player, scene: scene)
        weaponSystem.scene = scene
        weaponSystem.player = player
        weaponSystem.session = session
        weaponSystem.targetProvider = { [weak self] in self?.liveTargets() ?? [] }
        spawner.onClearField = { [weak self] in self?.clearField() }
        spawner.onSpawnBoss = { [weak self] in self?.spawnBoss() }

        session.reset(mode: mode)
        weaponSystem.reset()
        spawner.reset()
        ended = false
        paused = false
        bossActive = false
        bossDead = false
        boss = nil
        session.setBossFight(false)
        audio.resumeAll()
    }

    // MARK: Per-frame update (called by GameScene)
    func update(dt: TimeInterval) {
        guard !paused, !ended else { return }
        guard let scene else { return }

        session.advanceTime(dt)
        playerController.tick()
        playerController.syncShield(to: session)

        weaponSystem.update(deltaTime: dt)
        updateEnemies(dt, scene: scene)
        if bossActive { updateBoss(dt, scene: scene) }

        spawner.update(elapsed: session.elapsed,
                       bossActive: bossActive,
                       bossDead: bossDead,
                       scene: scene,
                       playerPos: playerController.player.position)

        cullProjectiles(scene: scene)

        // Enrage the boss if it is still alive past the time limit (level mode
        // only — endless bosses just get tougher over time).
        if mode == .level, session.elapsed >= GameConfig.bossTimeLimit, bossActive, !bossDead,
           !session.bossEnraged {
            session.setBossEnraged(true)
            boss?.enraged = true
            audio.play(.bossAlert)
        }
    }

    // MARK: Pause / background freeze
    func pause() {
        guard !ended, !paused else { return }
        paused = true
        scene?.isPaused = true
        audio.pauseAll()
    }

    func resume() {
        guard !ended, paused else { return }
        paused = false
        scene?.isPaused = false
        audio.resumeAll()
    }

    // MARK: Touch forwarding (relative drag lives in PlayerController)
    func beginTouch(at point: CGPoint) { playerController?.beginTouch(at: point) }
    func moveTouch(to point: CGPoint)  { playerController?.moveTouch(to: point) }
    func endTouch()                    { playerController?.endTouch() }

    // MARK: Collision handling (from GameScene.didBegin)
    func handleCollision(_ event: CollisionEvent) {
        guard !ended else { return }
        switch event {
        case .playerShotEnemy(let bullet, let enemy):
            if bullet.kind == .missile {
                explodeMissile(bullet as! Missile)
                bullet.removeFromParent()
            } else {
                bullet.removeFromParent()
                damageEnemy(enemy, amount: bullet.damage)
            }

        case .playerShotBoss(let bullet):
            if bullet.kind == .missile {
                explodeMissile(bullet as! Missile)
                bullet.removeFromParent()
            } else {
                bullet.removeFromParent()
                damageBoss(amount: bullet.damage)
            }

        case .enemyShotPlayer(let bullet):
            bullet.removeFromParent()
            playerHit()

        case .enemyRamPlayer(let enemy):
            enemy.removeFromParent()
            playerHit()

        case .bossRamPlayer:
            playerHit()

        case .playerGotItem(let item):
            collectItem(item)
        }
    }

    // MARK: Damage application
    private func damageEnemy(_ enemy: Enemy, amount: Int) {
        guard enemy.parent != nil else { return }
        let dead = enemy.takeDamage(amount)
        if dead {
            guard let scene else { return }
            session.registerKill(baseScore: enemy.scoreValue)
            audio.play(.explosion)
            spawner.rollDrop(for: enemy, scene: scene)
            enemy.removeFromParent()
        }
    }

    private func damageBoss(amount: Int) {
        guard let boss, boss.parent != nil, boss.state != .defeated else { return }
        let dead = boss.takeDamage(amount)
        session.setBossHP(CGFloat(boss.hp) / CGFloat(boss.maxHP))
        if dead {
            boss.state = .defeated
            bossDead = true
            bossActive = false
            session.setBossFight(false)
            session.registerBossDefeat()
            audio.play(.victory)
            boss.removeFromParent()
            self.boss = nil
            if mode == .level {
                endGame(.victory)
            } else {
                // Endless: don't end — clear the field and queue the next boss.
                spawner.notifyBossDefeated(elapsed: session.elapsed)
            }
        }
    }

    private func explodeMissile(_ missile: Missile) {
        audio.play(.explosion)
        guard let scene else { return }
        let center = missile.position
        let r = missile.blastRadius
        for node in scene.children {
            if let e = node as? Enemy, e.parent != nil,
               hypot(e.position.x - center.x, e.position.y - center.y) <= r {
                damageEnemy(e, amount: missile.damage)
            } else if let b = boss, b.parent != nil,
                      hypot(b.position.x - center.x, b.position.y - center.y) <= r {
                damageBoss(amount: missile.damage)
            }
        }
        let flash = SKShapeNode(circleOfRadius: r)
        flash.fillColor = .orange
        flash.alpha = 0.6
        flash.position = center
        scene.addChild(flash)
        flash.run(.sequence([.fadeOut(withDuration: 0.2), .removeFromParent()]))
    }

    private func playerHit() {
        guard !ended else { return }
        audio.play(.playerHit)
        audio.notifyHit()
        let destroyed = playerController.takeHit()
        session.resetCombo()
        if destroyed {
            if session.shouldRespawnAfterDown() {
                // Spend a life and respawn with a fresh shield instead of
                // ending the run.
                session.loseLife()
                respawnPlayer()
            } else {
                session.forceShieldToZero()
                endGame(.defeat)
            }
        }
    }

    /// Respawn after losing a life: recentre, refill shield, grant a longer
    /// invincibility window, and wipe incoming bullets so the player isn't
    /// instantly re-hit on the spot.
    private func respawnPlayer() {
        guard let scene, let player = playerController?.player else { return }
        player.position = CGPoint(x: scene.frame.midX,
                                  y: scene.frame.minY + 120)
        playerController.refillShield()
        player.grantInvincibility(GameConfig.respawnInvincible)
        clearEnemyBullets(scene: scene)
        session.pushShield(GameConfig.shieldMax)
    }

    private func clearEnemyBullets(scene: SKScene) {
        for node in scene.children where node is EnemyBullet {
            node.removeFromParent()
        }
    }

    private func collectItem(_ item: DropItem) {
        audio.play(.pickup)
        audio.notifyPickup()
        switch item.kind {
        case .core(let w):   _ = session.upgradeWeapon(w)
        case .repair:        playerController.repair()
        case .life:          session.addLife()
        }
        item.removeFromParent()
    }

    // MARK: Boss lifecycle
    private func spawnBoss() {
        guard let scene else { return }
        audio.play(.bossAlert)
        let kind = spawner.pickBossKind()
        let b = Boss(kind: kind)
        b.position = CGPoint(x: scene.frame.midX, y: scene.frame.maxY + 120)
        scene.addChild(b)
        boss = b
        bossActive = true
        bossDead = false
        session.setBossFight(true)
        session.setBossHP(1)
        session.setBossName(kind.spec.name)
    }

    private func clearField() {
        guard let scene else { return }
        for node in scene.children where node is Enemy || node is EnemyBullet {
            node.removeFromParent()
        }
    }

    // MARK: Helpers
    private func liveTargets() -> [SKNode] {
        guard let scene else { return [] }
        var nodes: [SKNode] = []
        for node in scene.children {
            if let e = node as? Enemy, e.parent != nil { nodes.append(e) }
        }
        if let b = boss, b.parent != nil { nodes.append(b) }
        return nodes
    }

    private func updateEnemies(_ dt: TimeInterval, scene: SKScene) {
        let enemies = scene.children.compactMap { $0 as? Enemy }
        let p = playerController.player.position
        for e in enemies { e.update(dt: dt, scene: scene, playerPos: p) }
    }

    private func updateBoss(_ dt: TimeInterval, scene: SKScene) {
        guard let boss else { return }
        let ctx = BossContext(
            scene: scene,
            playerPos: playerController.player.position,
            enraged: session.bossEnraged,
            fireBullet: { [weak self] from, angle, speed, dmg in
                self?.spawnBossBullet(from: from, angle: angle, speed: speed, damage: dmg)
            },
            summonMinion: { [weak self] at in
                self?.spawner.spawnMinion(at: at, scene: scene)
            },
            audio: audio,
            onPhaseChange: { [weak self] _ in
                self?.session.setBossHP(CGFloat(boss.hp) / CGFloat(boss.maxHP))
            }
        )
        bossStateMachine.update(boss, dt: dt, ctx: ctx)
        session.setBossHP(CGFloat(boss.hp) / CGFloat(boss.maxHP))
    }

    private func spawnBossBullet(from: CGPoint, angle: CGFloat, speed: CGFloat, damage: Int) {
        let bullet = EnemyBullet.make(damage: damage)
        bullet.position = from
        bullet.velocity = CGVector(dx: cos(angle) * speed, dy: sin(angle) * speed)
        scene?.addChild(bullet)
    }

    private func cullProjectiles(scene: SKScene) {
        let margin: CGFloat = 80
        for node in scene.children {
            if let p = node as? Projectile,
               p.position.y < scene.frame.minY - margin
               || p.position.y > scene.frame.maxY + margin
               || p.position.x < -margin
               || p.position.x > scene.frame.maxX + margin {
                p.removeFromParent()
            }
        }
    }

    // MARK: End of match (single-trigger)
    private func endGame(_ result: GameResult) {
        guard !ended else { return }
        ended = true
        session.endGame(result)
        audio.pauseAll()
        onGameEnd(result)
    }
}

// MARK: - LaserDamageTarget (column damage from the piercing laser)

extension GameCoordinator: LaserDamageTarget {
    func laserHitEnemy(_ enemy: Enemy, amount: Int) {
        damageEnemy(enemy, amount: amount)
    }

    func laserHitBoss(_ boss: Boss, amount: Int) {
        damageBoss(amount: amount)
    }
}
