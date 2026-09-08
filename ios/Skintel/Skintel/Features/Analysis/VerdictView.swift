import SwiftUI
import SkintelCore

/// Design §10. The score ring counts up, the card tints with the verdict, reasons are
/// plain sentences from the API, and saving is right there.
struct VerdictView: View {
    let scanID: String
    var fromScanner = false

    @Environment(AppEnvironment.self) private var env
    @State private var routineSlot: RoutineStore.Slot?
    @State private var addedToRoutine = false

    var body: some View {
        if let scan = env.scans.scans[scanID] {
            content(scan)
        } else {
            SKEmptyState(icon: "questionmark.circle", title: "Scan not found", message: "Scan the product again.")
                .skPageBackground()
        }
    }

    private func content(_ scan: ScanStore.StoredScan) -> some View {
        let parsed = INCI.parse(scan.inci)
        let buckets = IngredientKnowledge.categorize(parsed, culpritsByNormalized: env.products.culprits.byNormalized)
        return ScrollView {
            VStack(alignment: .leading, spacing: SKSpace.lg) {
                if let name = scan.productName ?? scan.brand {
                    HStack(spacing: SKSpace.md) {
                        SKProductMark(name: name, size: 40)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(name).font(SKFont.cardTitle).foregroundStyle(SKColor.ink).lineLimit(1)
                            Text("\(parsed.count) ingredients · \(scan.source)").font(SKFont.dataSmall).foregroundStyle(SKColor.muted)
                        }
                    }
                }

                VerdictCard(result: scan.result, goodCount: buckets.good.count)

                Text("Why this verdict").font(SKFont.section).foregroundStyle(SKColor.ink).padding(.top, SKSpace.sm)
                FlagList(result: scan.result, goodRows: Array(buckets.good.prefix(3)), culpritRows: buckets.watchOut)

                if let notes = scan.result.notes, !notes.isEmpty {
                    Text(notes).font(SKFont.secondary).foregroundStyle(SKColor.muted)
                }

                actions(scan)
                    .padding(.top, SKSpace.sm)
            }
            .skPagePadding()
            .padding(.vertical, SKSpace.md)
            .padding(.bottom, SKSpace.xxl)
        }
        .skPageBackground()
        .skNavigationTitle("Analysis")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: shareText(scan)) { Image(systemName: "square.and.arrow.up") }
                    .accessibilityLabel("Share")
            }
        }
        .onChange(of: routineSlot) { _, slot in
            guard let slot, let pid = scan.productID else { return }
            env.routine.add(pid, to: slot)
            addedToRoutine = true
            Haptics.success()
            routineSlot = nil
        }
    }

    @ViewBuilder
    private func actions(_ scan: ScanStore.StoredScan) -> some View {
        if let pid = scan.productID {
            HStack(spacing: SKSpace.md) {
                NavigationLink(value: AppDestination.productDetail(id: pid)) {
                    Text("View on shelf").font(SKFont.button).foregroundStyle(SKColor.cream)
                        .frame(maxWidth: .infinity).frame(height: 52)
                        .background(SKColor.primary, in: RoundedRectangle(cornerRadius: SKRadius.button, style: .continuous))
                }
                .buttonStyle(SKPressStyle())
                Menu {
                    Button("AM routine") { routineSlot = .am }
                    Button("PM routine") { routineSlot = .pm }
                } label: {
                    Text(addedToRoutine ? "Added ✓" : "+ Routine").font(SKFont.button).foregroundStyle(SKColor.ink)
                        .frame(maxWidth: .infinity).frame(height: 52)
                        .background(SKColor.cream, in: RoundedRectangle(cornerRadius: SKRadius.button, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: SKRadius.button, style: .continuous).stroke(SKColor.line))
                }
            }
        } else {
            VStack(spacing: SKSpace.sm) {
                NavigationLink(value: AppDestination.productForm(.add(prefill: ScanCandidate(
                    brand: scan.brand, productName: scan.productName, inci: scan.inci, upc: nil, source: scan.source)))) {
                    Text("Save to shelf").font(SKFont.button).foregroundStyle(SKColor.cream)
                        .frame(maxWidth: .infinity).frame(height: 52)
                        .background(SKColor.primary, in: RoundedRectangle(cornerRadius: SKRadius.button, style: .continuous))
                        .skPrimaryGlow()
                }
                .buttonStyle(SKPressStyle())
                Text("Tell Skintel how your skin reacts and this product joins your culprit analysis.")
                    .font(SKFont.caption).foregroundStyle(SKColor.muted).multilineTextAlignment(.center)
            }
        }
    }

    private func shareText(_ s: ScanStore.StoredScan) -> String {
        let name = s.productName ?? s.brand ?? "This product"
        return "\(name): \(s.result.score)/100 — \(s.result.verdict.label). \(s.result.summary) · Checked with Skintel (skinstel.com)"
    }
}

/// Tinted verdict card with ring + the three counts (design §10 top card).
struct VerdictCard: View {
    let result: ScanResult
    let goodCount: Int

    var body: some View {
        let tone = result.verdict.tone
        VStack(alignment: .leading, spacing: SKSpace.lg) {
            HStack {
                SKChip(result.verdict.label.uppercased(), tone: tone)
                Spacer()
                Text("\(result.flags.count) flag\(result.flags.count == 1 ? "" : "s")")
                    .font(SKFont.dataSmall).foregroundStyle(SKColor.muted)
            }
            HStack(alignment: .center, spacing: SKSpace.xl) {
                SKScoreRing(score: result.score, size: 118)
                VStack(spacing: 0) {
                    countRow("Good for you", goodCount, SKColor.goodFg)
                    countRow("Watch", result.mediumCount + result.lowCount, SKColor.cautionFg)
                    countRow("Red flags", result.highCount, result.highCount > 0 ? SKColor.badFg : SKColor.ink, last: true)
                }
            }
            if !result.summary.isEmpty {
                Text(result.summary).font(SKFont.sans(17, relativeTo: .body)).foregroundStyle(SKColor.ink).lineSpacing(3)
            }
        }
        .padding(SKSpace.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: [tone.bg, SKColor.cream], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: SKRadius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: SKRadius.card, style: .continuous).stroke(tone.fg.opacity(0.22)))
        .skCardShadow()
    }

    private func countRow(_ label: String, _ n: Int, _ color: Color, last: Bool = false) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(label).font(SKFont.secondary).foregroundStyle(SKColor.muted)
                Spacer()
                Text("\(n)").font(SKFont.sans(16, weight: .semibold)).foregroundStyle(color)
            }
            .padding(.vertical, 9)
            if !last { Rectangle().fill(SKColor.line).frame(height: 1) }
        }
        .accessibilityElement(children: .combine)
    }
}

/// "Why this verdict" rows: API flags (red/amber/neutral dots) then a few known-good
/// ingredients from the knowledge table, so a clean product still has reasons.
struct FlagList: View {
    let result: ScanResult
    var goodRows: [IngredientKnowledge.BucketRow] = []
    var culpritRows: [IngredientKnowledge.BucketRow] = []

    var body: some View {
        VStack(spacing: SKSpace.md) {
            ForEach(culpritRows) { r in
                row(tone: .bad, title: r.raw, text: "You've reacted to this before — it's in \(r.culprit?.badCount ?? 0) products that broke you out.")
            }
            ForEach(result.flags) { f in
                row(tone: f.level == .high ? .bad : f.level == .medium ? .caution : .neutral, title: f.ingredient, text: f.reason)
            }
            ForEach(goodRows) { r in
                row(tone: .good, title: r.raw, text: r.info?.benefit ?? "Known to help.")
            }
            if result.flags.isEmpty && goodRows.isEmpty && culpritRows.isEmpty {
                Text("Nothing stood out either way.").font(SKFont.secondary).foregroundStyle(SKColor.muted)
            }
        }
    }

    private func row(tone: SKTone, title: String, text: String) -> some View {
        SKCard(padding: SKSpace.lg) {
            HStack(alignment: .top, spacing: SKSpace.md) {
                SKDot(tone: tone).padding(.top, 7)
                (Text(title).font(SKFont.sans(16, weight: .semibold, relativeTo: .body)) + Text(" — \(text)").font(SKFont.body))
                    .foregroundStyle(SKColor.ink)
                    .lineSpacing(2)
            }
        }
    }
}
