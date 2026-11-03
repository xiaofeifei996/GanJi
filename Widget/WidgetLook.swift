import SwiftUI

/// 纸张与墨色。整个小组件不依赖任何图片资源，只用渐变、色块和字形，
/// 这样在 iOS 26 的液态玻璃主屏上也不会因为背景图被系统裁掉而变空白。
enum Paper {
    static let cream = Color(red: 0.985, green: 0.965, blue: 0.925)
    static let sand = Color(red: 0.945, green: 0.905, blue: 0.825)
    static let ink = Color(red: 0.16, green: 0.155, blue: 0.14)
    static let inkSoft = Color(red: 0.44, green: 0.415, blue: 0.365)
    static let vermilion = Color(red: 0.76, green: 0.26, blue: 0.18)
    static let jade = Color(red: 0.22, green: 0.42, blue: 0.36)
    static let rule = Color(red: 0.60, green: 0.545, blue: 0.43)
}

/// 宣纸底：暖米色斜向渐变 + 右上角一圈极淡朱砂，模拟纸上的一点印色。
struct PaperSurface: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Paper.cream, Paper.sand],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            GeometryReader { proxy in
                Circle()
                    .fill(Paper.vermilion.opacity(0.055))
                    .frame(width: proxy.size.width * 0.95, height: proxy.size.width * 0.95)
                    .position(x: proxy.size.width * 0.94, y: proxy.size.height * 0.04)
            }
        }
    }
}

extension View {
    /// iOS 17 起用系统的容器背景，系统会把它当作小组件真正的背景来渲染，
    /// 不会像普通 View 那样被液态玻璃外观丢弃；更早的系统退回普通背景。
    @ViewBuilder
    func paperWidget() -> some View {
        if #available(iOS 17.0, *) {
            containerBackground(for: .widget) { PaperSurface() }
        } else {
            background(PaperSurface())
        }
    }
}

/// 细横线，用来分隔版块。
struct HairLine: View {
    var body: some View {
        Rectangle()
            .fill(Paper.rule.opacity(0.38))
            .frame(height: 1)
    }
}

/// 版块标题：小字、字距拉开，像纸上的栏目名。
struct SectionLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .heavy))
            .tracking(1.6)
            .foregroundStyle(Paper.inkSoft)
            .lineLimit(1)
    }
}
