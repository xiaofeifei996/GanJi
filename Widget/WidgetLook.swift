import SwiftUI
import WidgetKit

private struct AdaptiveWidgetKey: EnvironmentKey { static let defaultValue = false }
extension EnvironmentValues {
    var adaptiveWidget: Bool {
        get { self[AdaptiveWidgetKey.self] }
        set { self[AdaptiveWidgetKey.self] = newValue }
    }
}

struct WidgetSurface: View {
    @Environment(\.widgetFamily) private var family
    private var size: WidgetPhotoSize {
        family == .systemSmall ? .small : (family == .systemMedium ? .medium : .large)
    }
    var body: some View {
        let appearance = WidgetBackgroundStore.appearance(for: size)
        GeometryReader { geometry in
            ZStack {
                LinearGradient(colors: [Color(red: 0.16, green: 0.32, blue: 0.31),
                                        Color(red: 0.04, green: 0.12, blue: 0.16)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                if let image = appearance.image {
                    Image(uiImage: image).resizable().scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                    Color.black.opacity(appearance.darkness)
                }
                LinearGradient(colors: [.black.opacity(0.05), .black.opacity(0.48)],
                               startPoint: .top, endPoint: .bottom)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
        }
        .accessibilityHidden(true)
    }
}

@available(iOS 16.0, *)
private struct AdaptiveContent<Content: View>: View {
    @Environment(\.widgetRenderingMode) private var mode
    let content: Content
    var body: some View {
        content.environment(\.adaptiveWidget, mode != .fullColor)
            .foregroundStyle(mode == .fullColor ? Color.white : Color.primary)
    }
}
@available(iOS 17.0, *)
private struct ContainerContent<Content: View>: View {
    @Environment(\.widgetRenderingMode) private var mode
    @Environment(\.showsWidgetContainerBackground) private var showsBackground
    let content: Content
    var body: some View {
        content.environment(\.adaptiveWidget, mode != .fullColor || !showsBackground)
            .foregroundStyle(mode == .fullColor && showsBackground ? Color.white : Color.primary)
    }
}
extension View {
    @ViewBuilder func photoWidget() -> some View {
        if #available(iOS 17.0, *) {
            ContainerContent(content: self).containerBackground(for: .widget) { WidgetSurface() }
        } else if #available(iOS 16.0, *) {
            AdaptiveContent(content: self).background(WidgetSurface())
        } else { foregroundStyle(.white).background(WidgetSurface()) }
    }
}

struct PhotoPanel: View {
    @Environment(\.adaptiveWidget) private var adaptive
    var body: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(adaptive ? Color.primary.opacity(0.08) : Color.black.opacity(0.22))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.7))
    }
}

struct WidgetIdentity: View {
    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "sun.max.fill").font(.system(size: 10, weight: .semibold))
            Text("赶集日记").font(.system(size: 10, weight: .semibold)).tracking(1)
        }
        .opacity(0.8)
    }
}
