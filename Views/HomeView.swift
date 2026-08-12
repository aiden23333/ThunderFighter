import SwiftUI

/// Simple launch screen. Pick a mode, then start the match.
struct HomeView: View {
    @EnvironmentObject var router: AppRouter
    @State private var mode: GameMode = .level

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color.black, Color(red: 0.05, green: 0.05, blue: 0.15)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 26) {
                Spacer()

                Text("雷霆战机")
                    .font(.system(size: 46, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                Text("THUNDER FIGHTER")
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.cyan)
                    .tracking(4)

                // Mode selector
                HStack(spacing: 12) {
                    ModeCard(title: "3 分钟关卡",
                             subtitle: "固定流程 · 击败 Boss 通关",
                             selected: mode == .level) { mode = .level }
                    ModeCard(title: "无尽模式",
                             subtitle: "随机 Boss · 命用光结算",
                             selected: mode == .endless) { mode = .endless }
                }
                .padding(.horizontal, 24)

                Text(mode == .level
                      ? "拖动屏幕操控战机 · 拾取核心升级武器 · 击败 Boss 通关"
                      : "拖动操控战机 · 拾取护盾/命道具续命 · 击败随机 Boss 直到命用光")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                Spacer()

                Button {
                    router.startGame(mode)
                } label: {
                    Text("开始作战")
                        .font(.title3.bold())
                        .frame(width: 220, height: 56)
                        .background(Capsule().fill(Color.cyan))
                        .foregroundStyle(.black)
                }
                .padding(.bottom, 60)
            }
        }
    }

    private struct ModeCard: View {
        let title: String
        let subtitle: String
        let selected: Bool
        let onTap: () -> Void

        var body: some View {
            Button(action: onTap) {
                VStack(spacing: 6) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(selected ? .black : .white)
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(selected ? .black.opacity(0.7) : .white.opacity(0.6))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(RoundedRectangle(cornerRadius: 14)
                    .fill(selected ? Color.cyan : Color.white.opacity(0.08))
                    .overlay(RoundedRectangle(cornerRadius: 14)
                        .stroke(selected ? Color.cyan : Color.white.opacity(0.25), lineWidth: 1)))
            }
        }
    }
}
