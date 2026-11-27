import SwiftUI
import UIKit

extension View {
    /// Keeps the edge swipe back working in a stack whose pages hide the navigation bar for a
    /// serif title: hiding the bar (`.toolbar(.hidden, for: .navigationBar)`) also switches off
    /// UIKit's pop gesture. Put it on the stack's root or on a pushed page; once the page is on
    /// screen, every page in that stack swipes back.
    func skSwipeBack() -> some View {
        background {
            SwipeBackInstaller()
                .frame(width: 0, height: 0)
                .accessibilityHidden(true)
        }
    }
}

/// An empty controller that finds the navigation controller it sits in once it is on screen.
private struct SwipeBackInstaller: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> InstallerController { InstallerController() }
    func updateUIViewController(_ controller: InstallerController, context: Context) {}

    final class InstallerController: UIViewController {
        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            install()
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            install()
        }

        private func install() {
            if let navigation = navigationController ?? Self.enclosingNavigation(of: view) {
                SwipeBackDelegate.install(on: navigation)
            }
        }

        /// The responder chain from the view up, for when the parent chain doesn't reach it.
        private static func enclosingNavigation(of view: UIView?) -> UINavigationController? {
            var responder: UIResponder? = view
            while let current = responder {
                if let navigation = current as? UINavigationController { return navigation }
                responder = current.next
            }
            return nil
        }
    }
}

/// The pop gesture's delegate: swipe back whenever there is a page to go back to and no push or
/// pop is already running (a swipe on the root page would leave the stack stuck).
@MainActor
final class SwipeBackDelegate: NSObject, @preconcurrency UIGestureRecognizerDelegate {
    /// A gesture recognizer holds its delegate weakly, so the delegates live here.
    private static var installed: [SwipeBackDelegate] = []
    private weak var navigation: UINavigationController?

    private init(navigation: UINavigationController) {
        self.navigation = navigation
        super.init()
    }

    static func install(on navigation: UINavigationController) {
        guard let pop = navigation.interactivePopGestureRecognizer, !(pop.delegate is SwipeBackDelegate) else { return }
        installed.removeAll { $0.navigation == nil }
        let delegate = SwipeBackDelegate(navigation: navigation)
        installed.append(delegate)
        pop.delegate = delegate
        pop.isEnabled = true
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let navigation else { return false }
        return navigation.viewControllers.count > 1 && navigation.transitionCoordinator == nil
    }
}
