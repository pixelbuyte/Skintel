import SwiftUI
import SkintelCore

/// Name + skin profile, written to auth user_metadata (the same store onboarding uses).
struct EditProfileSheet: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var skinType: SkinType?
    @State private var concerns: Set<SkinConcern> = []
    @State private var saving = false
    @State private var error: String?

    private let columns = [GridItem(.flexible(), spacing: SKSpace.md), GridItem(.flexible(), spacing: SKSpace.md)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: SKSpace.xl) {
                    VStack(alignment: .leading, spacing: SKSpace.sm) {
                        SKFieldLabel("Name")
                        SKTextField(placeholder: "How should Skintel greet you?", text: $name, contentType: .givenName, autocapitalization: .words)
                    }
                    VStack(alignment: .leading, spacing: SKSpace.md) {
                        SKFieldLabel("Skin type")
                        FlowLayout(spacing: SKSpace.sm) {
                            ForEach(SkinType.allCases) { t in
                                SKSelectChip(title: t.label, selected: skinType == t) { skinType = t; Haptics.selection() }
                            }
                        }
                    }
                    VStack(alignment: .leading, spacing: SKSpace.md) {
                        SKFieldLabel("Concerns · pick any")
                        LazyVGrid(columns: columns, spacing: SKSpace.md) {
                            ForEach(SkinConcern.allCases) { c in
                                SKSelectCard(title: c.label, selected: concerns.contains(c)) {
                                    if concerns.contains(c) { concerns.remove(c) } else { concerns.insert(c) }
                                    Haptics.selection()
                                }
                            }
                        }
                    }
                    if let error { SKInlineError(message: error) }
                    SKButton(title: "Save", isLoading: saving) { Task { await save() } }
                }
                .skPagePadding().padding(.vertical, SKSpace.lg)
            }
            .scrollDismissesKeyboard(.interactively)
            .skPageBackground()
            .skNavigationTitle("Your profile")
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() }.font(SKFont.bodyMedium) } }
        }
        .tint(SKColor.primary)
        .onAppear {
            let u = env.session.user
            name = u?.displayName ?? ""
            skinType = u?.skinProfile.skinType
            concerns = Set(u?.skinProfile.concerns ?? [])
        }
    }

    private func save() async {
        saving = true; error = nil
        defer { saving = false }
        let profile = SkinProfile(skinType: skinType, concerns: SkinConcern.allCases.filter { concerns.contains($0) })
        do {
            try await env.session.updateMetadata(AuthUser.metadataPatch(profile: profile, displayName: name.trimmingCharacters(in: .whitespaces),
                                                                        onboardingComplete: env.session.user?.onboardingComplete ?? true))
            Haptics.success()
            dismiss()
        } catch {
            self.error = (error as? APIError)?.userMessage ?? error.localizedDescription
        }
    }
}
