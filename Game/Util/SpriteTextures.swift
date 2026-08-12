import SpriteKit

/// Names of the optional sprite-sheet assets. The game runs fine without them
/// (it falls back to procedurally drawn placeholders), but dropping PNGs with
/// these exact filenames into the bundle upgrades the visuals automatically.
enum SpriteAsset: String {
    case player       = "ship_player"
    case enemyNormal0 = "enemy_normal_0"
    case enemyNormal1 = "enemy_normal_1"
    case enemyNormal2 = "enemy_normal_2"
    case elite        = "enemy_elite"
    case boss         = "boss"
    case coreMain     = "core_main"
    case coreMissile  = "core_missile"
    case coreLaser    = "core_laser"
    case repair       = "item_repair"
    case life         = "item_life"
    case boss2        = "boss2"
    case boss3        = "boss3"
}

/// Central, fail-safe loader. Returns nil (never throws, never crashes) when an
/// asset is absent, so every caller can fall back to a vector placeholder — this
/// keeps the "missing art must not crash" requirement intact.
enum SpriteTextures {
    static func texture(_ asset: SpriteAsset) -> SKTexture? {
        guard Bundle.main.path(forResource: asset.rawValue, ofType: "png") != nil else {
            return nil
        }
        return SKTexture(imageNamed: asset.rawValue)
    }

    /// Scale a sprite so its texture fits inside `box` while preserving aspect
    /// ratio (no stretching). Sets both the texture and the node size.
    static func fit(_ node: SKSpriteNode, texture: SKTexture, into box: CGSize) {
        let scale = min(box.width / texture.size().width,
                        box.height / texture.size().height)
        node.texture = texture
        node.size = CGSize(width: texture.size().width * scale,
                           height: texture.size().height * scale)
    }
}
