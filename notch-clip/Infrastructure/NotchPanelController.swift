import AppKit
import SwiftUI

@MainActor
protocol PanelPresenter: AnyObject {
    func show(anchorScreen: NSScreen?)
    func hide(reason: PanelHideReason)
    func toggle()
}

private final class NotchPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor
final class NotchPanelController: NSObject, PanelPresenter {
    private let store: ClipboardStore
    private var panel: NSPanel?

    var panelFrame: NSRect? {
        panel?.frame
    }

    init(store: ClipboardStore) {
        self.store = store
    }

    func show(anchorScreen: NSScreen?) {
        let screen = anchorScreen ?? NSScreen.main ?? NSScreen.screens.first
        guard let screen else { return }

        let panel = panel ?? makePanel()
        self.panel = panel
        panel.setFrame(frame(for: screen), display: true, animate: true)
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()
    }

    func hide(reason: PanelHideReason) {
        panel?.orderOut(nil)
    }

    func toggle() {
        if panel?.isVisible == true {
            hide(reason: .userDismissed)
        } else {
            show(anchorScreen: NSScreen.main)
        }
    }

    private func makePanel() -> NSPanel {
        let panel = NotchPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .statusBar
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .transient]
        panel.contentView = NSHostingView(rootView: ClipboardPanelView(store: store))
        return panel
    }

    private func frame(for screen: NSScreen) -> NSRect {
        let width = min(max(screen.frame.width - 420, 860), 1280)
        let height: CGFloat = 330
        let x = screen.frame.midX - width / 2
        let y = screen.frame.maxY - height - 76
        return NSRect(x: x, y: y, width: width, height: height)
    }
}
