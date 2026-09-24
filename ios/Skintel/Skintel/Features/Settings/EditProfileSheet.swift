import SwiftUI
import SkintelCore

/// Avatar look, name, skin profile and a note for Ask Skintel. Everything but the avatar is
/// written to auth user_metadata (the same store onboarding uses).
struct EditProfileSheet: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(SKAvatarLook.key) private var avatarLook = 0
    @State private var name = ""
    @State private var skinType: SkinType?
    @State private var concerns: Set<SkinConcern> = []
    @State private var about = ""
    @State private var saving = false
    @State private var error: String?

    private let columns = [GridItem(.flexible(), spacing: SKSpace.md), GridItem(.flexible(), spacing: SKSpace.md)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: SKSpace.xl) {
                    VStack(spacing: SKSpace.sm) {
                        Button(action: shuffleAvatar) { SKGeneratedAvatar(look: avatarLook, size: 104) }
                            .buttonStyle(SKPressStyle(scale: 0.94))
                            .accessibilityLabel("Shuffle your avatar")
                        Button(action: shuffleAvatar) {
                            Label("Shuffle look", systemImage: "shuffle")
                                .font(SKFont.sans(14, weight: .semibold, relativeTo: .subheadline))
                                .foregroundStyle(SKColor.primary)
                                .padding(.horizontal, 14)
                                .frame(height: 36)
                                .background(SKColor.cream, in: Capsule())
                                .overlay(Capsule().stroke(SKColor.line))
                        }
                        .buttonStyle(SKPressStyle())
                    }
                    .frame(maxWidth: .infinity)
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
                    VStack(alignment: .leading, spacing: SKSpace.sm) {
                        SKFieldLabel("Anything Ask Skintel should know")
                        SKTextEditor(placeholder: "Pregnant, so no retinoids. I prefer fragrance-free.", text: $about, minHeight: 96)
                        Text("Ask Skintel reads this before every answer.")
                            .font(SKFont.caption).foregroundStyle(SKColor.muted)
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
            about = u?.assistantAbout ?? ""
        }
    }

    private func shuffleAvatar() {
        Haptics.selection()
        withAnimation(reduceMotion ? nil : Animation.spring(duration: 0.35, bounce: 0.3)) {
            avatarLook = SKGeneratedAvatar.shuffled(from: avatarLook)
        }
    }

    private func save() async {
        saving = true; error = nil
        defer { saving = false }
        let profile = SkinProfile(skinType: skinType, concerns: SkinConcern.allCases.filter { concerns.contains($0) })
        var patch = AuthUser.metadataPatch(profile: profile, displayName: name.trimmingCharacters(in: .whitespaces),
                                           onboardingComplete: env.session.user?.onboardingComplete ?? true)
        let note = about.trimmingCharacters(in: .whitespacesAndNewlines)
        patch[AuthUser.assistantAboutKey] = .string(String(note.prefix(AuthUser.assistantAboutLimit)))
        do {
            try await env.session.updateMetadata(patch)
            Haptics.success()
            dismiss()
        } catch {
            self.error = (error as? APIError)?.userMessage ?? error.localizedDescription
        }
    }
}
