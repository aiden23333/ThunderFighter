import SpriteKit

/// Spawns enemy formations, the elite, and the boss. Behaviour depends on the
/// match `mode`:
///   - `.level`   → follows `LevelTimeline` (fixed 3-minute level).
///   - `.endless` → continuous waves, periodic elites, and a rotating cast of
///                  random bosses; runs until the player's lives run out.
/// All randomness goes through a seeded `GameRandom` so a given seed reproduces
/// the exact same run (required for debugging / tests).
final class EnemySpawner {

    private let mode: GameMode
    private let seed: UInt64
    private var rng: GameRandom
    private var nextSpawnAt: TimeInterval = 0
    private var eliteSpawned = false
    private var bossSpawned = false

    // Endless-only scheduling state.
    private var nextBossAt: TimeInterval = 0
    private var nextEliteAt: TimeInterval = 0
    private var bossPending = false
    private var lastBossKind: BossKind?

    let timeline = LevelTimeline()

    /// Coordinator hooks.
    var onClearField: (() -> Void)?
    var onSpawnBoss: (() -> Void)?

    init(mode: GameMode = .level, seed: UInt64? = nil) {
        self.mode = mode
        // Endless gets a fresh random seed each run for variety; the level mode
        // uses the fixed seed so replays are deterministic.
        self.seed = seed ?? (mode == .endless
                             ? UInt64.random(in: 0...UInt64.max)
                             : GameConfig.fixedSeed)
        self.rng = GameRandom(seed: self.seed)
    }

    func reset() {
        rng = GameRandom(seed: seed)
        nextSpawnAt = 0
        eliteSpawned = false
        bossSpawned = false
        nextBossAt = GameConfig.endlessFirstBossAt
        nextEliteAt = GameConfig.endlessEliteInterval
        bossPending = false
        lastBossKind = nil
    }

    /// Called every frame by the coordinator.
    /// `bossActive`/`bossDead` come from the live boss so the right phase runs.
    func update(elapsed: TimeInterval,
                bossActive: Bool,
                bossDead: Bool,
                scene: SKScene,
                playerPos: CGPoint) {
        if mode == .level {
            updateLevel(elapsed: elapsed, bossActive: bossActive, bossDead: bossDead, scene: scene)
        } else {
            updateEndless(elapsed: elapsed, bossActive: bossActive, scene: scene, playerPos: playerPos)
        }
    }

    /// Whether the boss has been triggered yet (coordinator uses this to know
    /// the fight is on). Level mode only.
    var isBossSpawned: Bool { bossSpawned }

    // MARK: Level mode (fixed 3-minute timeline)

    private func updateLevel(elapsed: TimeInterval,
                             bossActive: Bool,
                             bossDead: Bool,
                             scene: SKScene) {
        let phase = timeline.phase(at: elapsed, bossActive: bossActive, bossDead: bossDead)

        switch phase {
        case .normal, .elite:
            guard !bossSpawned else { return }
            let interval: TimeInterval = (phase == .elite) ? 0.9 : 1.4
            if elapsed >= nextSpawnAt {
                nextSpawnAt = elapsed + interval
                spawnWave(elapsed: elapsed, phase: phase, scene: scene)
                if phase == .elite, !eliteSpawned {
                    eliteSpawned = true
                    spawnElite(scene: scene)
                }
            }

        case .boss, .enraged:
            if !bossSpawned {
                bossSpawned = true
                onClearField?()
                onSpawnBoss?()
            }
        }
    }

    // MARK: Endless mode

    private func updateEndless(elapsed: TimeInterval,
                               bossActive: Bool,
                               scene: SKScene,
                               playerPos: CGPoint) {
        // Trigger the next boss once the previous one is dead and the interval
        // has elapsed. Clear the field first for a breather.
        if !bossActive, !bossPending, elapsed >= nextBossAt {
            bossPending = true
            onClearField?()
            onSpawnBoss?()
            return
        }

        // While a boss is alive, hold off on normal waves.
        if bossActive { return }

        let interval = waveInterval(elapsed)
        if elapsed >= nextSpawnAt {
            nextSpawnAt = elapsed + interval
            spawnEndlessWave(scene: scene)
        }

        if elapsed >= nextEliteAt {
            nextEliteAt = elapsed + GameConfig.endlessEliteInterval
            spawnElite(scene: scene)
        }
    }

    /// Called by the coordinator when a boss is defeated, so the next one is
    /// scheduled.
    func notifyBossDefeated(elapsed: TimeInterval) {
        bossPending = false
        nextBossAt = elapsed + GameConfig.endlessBossInterval
    }

    /// Which boss to spawn next. Level mode always uses the sentinel; endless
    /// picks a random kind that differs from the previous one.
    func pickBossKind() -> BossKind {
        if mode == .level { return .sentinel }
        let k = BossKind.random(rng: &rng, avoid: lastBossKind)
        lastBossKind = k
        return k
    }

    private func waveInterval(_ elapsed: TimeInterval) -> TimeInterval {
        let t = min(1, elapsed / 180)
        return GameConfig.endlessWaveIntervalStart
             - (GameConfig.endlessWaveIntervalStart - GameConfig.endlessWaveIntervalMin) * t
    }

    private func spawnEndlessWave(scene: SKScene) {
        let count = rng.int(in: 3...6)
        for i in 0..<count {
            let x = scene.frame.width * (CGFloat(i + 1) / CGFloat(count + 1))
            let core = WeaponType.allCases[rng.int(in: 0...2)]
            let flavor = rng.int(in: 0...2)
            let enemy = NormalEnemy(flavor: flavor, coreType: core)
            enemy.position = CGPoint(x: x, y: scene.frame.maxY + 40)
            enemy.baseX = x
            scene.addChild(enemy)
        }
    }

    // MARK: Wave building (level mode)
    private func spawnWave(elapsed: TimeInterval, phase: LevelTimeline.Phase, scene: SKScene) {
        let count = (phase == .elite)
            ? rng.int(in: 3...5)
            : rng.int(in: 2...4)
        let flavor = rng.int(in: 0...2)
        let core = teachingCore(elapsed)

        for i in 0..<count {
            let x = scene.frame.width * (CGFloat(i + 1) / CGFloat(count + 1))
            let enemy = NormalEnemy(flavor: flavor, coreType: core)
            enemy.position = CGPoint(x: x, y: scene.frame.maxY + 40)
            enemy.baseX = x
            scene.addChild(enemy)
        }
    }

    private func spawnElite(scene: SKScene) {
        let elite = EliteEnemy(coreType: .laser)
        elite.position = CGPoint(x: scene.frame.midX, y: scene.frame.maxY + 70)
        elite.baseX = scene.frame.midX
        scene.addChild(elite)
    }

    /// A minion summoned by the boss (uses the same seeded RNG so the run stays
    /// reproducible). These carry no core.
    func spawnMinion(at point: CGPoint, scene: SKScene) {
        let flavor = rng.int(in: 0...2)
        let enemy = NormalEnemy(flavor: flavor, coreType: nil)
        enemy.position = point
        enemy.baseX = point.x
        scene.addChild(enemy)
    }

    /// Teaching order: introduce one weapon's core at a time across the first
    /// 90 seconds so the player learns all three drops naturally.
    private func teachingCore(_ elapsed: TimeInterval) -> WeaponType {
        if elapsed < 30 { return .main }
        if elapsed < 60 { return .missile }
        return .laser
    }

    // MARK: Drops (rolled with the same seeded RNG → reproducible)
    func rollDrop(for enemy: Enemy, scene: SKScene) {
        // Weapon cores drop from enemies that carry one.
        if let core = enemy.coreType {
            let chance = enemy.isElite ? 1.0 : GameConfig.dropChance
            if rng.bool(probability: chance) {
                let item = DropItem(kind: .core(core))
                item.position = enemy.position
                scene.addChild(item)
                item.startFalling(in: scene)
            }
        }

        if enemy.isElite {
            // Elites always drop something useful; in endless it's a shield or a life.
            if mode == .endless {
                let item = rng.bool(probability: GameConfig.eliteLifeChance)
                    ? DropItem(kind: .life)
                    : DropItem(kind: .repair)
                item.position = enemy.position
                scene.addChild(item)
                item.startFalling(in: scene)
            }
            return
        }

        // Regular enemies: occasional shield repair, plus (endless only) a small
        // chance at an extra life.
        if rng.bool(probability: GameConfig.repairDropChance) {
            let item = DropItem(kind: .repair)
            item.position = CGPoint(x: enemy.position.x + 22, y: enemy.position.y)
            scene.addChild(item)
            item.startFalling(in: scene)
        }
        if mode == .endless, rng.bool(probability: GameConfig.lifeDropChance) {
            let item = DropItem(kind: .life)
            item.position = CGPoint(x: enemy.position.x - 22, y: enemy.position.y)
            scene.addChild(item)
            item.startFalling(in: scene)
        }
    }
}
