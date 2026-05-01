import SwiftUI

struct ArtworkView: View {
    let path: String?
    var size: CGFloat = 160
    var corner: CGFloat = Theme.artworkCorner

    var body: some View {
        Group {
            if let path, let img = NSImage(contentsOfFile: path) {
                Image(nsImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
    }

    private var placeholder: some View {
        ZStack {
            LinearGradient(
                colors: [.accentColor.opacity(0.55), .accentColor.opacity(0.25)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "music.note")
                .font(.system(size: size * 0.36, weight: .medium))
                .foregroundStyle(.white.opacity(0.85))
        }
    }
}
