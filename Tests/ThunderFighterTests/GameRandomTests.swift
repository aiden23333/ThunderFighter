import XCTest
@testable import ThunderFighter

/// The spec requires reproducible spawns/drops via a fixed seed. These tests
/// lock that determinism in so a refactor can't quietly make runs random.
final class GameRandomTests: XCTestCase {

    func testSameSeedProducesSameSequence() {
        var a = GameRandom(seed: 12345)
        var b = GameRandom(seed: 12345)
        for _ in 0..<200 {
            XCTAssertEqual(a.next(), b.next())
        }
    }

    func testDifferentSeedsDiverge() {
        var a = GameRandom(seed: 1)
        var b = GameRandom(seed: 2)
        var foundDifference = false
        for _ in 0..<200 {
            if a.next() != b.next() { foundDifference = true; break }
        }
        XCTAssertTrue(foundDifference, "different seeds must not produce identical streams")
    }

    func testZeroSeedAvoidsStuckZeroState() {
        // xorshift sticks at 0 if seeded with 0; the init must guard that.
        var r = GameRandom(seed: 0)
        XCTAssertNotEqual(r.next(), 0)
    }

    func testFloatStaysInUnitHalfOpenRange() {
        var r = GameRandom(seed: 999)
        for _ in 0..<2000 {
            let f = r.float()
            XCTAssertGreaterThanOrEqual(f, 0)
            XCTAssertLessThan(f, 1)
        }
    }

    func testIntStaysWithinClosedRange() {
        var r = GameRandom(seed: 42)
        for _ in 0..<2000 {
            let i = r.int(in: 0...3)
            XCTAssertGreaterThanOrEqual(i, 0)
            XCTAssertLessThanOrEqual(i, 3)
        }
    }
}
