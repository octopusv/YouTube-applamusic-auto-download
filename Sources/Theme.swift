import SwiftUI

enum Theme {
    static let cardCorner: CGFloat = 12
    static let smallCorner: CGFloat = 6
    static let artworkCorner: CGFloat = 10
    static let cardPadding: CGFloat = 20
    static let sectionSpacing: CGFloat = 18

    static let primaryAnimation: Animation = .smooth(duration: 0.28)
    static let snappyAnimation: Animation = .snappy(duration: 0.22)
}

struct CardBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(Theme.cardPadding)
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: Theme.cardCorner, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cardCorner, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5)
            )
    }
}

extension View {
    func card() -> some View { modifier(CardBackground()) }
}

struct HoverHighlight: ViewModifier {
    @State private var hovering = false
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.primary.opacity(hovering ? 0.06 : 0))
            )
            .onHover { hovering = $0 }
            .animation(.easeOut(duration: 0.12), value: hovering)
    }
}

extension View {
    func hoverHighlight() -> some View { modifier(HoverHighlight()) }
}
