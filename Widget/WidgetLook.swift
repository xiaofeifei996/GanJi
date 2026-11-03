import SwiftUI

/// Apple 系统风配色，与 App 内 v119+ 的界面语言一致：
/// 分组背景、白色圆角卡片、系统蓝、SF 字体。
/// 旧纸墨配色已整体移除。
enum Ink {
    static let page = Color(uiColor: .systemGroupedBackground)
    static let card = Color(uiColor: .secondarySystemGroupedBackground)
    static let title = Color.primary
    static let secondary = Color.secondary
    static let tertiary = Color(uiColor: .tertiaryLabel)
    static let blue = Color(red: 0.16, green: 0.43, blue: 0.94)
    static let separator = Color(uiColor: .separator)
}

struct WidgetSurface: View {
    var body: some View {
        Ink.page
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

/// 白色圆角卡片，App 内列表卡的同款视觉。
struct Card: View {
    var corner: CGFloat = 14

    init(corner: CGFloat = 14) {
        self.corner = corner
    }

    var body: some View {
        RoundedRectangle(cornerRadius: corner, style: .continuous)
            .fill(Ink.card)
    }
}

/// 蓝色小圆点，用于「今天」的强调，对应 App 里选中态的蓝。
struct BlueDot: View {
    var body: some View {
        Circle().fill(Ink.blue)
    }
}

/// 栏目小字。
struct SectionLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Ink.secondary)
            .lineLimit(1)
    }
}

/// 细分隔线。
struct HairLine: View {
    var body: some View {
        Rectangle()
            .fill(Ink.separator)
            .frame(height: 0.5)
    }
}
