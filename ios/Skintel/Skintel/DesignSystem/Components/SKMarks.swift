import SwiftUI

/// Rounded-square initial tile behind product names (design §07/§09/§11).
struct SKProductMark: View {
    let name: String
    var size: CGFloat = 48
    /// The product's own photo, when one is genuinely known. Most products have none —
    /// nothing is stored server-side yet — so the lettered tile stays the normal case
    /// rather than a failure state. Never pass another product's image to fill the space.
    var imageURL: String? = nil

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: size * 0.25, style: .continuous)
    }

    var body: some View {
        Group {
            if let imageURL, let url = URL(string: imageURL) {
                AsyncImage(url: url, transaction: Transaction(animation: .easeOut(duration: 0.18))) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure:
                        letterTile
                    case .empty:
                        // Deliberately blank, not the initial: a letter that appears for a
                        // moment and is then replaced by the photo reads as a glitch.
                        SKColor.tileLoading
                    @unknown default:
                        letterTile
                    }
                }
            } else {
                letterTile
            }
        }
        .frame(width: size, height: size)
        .clipShape(shape)
        .overlay(shape.stroke(SKColor.line, lineWidth: imageURL == nil ? 0 : 1))
        .accessibilityHidden(true)
    }

    private var letterTile: some View {
        let t = SKColor.tile(for: name)
        return Text(String(name.trimmingCharacters(in: .whitespaces).prefix(1)).uppercased())
            .font(SKFont.sans(size * 0.42, weight: .semibold, relativeTo: .title2))
            .foregroundStyle(t.fg)
            .frame(width: size, height: size)
            .background(t.bg)
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

// MARK: - The mascot

/// The mascot's smile: a shallow curve bowing down across its frame, drawn so the
/// stroke width can scale with the character without distorting the arc.
private struct SKSmile: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY),
                       control: CGPoint(x: rect.midX, y: rect.maxY))
        return p
    }
}

/// Skintel's character, drawn entirely from shapes and existing palette tokens — no
/// asset, no SF Symbol. It speaks for *Skintel's own state* (offline, failed, looking);
/// SF symbols stay for facts about her skin.
///
/// Unnamed in copy for v1 and `.accessibilityHidden(true)` like every other `SK*` mark —
/// the surrounding text carries the meaning. The body gradient is the exact one
/// `SKAppMark` uses, so it reads as a sibling of the app icon.
struct SKMascot: View {
    enum Mood: Sendable, Hashable {
        /// Landed, done, all good.
        case happy
        /// Something failed. Deliberately still — an error state must not fidget.
        case worried
        /// Offline. Eyes closed, breathing.
        case sleeping
        /// Working on it. Eyes tracking, plus the scan line above 40pt.
        case searching
    }

    var mood: Mood = .happy
    var size: CGFloat = 64
    var animated: Bool = true

    @State private var pop: CGFloat = 1
    @State private var breathe = false
    @State private var sweep = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Below this the face is a blob, so the small form drops everything but the body
    /// and two round eyes. Decided here, never at the call site.
    private var isSmall: Bool { size < 28 }

    /// Gated exactly the way `ScannerIllustration` and `SKScoreRing` already gate.
    private var loops: Bool { animated && !reduceMotion && !isSmall }

    var body: some View {
        ZStack {
            if !isSmall {
                ear(-1)
                ear(1)
            }

            RoundedRectangle(cornerRadius: size * 0.34, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: 0xB2634F), SKColor.primary, SKColor.primaryPressed],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: size * 0.86, height: size * 0.78)

            if !isSmall {
                cheek(-1)
                cheek(1)
            }

            eye(-1)
            eye(1)

            if !isSmall {
                mouth
            }

            if mood == .searching && size >= 40 {
                Capsule()
                    .fill(SKColor.cream.opacity(0.55))
                    .frame(width: size * 0.72, height: max(1.5, size * 0.03))
                    .offset(y: loops ? (sweep ? size * 0.28 : -size * 0.28) : 0)
            }
        }
        .frame(width: size, height: size)
        // A held tilt, not a wobble: the worried pose reads as concern without fidgeting.
        .rotationEffect(.degrees(mood == .worried ? 6 : 0))
        .scaleEffect(pop)
        .scaleEffect(breathe ? 1.03 : 1.0)
        .accessibilityHidden(true)
        .task(id: mood) { await play() }
    }

    // MARK: Parts

    private func ear(_ side: CGFloat) -> some View {
        Capsule()
            .fill(SKColor.primaryPressed)
            .frame(width: size * 0.16, height: size * 0.26)
            .rotationEffect(.degrees(22 * Double(side)))
            .offset(x: size * 0.26 * side, y: -size * 0.36)
    }

    private func cheek(_ side: CGFloat) -> some View {
        Ellipse()
            .fill(SKColor.cream.opacity(0.22))
            .frame(width: size * 0.13, height: size * 0.08)
            .offset(x: size * 0.29 * side, y: size * 0.10)
    }

    @ViewBuilder
    private func eye(_ side: CGFloat) -> some View {
        let shift = (mood == .searching && loops) ? (sweep ? size * 0.035 : -size * 0.035) : 0
        if isSmall {
            if mood == .sleeping {
                Capsule()
                    .fill(SKColor.cream)
                    .frame(width: size * 0.11, height: 1)
                    .offset(x: size * 0.17 * side, y: -size * 0.02)
            } else {
                Circle()
                    .fill(SKColor.cream)
                    .frame(width: size * 0.11, height: size * 0.11)
                    .offset(x: size * 0.17 * side, y: -size * 0.02)
            }
        } else {
            Capsule()
                .fill(SKColor.cream)
                .frame(width: size * 0.09, height: eyeHeight)
                .offset(x: size * 0.17 * side + shift, y: -size * 0.02)
        }
    }

    private var eyeHeight: CGFloat {
        switch mood {
        case .sleeping: max(1, size * 0.022)
        case .worried: size * 0.15
        case .happy, .searching: size * 0.13
        }
    }

    @ViewBuilder
    private var mouth: some View {
        switch mood {
        case .happy:
            SKSmile()
                .stroke(SKColor.cream.opacity(0.9),
                        style: StrokeStyle(lineWidth: max(1.2, size * 0.035), lineCap: .round))
                .frame(width: size * 0.18, height: size * 0.07)
                .offset(y: size * 0.16)
        case .worried, .searching:
            Capsule()
                .fill(SKColor.cream.opacity(0.9))
                .frame(width: size * 0.16, height: max(1.2, size * 0.035))
                .offset(y: size * 0.17)
        case .sleeping:
            EmptyView()
        }
    }

    // MARK: Motion

    private func play() async {
        // Plain assignment (no `withAnimation`) cancels whatever loop the previous mood
        // left running.
        pop = 1
        breathe = false
        sweep = false

        guard loops else { return }

        switch mood {
        case .happy:
            // One shot on appear, then it stops. Never `repeatForever`.
            pop = 0.82
            withAnimation(SKAnimation.ios(0.28)) { pop = 1.06 }
            try? await Task.sleep(for: .milliseconds(280))
            if Task.isCancelled { pop = 1; return }
            withAnimation(SKAnimation.emil(0.34)) { pop = 1.0 }
        case .sleeping:
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) { breathe = true }
        case .searching:
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) { sweep = true }
        case .worried:
            break
        }
    }
}
