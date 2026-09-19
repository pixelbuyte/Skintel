import SwiftUI
import SkintelCore
import UIKit

/// A real catalogue or user photo, with an honest neutral fallback when unavailable.
struct SKProductMark: View {
    let name: String
    var imageURL: URL? = nil
    var photoData: Data? = nil
    var size: CGFloat = 48
    @State private var localImage: UIImage?

    var body: some View {
        Group {
            if let localImage {
                Image(uiImage: localImage).resizable().scaledToFit().padding(size * 0.05)
            } else if let remote = ProductImageURL.remote(imageURL?.absoluteString) {
                AsyncImage(url: remote) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFit().padding(size * 0.05)
                    } else { placeholder }
                }
            } else { placeholder }
        }
            .frame(width: size, height: size)
            .background(SKColor.cream)
            .compositingGroup()
            .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous).stroke(SKColor.line.opacity(0.6)))
            .accessibilityHidden(true)
            .task(id: imageURL) { await loadLocalImage() }
            .onChange(of: photoData) { _, data in localImage = data.flatMap(UIImage.init(data:)) }
    }

    private var placeholder: some View {
        Image(systemName: "photo")
            .font(.system(size: size * 0.3, weight: .light))
            .foregroundStyle(SKColor.muted.opacity(0.65))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func loadLocalImage() async {
        localImage = photoData.flatMap(UIImage.init(data:))
        guard photoData == nil, let imageURL, imageURL.isFileURL else { return }
        let data = await Task.detached(priority: .utility) { try? Data(contentsOf: imageURL) }.value
        guard !Task.isCancelled else { return }
        localImage = data.flatMap(UIImage.init(data:))
    }
}

/// Circular avatar with initial (home greeting, settings).
struct SKAvatar: View {
    let name: String?
    var size: CGFloat = 44

    var body: some View {
        Text(String((name ?? "S").trimmingCharacters(in: .whitespaces).prefix(1)).uppercased())
            .font(SKFont.sans(size * 0.4, weight: .semibold, relativeTo: .title3))
            .foregroundStyle(SKColor.cream)
            .frame(width: size, height: size)
            .background(SKColor.primary, in: Circle())
            .accessibilityHidden(true)
    }
}

/// The app mark used on splash and sign-in: terracotta squircle with a serif S and the
/// hairline "shelf" across it (matches designs/app-icon.svg).
struct SKAppMark: View {
    var size: CGFloat = 64

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: 0xB2634F), SKColor.primary, SKColor.primaryPressed],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
            Rectangle()
                .fill(SKColor.cream.opacity(0.45))
                .frame(height: max(1, size * 0.02))
            Text("S")
                .font(SKFont.serif(size * 0.62, relativeTo: .largeTitle))
                .foregroundStyle(SKColor.cream)
                .offset(y: -size * 0.02)
        }
        .frame(width: size, height: size)
        .skPrimaryGlow(strength: 0.3)
        .accessibilityLabel("Skintel")
    }
}

/// Coloured status dot used in INCI rows and the journal week strip.
struct SKDot: View {
    let tone: SKTone
    var size: CGFloat = 8
    var body: some View {
        Circle().fill(tone == .neutral ? SKColor.line : tone.fg).frame(width: size, height: size)
    }
}
