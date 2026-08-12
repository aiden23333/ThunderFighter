import SpriteKit

/// The different bosses the game can throw at the player. Each has its own
/// look, durability and attack bias so "random boss" actually feels different.
enum BossKind: CaseIterable {
    case sentinel   // balanced (the original level boss)
    case tempest    // fast, dense fan, quick sweeps
    case colossus   // tanky, heavy charge, harder-hitting bullets

    /// Per-kind visual / durability setup.
    var spec: BossSpec {
        switch self {
        case .sentinel:
            return BossSpec(maxHP: 1600, size: CGSize(width: 120, height: 90),
                            color: .systemRed, asset: .boss, name: "哨戒者")
        case .tempest:
            return BossSpec(maxHP: 1400, size: CGSize(width: 100, height: 80),
                            color: .systemPurple, asset: .boss2, name: "风暴使")
        case .colossus:
            return BossSpec(maxHP: 2200, size: CGSize(width: 150, height: 110),
                            color: .systemOrange, asset: .boss3, name: "巨像")
        }
    }

    /// Per-kind attack tuning consumed by `BossStateMachine`.
    var tuning: BossTuning {
        switch self {
        case .sentinel:
            return BossTuning(fanSpeed: 200, fanCountBias: 0, sweepSpeed: 300,
                              chargeMul: 1.0, bulletDamage: 1)
        case .tempest:
            return BossTuning(fanSpeed: 250, fanCountBias: 4, sweepSpeed: 360,
                              chargeMul: 1.2, bulletDamage: 1)
        case .colossus:
            return BossTuning(fanSpeed: 170, fanCountBias: 2, sweepSpeed: 260,
                              chargeMul: 1.35, bulletDamage: 2)
        }
    }

    /// Pick a random kind that isn't `avoid` (so two bosses in a row differ).
    static func random(rng: inout GameRandom, avoid: BossKind? = nil) -> BossKind {
        let all = BossKind.allCases
        guard all.count > 1, let avoid else {
            return all[rng.int(in: 0...(all.count - 1))]
        }
        var k = all[rng.int(in: 0...(all.count - 1))]
        if k == avoid {
            let idx = all.firstIndex(of: avoid)!
            k = all[(idx + 1) % all.count]
        }
        return k
    }
}

struct BossSpec {
    let maxHP: Int
    let size: CGSize
    let color: UIColor
    let asset: SpriteAsset
    let name: String
}

struct BossTuning {
    let fanSpeed: CGFloat        // speed of fan-barrage bullets
    let fanCountBias: Int        // extra fan bullets vs. sentinel
    let sweepSpeed: CGFloat      // laser-sweep bullet speed
    let chargeMul: CGFloat       // multiplies charge-dash speed
    let bulletDamage: Int        // damage of boss bullets
}

/// Explicit lifecycle states for the boss. The state machine drives behaviour;
/// the `Boss` node only holds data + a body.
enum BossState {
    case entering   // descent animation, no attacks
    case phase1     // fan barrage + summon minions
    case phase2     // + laser sweep + charge (triggered at <=50% HP)
    case defeated
}

/// Everything the boss attacks need from the outside world, passed in each
/// frame so the state machine stays decoupled from spawner / coordinator.
struct BossContext {
    let scene: SKScene
    let playerPos: CGPoint
    let enraged: Bool
    let fireBullet: (_ from: CGPoint, _ angle: CGFloat, _ speed: CGFloat, _ damage: Int) -> Void
    let summonMinion: (_ at: CGPoint) -> Void
    let audio: AudioManager
    let onPhaseChange: (_ to: BossState) -> Void
}

/// The boss. Holds HP, position, attack timers and the current state. All
/// behaviour lives in `BossStateMachine`.
final class Boss: SKSpriteNode {

    let kind: BossKind
    let bossName: String
    var hp: Int
    let maxHP: Int
    var state: BossState = .entering

    // attack timers
    var fanTimer: TimeInterval = 1.5
    var summonTimer: TimeInterval = 3.0
    var sweepTimer: TimeInterval = 3.0
    var sweepActive: Bool = false
    var sweepElapsed: TimeInterval = 0
    var sweepAngle: CGFloat = .pi / 2
    var chargeTimer: TimeInterval = 5.0
    var chargeActive: Bool = false
    var chargeToX: CGFloat = 0
    var hoverT: TimeInterval = 0

    var enraged: Bool = false

    init(kind: BossKind = .sentinel) {
        self.kind = kind
        let spec = kind.spec
        self.maxHP = spec.maxHP
        self.hp = spec.maxHP
        self.bossName = spec.name
        let size = spec.size
        super.init(texture: nil, color: .clear, size: size)

        if let tex = SpriteTextures.texture(spec.asset) {
            SpriteTextures.fit(self, texture: tex, into: size)
        } else {
            let hull = SKShapeNode(rectOf: size, cornerRadius: 16)
            hull.fillColor = spec.color
            hull.strokeColor = .white
            hull.lineWidth = 3
            addChild(hull)

            let core = SKShapeNode(circleOfRadius: min(size.width, size.height) * 0.18)
            core.fillColor = .systemYellow
            core.strokeColor = .clear
            addChild(core)
        }

        let body = SKPhysicsBody(rectangleOf: self.size)
        body.categoryBitMask = PhysicsCategory.boss.rawValue
        body.contactTestBitMask = PhysicsCategory.playerBullet.rawValue | PhysicsCategory.player.rawValue
        body.collisionBitMask = 0
        physicsBody = body
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @discardableResult
    func takeDamage(_ amount: Int) -> Bool {
        hp -= amount
        run(SKAction.sequence([.fadeAlpha(to: 0.5, duration: 0.04),
                               .fadeAlpha(to: 1, duration: 0.06)]))
        return hp <= 0
    }
}
