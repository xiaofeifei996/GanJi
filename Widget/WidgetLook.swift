import SwiftUI

/// 票根对切风视觉层。
///
/// 版面语言来自一张真实票据：竖向打孔虚线把票面切成两半，
/// 左半是「日期存根」，右半是「圩名主票」。
/// 配色用暖米纸 + 一枚邮戳感的朱红圆，和前三版（纸墨历书 / 系统卡片 / 蓝色大票）都不同。
enum Ink {
    static let paper = Color(red: 0.97, green: 0.94, blue: 0.88)
    static let paperDeep = Color(red: 0.92, green: 0.88, blue: 0.79)
    static let stamp = Color(red: 0.78, green: 0.29, blue: 0.20)     // 邮戳朱红
    static let title = Color(red: 0.15, green: 0.13, blue: 0.11)
    static let secondary = Color(red: 0.45, green: 0.41, blue: 0.35)
    static let tertiary = Color(red: 0.62, green: 0.58, blue: 0.51)
    static let punch = Color(red: 0.93, green: 0.93, blue: 0.95)     // 打孔透出的底色
}

struct WidgetSurface: View {
    var body: some View {
        LinearGradient(
            colors: [Ink.paper, Ink.paperDeep],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
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

/// 竖向打孔线：一列小圆点，模拟票据撕裂孔。
struct PunchLine: View {
    var height: CGFloat = 44

    var body: some View {
        VStack(spacing: 4) {
            ForEach(0..<Int(height / 7), id: \.self) { _ in
                Circle()
                    .fill(Ink.punch)
                    .frame(width: 3.5, height: 3.5)
            }
        }
    }
}

/// 邮戳：双圈朱红圆 + 中间小字，盖在票面角落。
struct Postmark: View {
    let text: String
    var size: CGFloat = 30

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(Ink.stamp.opacity(0.85), lineWidth: 1.4)
            Circle()
                .strokeBorder(Ink.stamp.opacity(0.5), lineWidth: 0.8)
                .padding(2.5)
            Text(text)
                .font(.system(size: size * 0.3, weight: .black))
                .foregroundStyle(Ink.stamp)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .padding(4)
        }
        .frame(width: size, height: size)
        .rotationEffect(.degrees(-8))
    }
}

/// 撕票波浪边：底边一排半圆缺口。
struct TornEdge: View {
    var body: some View {
        HStack(spacing: 2.5) {
            ForEach(0..<24, id: \.self) { _ in
                Circle()
                    .fill(Ink.punch)
                    .frame(width: 3.5, height: 3.5)
                    .offset(y: 2)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct SectionLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 9, weight: .black))
            .tracking(1.4)
            .foregroundStyle(Ink.tertiary)
            .lineLimit(1)
    }
}

struct HairLine: View {
    var body: some View {
        Rectangle()
            .fill(Ink.tertiary.opacity(0.35))
            .frame(height: 0.7)
    }
}
