import UIKit
import SpriteKit

// MARK: - Weapon types

enum WeaponType: CaseIterable, Hashable {
    case main, missile, laser

    var id: String {
        switch self {
        case .main: return "main"
        case .missile: return "missile"
        case .laser: return "laser"
        }
    }

    var displayName: String {
        switch self {
        case .main: return "主炮"
        case .missile: return "追踪导弹"
        case .laser: return "贯穿激光"
        }
    }

    /// Core / accent colour used for the weapon, its bullets and dropped cores.
    var coreColor: UIColor {
        switch self {
        case .main:   return UIColor(red: 0.30, green: 0.80, blue: 1.00, alpha: 1)
        case .missile: return UIColor(red: 1.00, green: 0.55, blue: 0.20, alpha: 1)
        case .laser:  return UIColor(red: 0.45, green: 1.00, blue: 0.55, alpha: 1)
        }
    }
}

// MARK: - Game mode

enum GameMode: CaseIterable {
    case level    // fixed 3-minute level
    case endless  // survival: random bosses, lives, ends when lives run out
}

// MARK: - Game result / phase

enum GameResult {
    case victory
    case defeat
}

enum GamePhase {
    case home
    case playing
    case paused
    case result
}

// MARK: - Physics categories (CollisionSystem)

struct PhysicsCategory: OptionSet {
    let rawValue: UInt32

    static let player       = PhysicsCategory(rawValue: 0x1)
    static let playerBullet = PhysicsCategory(rawValue: 0x2)
    static let enemy        = PhysicsCategory(rawValue: 0x4)
    static let enemyBullet  = PhysicsCategory(rawValue: 0x8)
    static let boss         = PhysicsCategory(rawValue: 0x10)
    static let item         = PhysicsCategory(rawValue: 0x20)
}
