import SwiftUI
import SkintelCore

/// "Face scan is here": a short demo shown once per phone, the first time the app opens, before
/// sign-in or onboarding. The 3D face turns while its zones light up one by one in step with
/// the three steps. "Got it" closes it and onboarding carries on. The map is sample data.
struct FeatureIntroView: View {
    static let seenKey = "intro.faceScan.seen"

    let onDone: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// How many demo zones are lit (0...demo.count).
    @State private var lit = 0

    private struct DemoZone {
        let zone: FaceZone
        let level: Int
        let label: FaceMeshLabel
    }

    private static let demo: [DemoZone] = [
        DemoZone(zone: .nose, level: 1,
                 label: FaceMeshLabel(zone: .nose, title: "NOSE & T-ZONE", value: "SHINE · SOME", side: .trailing, y: 0.34, hot: false)),
        DemoZone(zone: .rightCheek, level: 1,
                 label: FaceMeshLabel(zone: .rightCheek, title: "RIGHT CHEEK", value: "REDNESS · SOME", side: .trailing, y: 0.62, hot: false)),
        DemoZone(zone: .chin, level: 2,
                 label: FaceMeshLabel(zone: .chin, title: "CHIN", value: "BLEMISHES · NOTICEABLE", side: .leading, y: 0.84, hot: true)),
        DemoZone(zone: .forehead, level: 0,
                 label: FaceMeshLabel(zone: .forehead, title: "FOREHEAD", value: "CLEAR", side: .leading, y: 0.16, hot: false)),
    ]

    private static let steps: [(icon: String, title: String, detail: String)] = [
        ("faceid", "Turn your head", "Three angles, about 15 seconds."),
        ("list.bullet", "Answer a few questions", "What you want to improve. Skip any you like."),
        ("sparkles", "See your map, zone by zone", "In plain words, then follow it for 7 days."),
    ]

    private var levels: FaceZoneLevels {
        var out: [FaceZone: Int] = [:]
        for item in Self.demo.prefix(lit) { out[item.zone] = item.level }
        return FaceZoneLevels(levels: out)
    }

    private var labels: [FaceMeshLabel] { Self.demo.prefix(lit).map(\.label) }

    /// The step the demo is on: 0 while nothing is lit, 2 once the map is filling in.
    private var activeStep: Int { lit == 0 ? 0 : lit == 1 ? 1 : 2 }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: SKSpace.lg) {
                    HStack(spacing: SKSpace.sm) {
                        Text("NEW IN SKINSTEL 2.0").font(SKFont.label).tracking(1.6).foregroundStyle(SKColor.primary)
                        SKNewBadge()
                    }
                    Text("Face scan is here").font(SKFont.serif(38, relativeTo: .largeTitle)).foregroundStyle(SKColor.ink)
                        .accessibilityAddTraits(.isHeader)
                    Text("See your skin zone by zone, then follow it for a week.")
                        .font(SKFont.sans(16, relativeTo: .body)).foregroundStyle(SKColor.muted)
                        .fixedSize(horizontal: false, vertical: true)

                    ZStack(alignment: .topTrailing) {
                        FaceMeshView(mode: .result, levels: levels, labels: labels, zoom: 0.3)
                            .frame(height: 300)
                            .frame(maxWidth: .infinity)
                            .allowsHitTesting(false)
                        Text("Sample").font(SKFont.label).foregroundStyle(SKColor.muted)
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(SKColor.cream, in: Capsule())
                            .overlay(Capsule().stroke(SKColor.line))
                            .padding(SKSpace.md)
                    }
                    .background(SKColor.cream, in: RoundedRectangle(cornerRadius: SKRadius.card, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: SKRadius.card, style: .continuous).stroke(SKColor.line))
                    .accessibilityElement()
                    .accessibilityLabel("A sample face map with each zone described in words")

                    VStack(spacing: SKSpace.sm) {
                        ForEach(Array(Self.steps.enumerated()), id: \.offset) { i, step in
                            stepRow(i, step.icon, step.title, step.detail)
                        }
                    }
                }
                .skPagePadding()
                .padding(.top, SKSpace.xl)
                .padding(.bottom, SKSpace.lg)
            }
            VStack(spacing: SKSpace.sm) {
                SKButton(title: "Got it", action: onDone)
                Text("A cosmetic read of your photos, not a diagnosis.")
                    .font(SKFont.caption).foregroundStyle(SKColor.muted).multilineTextAlignment(.center)
            }
            .skPagePadding()
            .padding(.bottom, SKSpace.lg)
        }
        .skPageBackground()
        .task { await play() }
    }

    private func stepRow(_ i: Int, _ icon: String, _ title: String, _ detail: String) -> some View {
        let on = i == activeStep
        return HStack(alignment: .top, spacing: SKSpace.md) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(on ? SKColor.cream : SKColor.primary)
                .frame(width: 36, height: 36)
                .background(on ? SKColor.primary : SKColor.blush, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(SKFont.sans(16, weight: .semibold, relativeTo: .body)).foregroundStyle(SKColor.ink)
                Text(detail).font(SKFont.sans(14, relativeTo: .subheadline)).foregroundStyle(SKColor.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(SKSpace.md)
        .background(on ? SKColor.cream : Color.clear, in: RoundedRectangle(cornerRadius: SKRadius.tile, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: SKRadius.tile, style: .continuous).stroke(on ? SKColor.line : Color.clear))
        .accessibilityElement(children: .combine)
    }

    /// Lights one zone at a time, holds the full map, then starts over. Reduce Motion shows it filled.
    private func play() async {
        guard !reduceMotion else { lit = Self.demo.count; return }
        while !Task.isCancelled {
            for n in 0...Self.demo.count {
                withAnimation(SKAnimation.ios(0.35)) { lit = n }
                try? await Task.sleep(for: .milliseconds(n == Self.demo.count ? 2200 : 1000))
                if Task.isCancelled { return }
            }
        }
    }
}

/// Onboarding step: how the parts of Skinstel fit together, before the camera step.
struct HowItWorksStepView: View {
    let back: () -> Void
    let next: () -> Void

    private static let rows: [(icon: String, title: String, detail: String, isNew: Bool)] = [
        ("barcode.viewfinder", "Scan your products", "Every ingredient checked against your skin.", false),
        ("face.smiling", "Check in your skin", "One tap a day. Patterns show up over time.", false),
        ("faceid", "Scan your face", "A zone-by-zone map, then a 7-day check.", true),
        ("sparkles", "Ask Skinstel", "Questions about your skin, your shelf or your scan.", false),
    ]

    var body: some View {
        VStack(spacing: 0) {
            StepHeader(step: 4, back: back).skPagePadding().padding(.top, SKSpace.sm)
            ScrollView {
                VStack(alignment: .leading, spacing: SKSpace.xl) {
                    Text("How Skinstel works.").font(SKFont.hero).foregroundStyle(SKColor.ink).padding(.top, SKSpace.xl)
                        .accessibilityAddTraits(.isHeader)
                    VStack(spacing: SKSpace.md) {
                        ForEach(Array(Self.rows.enumerated()), id: \.offset) { i, row in
                            HStack(alignment: .top, spacing: SKSpace.lg) {
                                Text("\(i + 1)")
                                    .font(SKFont.mono(12, relativeTo: .caption))
                                    .foregroundStyle(SKColor.primary)
                                    .frame(width: 28, height: 28)
                                    .background(SKColor.blush, in: Circle())
                                VStack(alignment: .leading, spacing: 3) {
                                    HStack(spacing: SKSpace.sm) {
                                        Image(systemName: row.icon).foregroundStyle(SKColor.primary)
                                        Text(row.title).font(SKFont.sans(17, weight: .semibold, relativeTo: .body)).foregroundStyle(SKColor.ink)
                                        if row.isNew { SKNewBadge() }
                                    }
                                    Text(row.detail).font(SKFont.sans(15, relativeTo: .subheadline)).foregroundStyle(SKColor.muted)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(SKSpace.lg)
                            .background(SKColor.cream, in: RoundedRectangle(cornerRadius: SKRadius.card, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: SKRadius.card, style: .continuous).stroke(SKColor.line))
                            .accessibilityElement(children: .combine)
                        }
                    }
                }
                .skPagePadding()
                .padding(.bottom, SKSpace.xxl)
            }
            SKButton(title: "Continue", action: next)
                .skPagePadding()
                .padding(.bottom, SKSpace.lg)
        }
    }
}
