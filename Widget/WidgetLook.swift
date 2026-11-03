import SwiftUI

/// 纸与墨。
///
/// 之前用的淡朱砂大圆在真机上像一块污渍，纸色也偏灰，整体发闷。
/// 这次只保留「上暖下沉的纸」+ 一点点右上角柔光，视觉重点交给字号与朱砂竖标。
enum Paper {
    static let cream = Color(red: 0.988, green: 0.980, blue: 0.957)
    static let sand = Color(red: 0.949, green: 0.914, blue: 0.847)
    static let ink = Color(red: 0.118, green: 0.102, blue: 0.082)
    static let inkSoft = Color(red: 0.404, green: 0.365, blue: 0.310)
    static let vermilion = Color(red: 0.745, green: 0.227, blue: 0.149)
    static let jade = Color(red: 0.176, green: 0.353, blue: 0.302)
    static let rule = Color(red: 0.843, green: 0.800, blue: 0.714)
}

struct PaperSurface: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Paper.cream, Paper.sand],
                startPoint: .top,
                endPoint: .bottom
            )
            // 极淡的暖光，柔和的径向渐变而不是硬边圆形。
            GeometryReader { proxy in
                RadialGradient(
                    colors: [Paper.vermilion.opacity(0.06), Paper.vermilion.opacity(0)],
                    center: UnitPoint(x: 0.92, y: 0.0),
                    startRadius: 0,
                    endRadius: proxy.size.width * 0.85
                )
            }
        }
    }
}

extension View {
    /// iOS 17 起用系统容器背景，系统会把它当成小组件真正的背景来渲染；
    /// 更早的系统退回普通背景。
    @ViewBuilder
    func paperWidget() -> some View {
        if #available(iOS 17.0, *) {
            containerBackground(for: .widget) { PaperSurface() }
        } else {
            background(PaperSurface())
        }
    }
}

/// 朱砂竖标：所有版面的视觉锚点。
struct VermilionTick: View {
    var height: CGFloat = 10

    var body: some View {
        Capsule()
            .fill(Paper.vermilion)
            .frame(width: 3, height: height)
    }
}

/// 栏目小字：字距拉开，像纸上的栏名。
struct SectionLabel: View {
    let text: String
    var size: CGFloat = 10

    var body: some View {
        Text(text)
            .font(.system(size: size, weight: .heavy))
            .tracking(1.5)
            .foregroundStyle(Paper.inkSoft)
            .lineLimit(1)
    }
}

/// 细分隔线。
struct HairLine: View {
    var body: some View {
        Rectangle()
            .fill(Paper.rule)
            .frame(height: 1)
    }
}
