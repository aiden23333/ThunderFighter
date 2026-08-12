import Foundation

/// Small, fast, deterministic PRNG (xorshift64*). Using a fixed seed makes
/// enemy spawns and drops reproducible, which is what the spec asks for in the
/// "stability / testing" section.
struct GameRandom {
    private var state: UInt64

    init(seed: UInt64) {
        // Avoid a zero state which would stick at zero.
        self.state = (seed == 0) ? 0x9E3779B97F4A7C15 : seed
    }

    /// Next raw 64-bit value.
    mutating func next() -> UInt64 {
        var x = state
        x ^= x << 13
        x ^= x >> 7
        x ^= x << 17
        state = x
        return x
    }

    /// Uniform double in [0, 1).
    mutating func float() -> Double {
        Double(next() & 0x1FFFFFFFFFFFFF) / Double(0x20000000000000)
    }

    /// Uniform integer in `range` (inclusive, closed).
    mutating func int(in range: ClosedRange<Int>) -> Int {
        let span = UInt64(range.upperBound - range.lowerBound + 1)
        return range.lowerBound + Int(next() % span)
    }

    /// True with probability `p`.
    mutating func bool(probability p: Double) -> Bool {
        float() < p
    }
}
