import SwiftUI

/// 江南水墨风视觉层。
///
/// 背景是真正的山水画图片（Widget/Assets.xcassets/InkSmall|Medium|Large），
/// 通过 containerBackground(for: .widget) 声明——这正是 iOS 26 上背景消失问题的
/// 正解：图片必须作为容器背景交给系统渲染，不能画在普通内容层里。
/// 半透明内容卡浮在画上，保证文字可读。
enum Ink {
    static let title = Color(red: 0.13, green: 0.15, blue: 0.14)
    static let secondary = Color(red: 0.32, green: 0.37, blue: 0.36)
    static let tertiary = Color(red: 0.48, green: 0.53, blue: 0.52)
    /// 墨绿：开圩的印章色，来自参考图的绿棚/绿签。
    static let green = Color(red: 0.26, green: 0.38, blue: 0.29)
    static let greenDeep = Color(red: 0.18, green: 0.29, blue: 0.22)
    /// 印章红：农历行的「农」字小方印。
    static let seal = Color(red: 0.70, green: 0.16, blue: 0.12)
    /// 磨砂白卡：浮在画上的内容底。
    static let glass = Color.white.opacity(0.72)
    static let glassStrong = Color.white.opacity(0.88)
}

struct WidgetSurface: View {
    @Environment(\.widgetFamily) private var family

    var body: some View {
        GeometryReader { proxy in
            let name = family == .systemSmall ? "InkSmall"
                : (family == .systemMedium ? "InkMedium" : "InkLarge")
            Image(name)
                .resizable()
                .scaledToFill()
                .frame(width: proxy.size.width, height: proxy.size.height)
                .clipped()
        }
    }
}

extension View {
    @ViewBuilder
    func paperWidget() -> some View {
        if #available(iOS 17.0, *) {
            containerBackground(for: .widget) { WidgetSurface() }
        } else {
            background(WidgetSurface())
        }
    }
}

/// 磨砂白圆角卡：所有文字都放在这样的卡上，压得住画面。
struct GlassCard: View {
    var strong = false
    var radius: CGFloat = 12

    var body: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(strong ? Ink.glassStrong : Ink.glass)
    }
}

/// 绿色圆角签：参考图里「开圩/不开圩」的小绿牌。
struct GreenBadge: View {
    let text: String
    let isOpen: Bool
    var size: CGFloat = 12

    var body: some View {
        Text(text)
            .font(.system(size: size, weight: .heavy))
            .foregroundStyle(.white)
            .padding(.horizontal, 9)
            .padding(.vertical, 3.5)
            .background(
                Capsule().fill(isOpen ? Ink.green : Color(red: 0.52, green: 0.55, blue: 0.53))
            )
    }
}

/// 墨绿摊棚小图标：参考图里的绿色摊位符号，用简单几何画。
struct StallIcon: View {
    var size: CGFloat = 20
    var open: Bool = true

    var body: some View {
        VStack(spacing: 1.5) {
            // 遮阳棚：三段条纹
            HStack(spacing: 0) {
                ForEach(0..<3, id: \.self) { i in
                    Rectangle()
                        .fill(i % 2 == 0 ? awning : awning.opacity(0.55))
                    Rectangle()
                        .fill(awning)
                        .frame(width: size * 0.06)
                }
            }
            .frame(width: size, height: size * 0.3)
            .clipShape(AwningShape())
            // 桌面
            RoundedRectangle(cornerRadius: 1.5)
                .fill(Ink.title.opacity(open ? 0.75 : 0.4))
                .frame(width: size * 0.86, height: size * 0.14)
            // 桌腿+货
            HStack(spacing: size * 0.1) {
                ForEach(0..<3, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Ink.title.opacity(open ? 0.5 : 0.28))
                        .frame(width: size * 0.16, height: size * 0.22)
                }
            }
        }
    }

    private var awning: Color {
        open ? Ink.green : Color(red: 0.55, green: 0.58, blue: 0.56)
    }
}

private struct AwningShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let scallop = rect.width / 4
        p.move(to: CGPoint(x: 0, y: 0))
        p.addLine(to: CGPoint(x: rect.width, y: 0))
        p.addLine(to: CGPoint(x: rect.width, y: rect.height * 0.55))
        for i in stride(from: 4, through: 1, by: -1) {
            let x1 = scallop * CGFloat(i - 1)
            let x2 = scallop * CGFloat(i)
            p.addQuadCurve(
                to: CGPoint(x: x1, y: rect.height * 0.55),
                control: CGPoint(x: (x1 + x2) / 2, y: rect.height * 1.05)
            )
        }
        p.closeSubpath()
        return p
    }
}

/// 「农」字小红印。
struct SealMark: View {
    var size: CGFloat = 13

    var body: some View {
        Text("农")
            .font(.system(size: size * 0.62, weight: .black))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(RoundedRectangle(cornerRadius: 3).fill(Ink.seal))
    }
}

struct SectionLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 9, weight: .black))
            .tracking(1.2)
            .foregroundStyle(Ink.secondary)
            .lineLimit(1)
    }
}
