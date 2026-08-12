import Foundation
import Combine

/// Single source of truth for everything the HUD shows and the end screen
/// reports. Systems write to it; the HUD only reads from it. This keeps the
/// data flow strictly one-directional (input → systems → session → HUD).
final class GameSession: ObservableObject {

    let shieldMax = GameConfig.shieldMax

    // MARK: HUD-readable state (published for SwiftUI)
    @Published private(set) var mode: GameMode = .level
    @Published private(set) var score: Int = 0
    @Published private(set) var combo: Int = 0
    @Published private(set) var multiplier: Int = 1
    @Published private(set) var maxCombo: Int = 0
    @Published private(set) var kills: Int = 0
    @Published private(set) var shield: Int = GameConfig.shieldMax
    @Published private(set) var lives: Int = 0
    @Published private(set) var bossesDefeated: Int = 0
    @Published private(set) var bossDefeated: Bool = false
    @Published private(set) var bossEnraged: Bool = false
    @Published private(set) var inBossFight: Bool = false
    @Published private(set) var bossHP: CGFloat = 1.0
    @Published private(set) var bossName: String = ""
    @Published private(set) var weaponLevels: [WeaponType: Int] = [:]
    @Published private(set) var laserCharge: CGFloat = 1.0
    @Published private(set) var elapsed: TimeInterval = 0
    @Published private(set) var result: GameResult? = nil

    // MARK: Lifecycle
    func reset(mode: GameMode) {
        self.mode = mode
        score = 0; combo = 0; multiplier = 1; maxCombo = 0; kills = 0
        shield = shieldMax
        lives = (mode == .endless) ? GameConfig.startingLives : 1
        bossesDefeated = 0
        bossDefeated = false; bossEnraged = false
        inBossFight = false; bossHP = 1.0; bossName = ""
        weaponLevels = [.main: 1, .missile: 1, .laser: 1]
        laserCharge = 1.0; elapsed = 0; result = nil
    }

    /// Advance the match clock (written only by the coordinator loop).
    func advanceTime(_ dt: TimeInterval) {
        elapsed += dt
    }

    /// Hard-zero the shield when the last point is lost (defeat).
    func forceShieldToZero() {
        shield = 0
    }

    /// Mirror the live shield value from `PlayerController` into the session.
    func pushShield(_ value: Int) {
        shield = value
    }

    // MARK: Score & combo
    func registerKill(baseScore: Int) {
        kills += 1
        combo += 1
        if combo > maxCombo { maxCombo = combo }
        multiplier = Self.multiplierForCombo(combo)
        score += baseScore * multiplier
    }

    static func multiplierForCombo(_ combo: Int) -> Int {
        let step = GameConfig.comboPerMultiplierStep
        return min(GameConfig.maxScoreMultiplier, 1 + combo / step)
    }

    /// Getting hit resets the combo/multiplier but NEVER the weapon levels.
    func resetCombo() {
        combo = 0
        multiplier = 1
    }

    // MARK: Shield
    /// Returns true when the last point of shield was lost (player destroyed).
    @discardableResult
    func applyDamage() -> Bool {
        shield = max(0, shield - 1)
        resetCombo()
        return shield <= 0
    }

    func repairShield() {
        shield = min(shieldMax, shield + 1)
    }

    // MARK: Lives (endless mode)
    /// Spend one life. Returns the remaining life count.
    @discardableResult
    func loseLife() -> Int {
        lives = max(0, lives - 1)
        return lives
    }

    /// Grant an extra life (capped).
    func addLife() {
        lives = min(GameConfig.maxLives, lives + 1)
    }

    /// The coordinator asks this right after the shield is gone: should the
    /// player respawn by spending a life, or is the run over? Endless mode with
    /// more than one life left respawns; everything else ends the game. Kept
    /// here (instead of inline in the coordinator) so the rule is unit-testable
    /// and the coordinator stays a thin caller.
    func shouldRespawnAfterDown() -> Bool {
        mode == .endless && lives > 1
    }

    // MARK: Weapons
    /// Upgrades the weapon one level (capped). Returns the new level.
    @discardableResult
    func upgradeWeapon(_ type: WeaponType) -> Int {
        let cur = weaponLevels[type] ?? 1
        let next = min(GameConfig.maxWeaponLevel, cur + 1)
        weaponLevels[type] = next
        return next
    }

    func setLaserCharge(_ value: CGFloat) {
        laserCharge = max(0, min(1, value))
    }

    // MARK: Boss
    func setBossFight(_ active: Bool) {
        inBossFight = active
        if !active { bossHP = 1; bossName = "" }
    }

    func setBossHP(_ value: CGFloat) {
        bossHP = max(0, min(1, value))
    }

    func setBossEnraged(_ value: Bool) {
        bossEnraged = value
    }

    func setBossName(_ name: String) {
        bossName = name
    }

    func registerBossDefeat() {
        bossesDefeated += 1
    }

    // MARK: End of game (single-trigger guard)
    func endGame(_ result: GameResult) {
        guard self.result == nil else { return }
        self.result = result
        self.bossDefeated = (result == .victory)
    }
}
