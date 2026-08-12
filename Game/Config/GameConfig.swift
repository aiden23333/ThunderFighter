import Foundation

/// Central tuning constants for the first (and currently only) level.
/// Anything that controls balance or timing lives here so designers can tweak
/// without touching gameplay code.
struct GameConfig {

    // MARK: Level timeline (seconds)
    static let totalDuration: TimeInterval = 180
    /// 0–90s: normal formations, teaching drops.
    static let normalPhaseEnd: TimeInterval = 90
    /// 90–150s: denser waves + one elite.
    static let elitePhaseEnd: TimeInterval = 150
    /// 150s: clear field, boss entrance animation.
    static let bossSpawnTime: TimeInterval = 150
    /// If the boss is still alive at this time it enters the enrage state.
    static let bossTimeLimit: TimeInterval = 180

    // MARK: Player
    static let shieldMax: Int = 3
    static let invincibleDuration: TimeInterval = 1.2
    /// Inset from the scene frame that the ship may travel within.
    static let playerMargin: CGFloat = 28

    // MARK: Weapons
    static let maxWeaponLevel: Int = 3
    static let baseMainCooldown: TimeInterval = 0.18
    static let baseMissileCooldown: TimeInterval = 0.9
    static let baseLaserChargeTime: TimeInterval = 3.0

    // MARK: Damage
    static let mainDamageByLevel: [Int] = [0, 10, 14, 18]
    static let missileDamageByLevel: [Int] = [0, 18, 22, 26]
    static let missileBlastRadiusByLevel: [CGFloat] = [0, 60, 80, 110]
    static let laserDamageByLevel: [Int] = [0, 30, 42, 56]
    static let laserWidthByLevel: [CGFloat] = [0, 22, 34, 50]
    static let laserChargeTimeByLevel: [TimeInterval] = [0, 3.0, 2.4, 1.8]

    // MARK: Enemies
    static let normalEnemyHP: [Int] = [20, 28, 36]      // three flavours
    static let eliteEnemyHP: Int = 220
    static let bossMaxHP: Int = 1600

    // MARK: Score
    static let baseKillScore: Int = 100
    static let eliteKillScore: Int = 500
    static let bossKillScore: Int = 5000
    static let maxScoreMultiplier: Int = 8
    /// Every N consecutive kills raises the multiplier by 1.
    static let comboPerMultiplierStep: Int = 5

    // MARK: Drops
    static let dropChance: Double = 0.35
    static let repairDropChance: Double = 0.10

    // MARK: Stability / testing
    static let fixedSeed: UInt64 = 20260811

    // MARK: Endless mode
    static let startingLives: Int = 3
    static let maxLives: Int = 5
    static let respawnInvincible: TimeInterval = 2.0
    static let endlessFirstBossAt: TimeInterval = 25
    static let endlessBossInterval: TimeInterval = 42
    static let endlessEliteInterval: TimeInterval = 32
    static let endlessWaveIntervalStart: TimeInterval = 1.6
    static let endlessWaveIntervalMin: TimeInterval = 0.7
    static let lifeDropChance: Double = 0.05
    static let eliteLifeChance: Double = 0.5
}
