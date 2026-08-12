import SpriteKit

/// A semantic description of what collided. `GameScene` turns every physics
/// contact into one of these and hands it to the coordinator, which applies
/// damage / spawns drops. Gameplay code never reads raw `SKPhysicsContact`.
enum CollisionEvent {
    case playerShotEnemy(bullet: Projectile, enemy: Enemy)
    case playerShotBoss(bullet: Projectile)
    case enemyShotPlayer(bullet: EnemyBullet)
    case enemyRamPlayer(enemy: Enemy)
    case bossRamPlayer
    case playerGotItem(item: DropItem)
}

/// Owns the category-bit definitions and the contact → event translation.
/// Keeping this in one place means adding a new interactable is a one-file change.
struct CollisionSystem {

    /// Translate a raw SpriteKit contact into a semantic `CollisionEvent`.
    /// Returns `nil` when the pair is not something we care about.
    static func route(_ contact: SKPhysicsContact) -> CollisionEvent? {
        let a = contact.bodyA
        let b = contact.bodyB
        let ca = PhysicsCategory(rawValue: a.categoryBitMask)
        let cb = PhysicsCategory(rawValue: b.categoryBitMask)

        /// Returns (first, second) ordered so the first matches `c1`.
        func ordered(_ c1: PhysicsCategory, _ c2: PhysicsCategory)
            -> (SKPhysicsBody, SKPhysicsBody)? {
            if ca == c1 && cb == c2 { return (a, b) }
            if ca == c2 && cb == c1 { return (b, a) }
            return nil
        }

        // player bullet → enemy
        if let (bulletBody, enemyBody) = ordered(.playerBullet, .enemy),
           let bullet = bulletBody.node as? Projectile,
           let enemy = enemyBody.node as? Enemy {
            return .playerShotEnemy(bullet: bullet, enemy: enemy)
        }

        // player bullet → boss
        if let (bulletBody, _) = ordered(.playerBullet, .boss),
           let bullet = bulletBody.node as? Projectile {
            return .playerShotBoss(bullet: bullet)
        }

        // enemy bullet → player
        if let (bulletBody, _) = ordered(.enemyBullet, .player),
           let bullet = bulletBody.node as? EnemyBullet {
            return .enemyShotPlayer(bullet: bullet)
        }

        // enemy → player (ramming)
        if let (enemyBody, _) = ordered(.enemy, .player),
           let enemy = enemyBody.node as? Enemy {
            return .enemyRamPlayer(enemy: enemy)
        }

        // boss → player (ramming)
        if ordered(.boss, .player) != nil {
            return .bossRamPlayer
        }

        // item → player
        if let (itemBody, _) = ordered(.item, .player),
           let item = itemBody.node as? DropItem {
            return .playerGotItem(item: item)
        }

        return nil
    }
}
