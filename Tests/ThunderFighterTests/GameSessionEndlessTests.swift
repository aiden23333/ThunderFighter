import XCTest
@testable import ThunderFighter

/// Covers the endless-mode contract that the HUD and the coordinator rely on:
/// starting lives, the +1-life cap, life loss, the respawn-vs-defeat decision,
/// boss-defeat counting, single-trigger end-of-game, and the combo/weapon rules.
final class GameSessionEndlessTests: XCTestCase {

    // MARK: Starting lives per mode
    func testEndlessStartsWithStartingLives() {
        let s = GameSession()
        s.reset(mode: .endless)
        XCTAssertEqual(s.lives, GameConfig.startingLives)
        XCTAssertEqual(s.lives, 3, "default endless starting lives")
    }

    func testLevelStartsWithOneLife() {
        let s = GameSession()
        s.reset(mode: .level)
        XCTAssertEqual(s.lives, 1, "level mode is a single-life run")
    }

    // MARK: +1 life cap
    func testAddLifeCapsAtMaxLives() {
        let s = GameSession()
        s.reset(mode: .endless)
        for _ in 0..<20 { s.addLife() }
        XCTAssertEqual(s.lives, GameConfig.maxLives)
        XCTAssertEqual(s.lives, 5, "life pickup must never exceed the cap")
    }

    // MARK: Losing lives
    func testLoseLifeNeverGoesNegative() {
        let s = GameSession()
        s.reset(mode: .endless) // 3 lives
        for _ in 0..<10 { _ = s.loseLife() }
        XCTAssertEqual(s.lives, 0)
        XCTAssertGreaterThanOrEqual(s.lives, 0)
    }

    // MARK: Respawn decision (the heart of endless revival)
    func testRespawnDecisionEndlessWithSpareLives() {
        let s = GameSession()
        s.reset(mode: .endless) // 3 lives
        // Shield gone while 3 lives remain -> respawn.
        XCTAssertTrue(s.shouldRespawnAfterDown())
        _ = s.loseLife()        // 2 lives
        XCTAssertTrue(s.shouldRespawnAfterDown())
        _ = s.loseLife()        // 1 life
        // Last life: taking the hit ends the run, not another respawn.
        XCTAssertFalse(s.shouldRespawnAfterDown())
    }

    func testRespawnDecisionLevelAlwaysEnds() {
        let s = GameSession()
        s.reset(mode: .level) // 1 life
        XCTAssertFalse(s.shouldRespawnAfterDown(), "level mode never respawns")
    }

    func testRespawnRefillsShieldContract() {
        // After a respawn the coordinator refills the shield to full. Mirror
        // that here so the contract is captured even without a live scene.
        let s = GameSession()
        s.reset(mode: .endless)
        s.pushShield(0)                 // shield wiped by the hit
        XCTAssertEqual(s.shield, 0)
        s.loseLife()                    // spend a life (3 -> 2)
        s.pushShield(GameConfig.shieldMax) // refill on respawn
        XCTAssertEqual(s.shield, GameConfig.shieldMax)
        XCTAssertEqual(s.lives, 2)
    }

    // MARK: Boss defeat counting (endless score is built on this)
    func testBossDefeatCounterIncrements() {
        let s = GameSession()
        s.reset(mode: .endless)
        XCTAssertEqual(s.bossesDefeated, 0)
        s.registerBossDefeat()
        s.registerBossDefeat()
        s.registerBossDefeat()
        XCTAssertEqual(s.bossesDefeated, 3)
    }

    // MARK: Single-trigger end of game
    func testEndGameIsSingleTrigger() {
        let s = GameSession()
        s.reset(mode: .level)
        s.endGame(.victory)
        s.endGame(.defeat) // must be ignored
        XCTAssertEqual(s.result, .victory)
        XCTAssertTrue(s.bossDefeated)
    }

    // MARK: Score / combo / weapon rules
    func testScoreMultiplierScalesWithComboAndCaps() {
        let s = GameSession()
        s.reset(mode: .level)
        for _ in 0..<5 { s.registerKill(baseScore: 100) }
        XCTAssertEqual(s.multiplier, 2, "every 5 kills raises the multiplier")
        for _ in 0..<60 { s.registerKill(baseScore: 100) }
        XCTAssertLessThanOrEqual(s.multiplier, GameConfig.maxScoreMultiplier)
    }

    func testHitResetsComboButKeepsWeaponLevels() {
        let s = GameSession()
        s.reset(mode: .level)
        _ = s.upgradeWeapon(.main)    // level 2
        _ = s.upgradeWeapon(.missile) // level 2
        for _ in 0..<10 { s.registerKill(baseScore: 100) }
        XCTAssertGreaterThan(s.combo, 1)
        s.resetCombo()
        XCTAssertEqual(s.combo, 0)
        XCTAssertEqual(s.multiplier, 1)
        // Weapons must NOT drop a level when hit.
        XCTAssertEqual(s.weaponLevels[.main], 2)
        XCTAssertEqual(s.weaponLevels[.missile], 2)
    }
}
