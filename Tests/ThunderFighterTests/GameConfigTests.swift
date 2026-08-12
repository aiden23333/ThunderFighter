import XCTest
@testable import ThunderFighter

/// Guards the tuning invariants the game balance depends on. If someone
/// "tweaks" these, the test fails loudly instead of shipping a broken build.
final class GameConfigTests: XCTestCase {

    func testLivesInvariant() {
        XCTAssertGreaterThan(GameConfig.startingLives, 0)
        XCTAssertGreaterThanOrEqual(GameConfig.maxLives, GameConfig.startingLives,
                                    "you can't start with more lives than the cap")
    }

    func testEndlessTimingIsPositiveAndOrdered() {
        XCTAssertGreaterThan(GameConfig.endlessFirstBossAt, 0)
        XCTAssertGreaterThan(GameConfig.endlessBossInterval, 0)
        XCTAssertGreaterThan(GameConfig.endlessWaveIntervalStart,
                             GameConfig.endlessWaveIntervalMin,
                             "waves must tighten, not loosen")
    }

    func testWeaponLevelCap() {
        XCTAssertEqual(GameConfig.maxWeaponLevel, 3)
        XCTAssertEqual(GameConfig.mainDamageByLevel.count, 4, "index 0 unused + 3 levels")
    }

    func testShieldMaxPositive() {
        XCTAssertGreaterThan(GameConfig.shieldMax, 0)
    }
}
