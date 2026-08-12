import SpriteKit

/// What a dropped pickup grants.
enum DropKind {
    case core(WeaponType)
    case repair
    case life
}

/// A falling pickup. Moved kinematically (no gravity) by an `SKAction`; contacts
/// the player to be collected. Visual colour encodes the weapon it upgrades.
final class DropItem: SKSpriteNode {

    let kind: DropKind

    init(kind: DropKind) {
        self.kind = kind
        let size = CGSize(width: 22, height: 22)
        super.init(texture: nil, color: .clear, size: size)

        let asset: SpriteAsset? = {
            switch kind {
            case .core(let w):
                switch w {
                case .main:    return .coreMain
                case .missile: return .coreMissile
                case .laser:   return .coreLaser
                }
            case .repair: return .repair
            case .life:   return .life
            }
        }()

        if let a = asset, let tex = SpriteTextures.texture(a) {
            SpriteTextures.fit(self, texture: tex, into: size)
        } else {
            let color: UIColor = {
                switch kind {
                case .core(let w): return w.coreColor
                case .repair:      return .systemGreen
                case .life:        return .systemGreen
                }
            }()
            let shape = SKShapeNode(circleOfRadius: 11)
            shape.fillColor = color
            shape.strokeColor = .white
            shape.lineWidth = 2
            addChild(shape)

            // A small glyph so the different pickups are distinguishable even
            // without art: repair = cross, life = heart.
            if case .repair = kind {
                let plus = SKShapeNode(rectOf: CGSize(width: 10, height: 3))
                plus.fillColor = .white
                let plus2 = SKShapeNode(rectOf: CGSize(width: 3, height: 10))
                plus2.fillColor = .white
                addChild(plus); addChild(plus2)
            } else if case .life = kind {
                let heart = SKShapeNode(path: DropItem.heartPath(size: CGSize(width: 16, height: 16)))
                heart.fillColor = .white
                heart.position = .zero
                addChild(heart)
            }
        }

        let body = SKPhysicsBody(circleOfRadius: 11)
        body.categoryBitMask = PhysicsCategory.item.rawValue
        body.contactTestBitMask = PhysicsCategory.player.rawValue
        body.collisionBitMask = 0
        body.isDynamic = false   // moved by SKAction, not physics
        physicsBody = body
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Begin falling; auto-removed once off the bottom.
    func startFalling(in scene: SKScene) {
        let travel = position.y + 60
        let duration = max(0.1, travel / 140)
        run(SKAction.sequence([
            .moveTo(y: -60, duration: TimeInterval(duration)),
            .removeFromParent()
        ]))
    }

    /// Simple two-lobe heart, used as the vector fallback glyph for a life pickup.
    private static func heartPath(size: CGSize) -> CGPath {
        let w = size.width, h = size.height
        let path = CGMutablePath()
        let topY = h * 0.32
        path.move(to: CGPoint(x: w * 0.5, y: h * 0.92))
        path.addCurve(to: CGPoint(x: w * 0.08, y: topY),
                      control1: CGPoint(x: w * 0.12, y: h * 0.56),
                      control2: CGPoint(x: w * 0.08, y: h * 0.46))
        path.addCurve(to: CGPoint(x: w * 0.5, y: h * 0.18),
                      control1: CGPoint(x: w * 0.08, y: h * 0.10),
                      control2: CGPoint(x: w * 0.30, y: h * 0.04))
        path.addCurve(to: CGPoint(x: w * 0.92, y: topY),
                      control1: CGPoint(x: w * 0.70, y: h * 0.04),
                      control2: CGPoint(x: w * 0.92, y: h * 0.10))
        path.addCurve(to: CGPoint(x: w * 0.5, y: h * 0.92),
                      control1: CGPoint(x: w * 0.92, y: h * 0.46),
                      control2: CGPoint(x: w * 0.88, y: h * 0.56))
        path.closeSubpath()
        return path
    }
}
