import Foundation

/// Describes the macro phases of a single 3-minute level. The spawner reads
/// this every frame to decide what to throw at the player.
struct LevelTimeline {

    enum Phase {
        case normal    // 0–90s
        case elite     // 90–150s
        case boss      // 150s+ until time limit
        case enraged   // boss still alive past the time limit
    }

    let normalPhaseEnd: TimeInterval
    let elitePhaseEnd: TimeInterval
    let bossSpawnTime: TimeInterval
    let bossTimeLimit: TimeInterval

    init(normalPhaseEnd: TimeInterval = GameConfig.normalPhaseEnd,
         elitePhaseEnd: TimeInterval = GameConfig.elitePhaseEnd,
         bossSpawnTime: TimeInterval = GameConfig.bossSpawnTime,
         bossTimeLimit: TimeInterval = GameConfig.bossTimeLimit) {
        self.normalPhaseEnd = normalPhaseEnd
        self.elitePhaseEnd = elitePhaseEnd
        self.bossSpawnTime = bossSpawnTime
        self.bossTimeLimit = bossTimeLimit
    }

    /// Current macro phase. `bossActive`/`bossDead` come from the live boss.
    func phase(at time: TimeInterval, bossActive: Bool, bossDead: Bool) -> Phase {
        if bossDead { return .boss }
        if bossActive {
            return time >= bossTimeLimit ? .enraged : .boss
        }
        if time < normalPhaseEnd { return .normal }
        return .elite
    }

    /// Seconds remaining in the whole level (used by the HUD countdown).
    func timeRemaining(_ time: TimeInterval) -> TimeInterval {
        max(0, totalDuration - time)
    }

    private var totalDuration: TimeInterval { GameConfig.totalDuration }
}
