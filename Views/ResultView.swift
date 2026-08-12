import SwiftUI

/// End-of-match screen. Reports score, kills, max combo and whether the boss
/// was defeated, then offers restart or return home.
struct ResultView: View {
    @EnvironmentObject var router: AppRouter
    let result: GameResult

    private var session: GameSession? { router.coordinator?.session }

    private var isEndless: Bool { session?.mode == .endless }

    private var titleText: String {
        if isEndless { return "游戏结束" }
        return result == .victory ? "通关胜利" : "作战失败"
    }

    private var titleColor: Color {
        if isEndless { return .orange }
        return result == .victory ? .green : .red
    }

    private var backColor: Color {
        if isEndless { return Color(red: 0.18, green: 0.10, blue: 0) }
        return result == .victory ? Color(red: 0, green: 0.15, blue: 0.08)
                                   : Color(red: 0.15, green: 0, blue: 0)
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color.black, backColor],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 26) {
                Text(titleText)
                    .font(.system(size: 40, weight: .heavy, design: .rounded))
                    .foregroundStyle(titleColor)

                VStack(spacing: 12) {
                    StatRow(label: "得分", value: "\(session?.score ?? 0)")
                    StatRow(label: "击毁数", value: "\(session?.kills ?? 0)")
                    StatRow(label: "最高连击", value: "\(session?.maxCombo ?? 0)")
                    if isEndless {
                        StatRow(label: "击败 Boss", value: "\(session?.bossesDefeated ?? 0)")
                    } else {
                        StatRow(label: "击败 Boss", value: (session?.bossDefeated ?? false) ? "是" : "否")
                    }
                }
                .padding(20)
                .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.06)))

                HStack(spacing: 16) {
                    Button { router.restart() } label: { PrimaryButton(title: "重新开始") }
                    Button { router.backToHome() } label: { SecondaryButton(title: "返回首页") }
                }
            }
            .padding(.horizontal, 32)
        }
    }

    private struct StatRow: View {
        let label: String
        let value: String
        var body: some View {
            HStack {
                Text(label).foregroundStyle(.white.opacity(0.7))
                Spacer()
                Text(value).font(.headline).foregroundStyle(.white)
            }
        }
    }

    private struct PrimaryButton: View {
        let title: String
        var body: some View {
            Text(title).font(.title3.bold())
                .frame(width: 140, height: 52)
                .background(Capsule().fill(Color.cyan))
                .foregroundStyle(.black)
        }
    }

    private struct SecondaryButton: View {
        let title: String
        var body: some View {
            Text(title).font(.title3.bold())
                .frame(width: 140, height: 52)
                .background(Capsule().stroke(Color.white.opacity(0.6), lineWidth: 1.5))
                .foregroundStyle(.white)
        }
    }
}
