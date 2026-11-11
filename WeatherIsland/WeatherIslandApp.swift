import SwiftUI

@main
struct WeatherIslandApp: App {
    var body: some Scene {
        WindowGroup {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--settings-check") {
                WeatherTabsView()
            } else if ProcessInfo.processInfo.arguments.contains("--widget-gallery") {
                WeatherNavigationStack { WeatherWidgetGallery() }
            } else {
                WeatherRootView()
            }
            #else
            WeatherRootView()
            #endif
        }
    }
}

/// Keeps button-based navigation while disabling interactive back gestures in every stack.
struct WeatherNavigationStack<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        NavigationStack {
            content
                #if os(iOS)
                .background(WeatherBackGestureBlocker())
                #endif
        }
    }
}

#if os(iOS)
import UIKit

private struct WeatherBackGestureBlocker: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> Controller { Controller() }

    func updateUIViewController(_ controller: Controller, context: Context) {
        controller.disableBackGestures()
    }

    final class Controller: UIViewController, UIGestureRecognizerDelegate {
        override func didMove(toParent parent: UIViewController?) {
            super.didMove(toParent: parent)
            disableBackGestures()
        }

        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            disableBackGestures()
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            disableBackGestures()
        }

        func disableBackGestures() {
            guard let navigationController else { return }
            block(navigationController.interactivePopGestureRecognizer)
            if #available(iOS 26.0, *) {
                block(navigationController.interactiveContentPopGestureRecognizer)
            }
        }

        private func block(_ gesture: UIGestureRecognizer?) {
            gesture?.isEnabled = false
            // Navigation transitions may re-enable a recognizer; keep its begin check blocked.
            gesture?.delegate = self
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool { false }
    }
}
#endif
