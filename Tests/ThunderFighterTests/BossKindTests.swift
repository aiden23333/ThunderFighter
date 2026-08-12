import XCTest
@testable import ThunderFighter

/// Endless mode promises "random bosses, never the same one twice in a row".
/// These tests pin that behaviour and the three-boss roster down.
final class BossKindTests: XCTestCase {

    func testThreeBossKindsExist() {
        XCTAssertEqual(BossKind.allCases.count, 3,
                       "endless rotation needs exactly three bosses")
    }

    func testRandomNeverPicksTheAvoidedBoss() {
        var rng = GameRandom(seed: GameConfig.fixedSeed)
        var previous: BossKind? = nil
        for _ in 0..<100 {
            let next = BossKind.random(rng: &rng, avoid: previous)
            if let prev = previous {
                XCTAssertNotEqual(next, prev, "two bosses in a row must differ")
            }
            previous = next
        }
    }

    func testBossNamesAreUnique() {
        let names = BossKind.allCases.map { $0.spec.name }
        XCTAssertEqual(Set(names).count, names.count, "boss display names must be distinct")
    }

    func testBossSpecsCarryDistinctTuning() {
        // At least the colossus (tank) should differ from the sentinel baseline.
        let sentinel = BossKind.sentinel.spec
        let colossus = BossKind.colossus.spec
        XCTAssertGreaterThan(colossus.maxHP, sentinel.maxHP,
                             "colossus should be the tankier boss")
    }
}
