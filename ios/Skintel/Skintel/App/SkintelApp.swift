import SwiftUI

@main
struct SkintelApp: App {
    @State private var environment: AppEnvironment?
    @State private var configError: Error?

    init() {
        do {
            let config = try AppConfiguration.load()
            _environment = State(initialValue: AppEnvironment(config: config))
        } catch {
            _configError = State(initialValue: error)
        }
    }

    var body: some Scene {
        WindowGroup {
            if let environment {
                RootView()
                    .environment(environment)
                    .tint(SKColor.primary)
                    .preferredColorScheme(.light)
            } else if let configError {
                ConfigErrorView(error: configError)
            }
        }
    }
}
