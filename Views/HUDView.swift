import SwiftUI

/// Heads-up display. Reads only from `GameSession` — it never mutates game
/// state. Top shows shield / timer / score / combo; the boss bar appears only
/// during the boss fight; the bottom shows the three weapon levels + laser
/// charge. The centre is intentionally left empty for bullet-dodging room.
struct HUDView: View {
    @ObservedObject var session: GameSession

    var body: some View {
        VStack(spacing: 0) {
            topBar
            if session.inBossFight { bossBar }
            Spacer()
            bottomBar
        }
        .padding(.top, 6)
        .padding(.bottom, 6)
        .safeAreaPadding(.top, 10)
        .safeAreaPadding(.bottom, 14)
        .allowsHitTesting(false)   // never steal drags from the gameplay layer
    }

    // MARK: Top
    private var topBar: some View {
        HStack(alignment: .top, spacing: 12) {
            ShieldPips(shield: session.shield, max: session.shieldMax)
            Spacer()
            if session.mode == .endless {
                LivesPips(lives: session.lives)
            } else {
                TimerLabel(time: max(0, GameConfig.totalDuration - session.elapsed),
                           enraged: session.bossEnraged && session.inBossFight)
            }
            Spacer()
            ScoreCombo(score: session.score, combo: session.combo, multiplier: session.multiplier)
        }
        .padding(.horizontal, 16)
    }

    // MARK: Boss bar
    private var bossBar: some View {
        HStack(spacing: 8) {
            Text(session.bossEnraged
                 ? "\(session.bossName)·狂暴"
                 : (session.bossName.isEmpty ? "BOSS" : session.bossName))
                .font(.caption.bold())
                .foregroundStyle(session.bossEnraged ? .red : .orange)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.15))
                    Capsule()
                        .fill(session.bossEnraged ? Color.red : Color.orange)
                        .frame(width: geo.size.width * CGFloat(session.bossHP))
                }
            }
            .frame(height: 12)
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
    }

    // MARK: Bottom
    private var bottomBar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                ForEach(WeaponType.allCases, id: \.self) { type in
                    WeaponChip(type: type, level: session.weaponLevels[type] ?? 1)
                }
            }
            LaserChargeBar(charge: session.laserCharge)
        }
        .padding(.horizontal, 16)
    }

    // MARK: Subviews
    private struct LivesPips: View {
        let lives: Int
        var body: some View {
            HStack(spacing: 4) {
                Text("♥")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.green)
                Text("\(lives)")
                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
            }
            .frame(minWidth: 70)
        }
    }

    private struct ShieldPips: View {
        let shield: Int
        let max: Int
        var body: some View {
            HStack(spacing: 5) {
                ForEach(0..<max, id: \.self) { i in
                    Circle()
                        .fill(i < shield ? Color.cyan : Color.white.opacity(0.2))
                        .frame(width: 14, height: 14)
                        .overlay(Circle().stroke(Color.white.opacity(0.6), lineWidth: 1))
                }
            }
        }
    }

    private struct TimerLabel: View {
        let time: TimeInterval
        let enraged: Bool
        var body: some View {
            Text(enraged ? "狂暴" : format(time))
                .font(.system(size: 22, weight: .bold, design: .monospaced))
                .foregroundStyle(enraged ? .red : .white)
                .frame(minWidth: 70)
        }
        private func format(_ t: TimeInterval) -> String {
            let s = Int(t)
            return String(format: "%d:%02d", s / 60, s % 60)
        }
    }

    private struct ScoreCombo: View {
        let score: Int
        let combo: Int
        let multiplier: Int
        var body: some View {
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(score)")
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                Text("x\(multiplier)  \(combo)连")
                    .font(.caption)
                    .foregroundStyle(.yellow)
            }
        }
    }

    private struct WeaponChip: View {
        let type: WeaponType
        let level: Int
        var body: some View {
            HStack(spacing: 4) {
                Circle().fill(Color(type.coreColor)).frame(width: 10, height: 10)
                Text(type.displayName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                HStack(spacing: 2) {
                    ForEach(1...GameConfig.maxWeaponLevel, id: \.self) { lvl in
                        Circle()
                            .fill(lvl <= level ? Color(type.coreColor) : Color.white.opacity(0.2))
                            .frame(width: 7, height: 7)
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Capsule().fill(Color.black.opacity(0.45)))
        }
    }

    private struct LaserChargeBar: View {
        let charge: CGFloat
        var body: some View {
            HStack(spacing: 6) {
                Text("激光")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.green)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.15))
                        Capsule()
                            .fill(charge >= 1 ? Color.green : Color.green.opacity(0.6))
                            .frame(width: geo.size.width * charge)
                    }
                }
                .frame(height: 8)
            }
            .padding(.horizontal, 4)
        }
    }
}
