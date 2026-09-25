import SwiftUI

/// Every action with its controls, for an Xcode preview or a debug screen. No app, account
/// or network dependency.
public struct MascotPlayground: View {
    @State private var action: SkinstelMascotAction = .wave
    @State private var playing = true
    @State private var travels = false
    @State private var facingLeft = false
    @State private var replay = 0

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("A little care. A little company.")
                    .font(.title2.weight(.semibold))
                    .multilineTextAlignment(.center)
                SkinstelMascot(action: action, isPlaying: playing, travels: travels,
                               facingLeft: facingLeft, playbackID: replay)
                    .frame(height: 260)
                    .frame(maxWidth: .infinity)
                Text(action.label).font(.headline)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 10) {
                    ForEach(SkinstelMascotAction.allCases) { item in
                        Button(item.label) {
                            action = item
                            replay += 1
                        }
                        .buttonStyle(.bordered)
                        .accessibilityAddTraits(action == item ? [.isSelected] : [])
                    }
                }
                Toggle("Walk across the frame", isOn: $travels)
                Toggle("Face left", isOn: $facingLeft)
                Toggle("Playing", isOn: $playing)
            }
            .padding(24)
        }
        .tint(Color(.sRGB, red: 163 / 255, green: 88 / 255, blue: 72 / 255, opacity: 1))
        .background(Color(.sRGB, red: 244 / 255, green: 237 / 255, blue: 224 / 255, opacity: 1))
    }
}

#Preview { MascotPlayground() }
