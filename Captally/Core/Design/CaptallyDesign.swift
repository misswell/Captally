import SwiftUI

/// The single source of layout numbers for every screen.
///
/// Radii follow the concentric rule: a control inset by `s` inside a `cardRadius` surface reads
/// as continuous only if its own radius is smaller by that inset. Mixing unrelated numbers is
/// what made the previous layout look stacked rather than layered.
enum Metrics {
    static let cardRadius: CGFloat = 24
    static let controlRadius: CGFloat = 14

    static let xs: CGFloat = 6
    static let s: CGFloat = 10
    static let m: CGFloat = 16
    static let l: CGFloat = 24
    static let gutter: CGFloat = 20

    static let keyHeight: CGFloat = 48
    static let rowHeight: CGFloat = 44
    static let chipHeight: CGFloat = 32
}

extension View {
    /// Liquid Glass on iOS 26 and later, material everywhere else.
    ///
    /// `interactive` opts a surface into the glass spring response, so only surfaces the user can
    /// actually press should ask for it.
    @ViewBuilder
    func glassSurface(_ radius: CGFloat = Metrics.cardRadius, interactive: Bool = false, tint: Color? = nil) -> some View {
        if #available(iOS 26.0, *) {
            let base = Glass.regular.interactive(interactive)
            glassEffect(tint.map(base.tint) ?? base, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
        } else {
            background(.regularMaterial, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
        }
    }

    /// A pressable surface. iOS 26 gets tinted interactive glass; earlier systems get a flat
    /// fill, which is the nearest equivalent without inventing a second visual language.
    @ViewBuilder
    func glassKey(tint: Color? = nil, radius: CGFloat = Metrics.controlRadius) -> some View {
        if #available(iOS 26.0, *) {
            let base = Glass.regular.interactive(true)
            glassEffect(tint.map(base.tint) ?? base, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
        } else {
            background((tint ?? Color(.secondarySystemFill)).opacity(0.5),
                       in: RoundedRectangle(cornerRadius: radius, style: .continuous))
        }
    }

    @ViewBuilder
    func glassPill(tint: Color? = nil) -> some View {
        if #available(iOS 26.0, *) {
            let base = Glass.regular.interactive(true)
            glassEffect(tint.map(base.tint) ?? base, in: Capsule())
        } else {
            background((tint ?? Color(.secondarySystemFill)).opacity(0.5), in: Capsule())
        }
    }

    /// The one prominent action on a screen.
    @ViewBuilder
    func primaryAction(tint: Color) -> some View {
        if #available(iOS 26.0, *) {
            buttonStyle(.glassProminent).tint(tint)
        } else {
            buttonStyle(.borderedProminent).tint(tint)
        }
    }

    /// Frees vertical space while the user reads the list, which is what the entry screens
    /// needed most.
    @ViewBuilder
    func collapsingTopBarOnScroll() -> some View {
        if #available(iOS 27.0, *) {
            toolbarMinimizationBehavior(.onScrollDown, for: .navigationBar)
        } else {
            self
        }
    }

    @ViewBuilder
    func softTopScrollEdge() -> some View {
        if #available(iOS 26.0, *) {
            scrollEdgeEffectStyle(.soft, for: .top)
        } else {
            self
        }
    }
}

/// Groups pressable glass surfaces so they morph together instead of overlapping as separate
/// films. Falls through to a plain container below iOS 26, where there is no glass to coordinate.
struct GlassGroup<Content: View>: View {
    private let spacing: CGFloat
    private let content: Content

    init(spacing: CGFloat = Metrics.s, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    var body: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) { content }
        } else {
            content
        }
    }
}
