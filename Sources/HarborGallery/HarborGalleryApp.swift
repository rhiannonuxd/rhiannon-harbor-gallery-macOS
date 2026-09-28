import AppKit
import SwiftUI

@main
struct HarborGalleryApp: App {
    @StateObject private var store = GalleryStore()

    var body: some Scene {
        WindowGroup("Harbor Gallery") {
            ContentView()
                .environmentObject(store)
                .frame(minWidth: 640, minHeight: 420)
                .background(
                    InitialWindowSizer(contentSize: CGSize(width: 996, height: 860))
                )
        }
        .defaultSize(width: 996, height: 860)
        .windowResizability(.contentMinSize)

        Settings {
            ConnectionSettingsView()
                .environmentObject(store)
                .frame(width: 470)
                .padding(GallerySpacing.space24)
        }
    }
}

private struct InitialWindowSizer: NSViewRepresentable {
    let contentSize: CGSize

    final class Coordinator {
        var hasSizedWindow = false
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        scheduleResize(for: view, coordinator: context.coordinator)
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        scheduleResize(for: view, coordinator: context.coordinator)
    }

    private func scheduleResize(for view: NSView, coordinator: Coordinator) {
        DispatchQueue.main.async {
            guard !coordinator.hasSizedWindow, let window = view.window else { return }
            coordinator.hasSizedWindow = true

            let desiredContentRect = NSRect(origin: .zero, size: contentSize)
            var targetFrame = window.frameRect(forContentRect: desiredContentRect)

            if let visibleFrame = window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame {
                targetFrame.size.width = min(targetFrame.width, visibleFrame.width)
                targetFrame.size.height = min(targetFrame.height, visibleFrame.height)
                targetFrame.origin.x = visibleFrame.midX - targetFrame.width / 2
                targetFrame.origin.y = visibleFrame.midY - targetFrame.height / 2
            }

            window.setFrame(targetFrame, display: true)
        }
    }
}
