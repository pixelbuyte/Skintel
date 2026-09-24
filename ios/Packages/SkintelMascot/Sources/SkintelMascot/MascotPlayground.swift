import SwiftUI
import MascotRig

/// A small screen for trying the droplet: every action, the worried face, sizes, the still
/// (Reduce Motion) frame, and pull-to-refresh.
public struct MascotPlayground: View {
    @State private var action: MascotAction = .idle
    @State private var worried = false
    @State private var animated = true
    @State private var size: CGFloat = 180

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                SkintelMascot(action, mood: worried ? .worried : .happy, size: size, animated: animated)
                    .frame(height: 230)

                Picker("Action", selection: $action) {
                    ForEach(MascotAction.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)

                VStack(spacing: 12) {
                    Toggle("Worried face", isOn: $worried)
                    Toggle("Animate", isOn: $animated)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Size · \(Int(size)) pt").font(.subheadline)
                        Slider(value: $size, in: 60...220)
                    }
                }
                .padding(16)
                .background(.background.opacity(0.7), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                Text("Animate off shows the still frame Reduce Motion uses. Pull down to see the refresh walk.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 12)], spacing: 16) {
                    ForEach(MascotAction.allCases) { item in
                        VStack(spacing: 4) {
                            SkintelMascot(item, size: 96)
                            Text(item.title).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    VStack(spacing: 4) {
                        SkintelMascot(.idle, mood: .worried, size: 96)
                        Text("Worried").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .padding(20)
        }
        .mascotRefreshable {
            try? await Task.sleep(for: .seconds(2))
        }
        .background(Color(red: 244 / 255, green: 237 / 255, blue: 224 / 255).ignoresSafeArea())
        .navigationTitle("Mascot playground")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

#Preview {
    NavigationStack { MascotPlayground() }
}
