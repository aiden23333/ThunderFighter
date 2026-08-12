import SpriteKit

/// Drives the boss through its explicit two-phase lifecycle. Pure logic — it
/// never creates nodes directly, it asks `BossContext` to fire bullets / summon
/// minions so the boss stays testable and decoupled. Attack intensity is scaled
/// by the boss's `BossTuning` so each `BossKind` plays differently.
struct BossStateMachine {

    func update(_ boss: Boss, dt: TimeInterval, ctx: BossContext) {
        switch boss.state {
        case .entering:
            updateEntering(boss, dt: dt, ctx: ctx)
        case .phase1:
            updatePhase1(boss, dt: dt, ctx: ctx)
        case .phase2:
            updatePhase2(boss, dt: dt, ctx: ctx)
        case .defeated:
            break
        }

        // Half-HP transition into phase 2 (the only automatic transition).
        if boss.state == .phase1,
           CGFloat(boss.hp) / CGFloat(boss.maxHP) <= 0.5 {
            boss.state = .phase2
            boss.fanTimer = 1.0
            ctx.audio.play(.bossAlert)
            ctx.onPhaseChange(.phase2)
        }
    }

    // MARK: Entering
    private func updateEntering(_ boss: Boss, dt: TimeInterval, ctx: BossContext) {
        let targetY = ctx.scene.frame.maxY - 150
        boss.position.x = ctx.scene.frame.midX
        boss.position.y += (targetY - boss.position.y) * min(1, dt * 2.5)
        if abs(boss.position.y - targetY) < 2 {
            boss.position.y = targetY
            boss.state = .phase1
            ctx.onPhaseChange(.phase1)
        }
    }

    // MARK: Phase 1 — fan barrage + summon
    private func updatePhase1(_ boss: Boss, dt: TimeInterval, ctx: BossContext) {
        hover(boss, dt: dt, ctx: ctx)

        boss.fanTimer -= dt
        if boss.fanTimer <= 0 {
            boss.fanTimer = ctx.enraged ? 1.4 : 2.2
            fanBarrage(boss, ctx: ctx, count: (ctx.enraged ? 14 : 10) + boss.kind.tuning.fanCountBias)
        }

        boss.summonTimer -= dt
        if boss.summonTimer <= 0 {
            boss.summonTimer = ctx.enraged ? 3.0 : 4.5
            ctx.summonMinion(CGPoint(x: boss.position.x, y: boss.position.y - 40))
        }
    }

    // MARK: Phase 2 — + laser sweep + charge
    private func updatePhase2(_ boss: Boss, dt: TimeInterval, ctx: BossContext) {
        let tune = boss.kind.tuning

        // Laser sweep: emit a rotating stream of bullets for a short window.
        if boss.sweepActive {
            boss.sweepElapsed += dt
            boss.sweepAngle += dt * 1.6
            ctx.fireBullet(boss.position, boss.sweepAngle, tune.sweepSpeed, tune.bulletDamage)
            if boss.sweepElapsed > 1.2 {
                boss.sweepActive = false
                boss.sweepTimer = ctx.enraged ? 3.0 : 4.5
            }
        } else {
            boss.sweepTimer -= dt
            if boss.sweepTimer <= 0 {
                boss.sweepActive = true
                boss.sweepElapsed = 0
                boss.sweepAngle = -.pi / 2   // start pointing down
                ctx.audio.play(.bossAlert)
            }
        }

        // Charge: dash toward the player's x, then settle back to hover.
        if boss.chargeActive {
            let dx = boss.chargeToX - boss.position.x
            boss.position.x += dx * min(1, dt * 4 * tune.chargeMul)
            if abs(dx) < 6 {
                boss.chargeActive = false
                boss.chargeTimer = ctx.enraged ? 4.0 : 6.0
            }
        } else {
            hover(boss, dt: dt, ctx: ctx)
            boss.chargeTimer -= dt
            if boss.chargeTimer <= 0 {
                boss.chargeActive = true
                boss.chargeToX = ctx.playerPos.x
                ctx.audio.play(.bossAlert)
            }
        }

        // Keep the pressure on with faster fan + summon.
        boss.fanTimer -= dt
        if boss.fanTimer <= 0 {
            boss.fanTimer = ctx.enraged ? 1.1 : 1.6
            fanBarrage(boss, ctx: ctx, count: (ctx.enraged ? 16 : 12) + tune.fanCountBias)
        }
        boss.summonTimer -= dt
        if boss.summonTimer <= 0 {
            boss.summonTimer = ctx.enraged ? 2.5 : 4.0
            ctx.summonMinion(CGPoint(x: boss.position.x, y: boss.position.y - 40))
        }
    }

    // MARK: Shared helpers
    private func hover(_ boss: Boss, dt: TimeInterval, ctx: BossContext) {
        boss.hoverT += dt
        let midX = ctx.scene.frame.midX
        let amp = ctx.scene.frame.width * 0.3
        boss.position.x = midX + sin(boss.hoverT * 1.2) * amp
        let targetY = ctx.scene.frame.maxY - 150
        boss.position.y += (targetY - boss.position.y) * min(1, dt * 2)
    }

    /// Fire `count` bullets in a downward fan around straight-down.
    private func fanBarrage(_ boss: Boss, ctx: BossContext, count: Int) {
        let spread = CGFloat.pi * 0.6
        let speed = boss.kind.tuning.fanSpeed
        let dmg = boss.kind.tuning.bulletDamage
        for i in 0..<count {
            let t = count == 1 ? 0.5 : CGFloat(i) / CGFloat(count - 1)
            let ang = -CGFloat.pi / 2 + (t - 0.5) * spread
            ctx.fireBullet(boss.position, ang, speed, dmg)
        }
        ctx.audio.play(.enemyFire)
    }
}
