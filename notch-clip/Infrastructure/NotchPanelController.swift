import AppKit
import QuartzCore
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
    private let transitionState = PanelTransitionState()
    private var panel: NSPanel?
    private var currentScreen: NSScreen?
    private var animationGeneration = 0

    var panelFrame: NSRect? {
        guard panel?.isVisible == true else { return nil }
        return panel?.frame
    }

    init(store: ClipboardStore) {
        self.store = store
    }

    func show(anchorScreen: NSScreen?) {
        let screen = anchorScreen ?? NSScreen.main ?? NSScreen.screens.first
        guard let screen else { return }

        let panel = panel ?? makePanel()
        self.panel = panel
        currentScreen = screen

        let targetFrame = frame(for: screen)
        let startFrame = collapsedFrame(for: screen, targetFrame: targetFrame)
        animationGeneration += 1

        if panel.isVisible == false {
            transitionState.progress = 0
            panel.alphaValue = 1
            panel.setFrame(startFrame, display: false)
            panel.makeKeyAndOrderFront(nil)
            panel.orderFrontRegardless()
        }

        withAnimation(.timingCurve(0.18, 0.9, 0.2, 1, duration: 0.36)) {
            transitionState.progress = 1
        }
        animate(panel, to: targetFrame, duration: 0.36, timingFunction: .notchPanelShow)
    }

    func hide(reason: PanelHideReason) {
        guard let panel, panel.isVisible else { return }

        let screen = currentScreen ?? screen(containing: panel.frame) ?? NSScreen.main ?? NSScreen.screens.first
        guard let screen else {
            panel.orderOut(nil)
            return
        }

        let targetFrame = collapsedFrame(for: screen, targetFrame: frame(for: screen))
        animationGeneration += 1
        let animationGeneration = animationGeneration

        withAnimation(.timingCurve(0.35, 0, 0.85, 0.2, duration: 0.24)) {
            transitionState.progress = 0
        }
        animate(panel, to: targetFrame, duration: 0.24, timingFunction: .notchPanelHide) { [weak self, weak panel] in
            guard let self, self.animationGeneration == animationGeneration else { return }
            panel?.orderOut(nil)
        }
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
        panel.animationBehavior = .none
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .transient]
        panel.contentView = NSHostingView(rootView: ClipboardPanelView(store: store, transition: transitionState))
        return panel
    }

    private func frame(for screen: NSScreen) -> NSRect {
        let width = min(max(screen.frame.width - 420, 860), 1080)
        let height: CGFloat = 330
        let x = screen.frame.midX - width / 2
        let y = screen.frame.maxY - height
        return NSRect(x: x, y: y, width: width, height: height)
    }

    private func collapsedFrame(for screen: NSScreen, targetFrame: NSRect) -> NSRect {
        let width: CGFloat = min(max(targetFrame.width * 0.18, 168), 220)
        let height: CGFloat = 14
        return NSRect(
            x: targetFrame.midX - width / 2,
            y: screen.frame.maxY - height,
            width: width,
            height: height
        )
    }

    private func screen(containing frame: NSRect) -> NSScreen? {
        NSScreen.screens.first { $0.frame.intersects(frame) }
    }

    private func animate(
        _ panel: NSPanel,
        to targetFrame: NSRect,
        duration: TimeInterval,
        timingFunction: CAMediaTimingFunction,
        completion: (() -> Void)? = nil
    ) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            context.timingFunction = timingFunction
            context.allowsImplicitAnimation = true
            panel.animator().setFrame(targetFrame, display: true)
        } completionHandler: {
            completion?()
        }
    }
}

private extension CAMediaTimingFunction {
    static let notchPanelShow = CAMediaTimingFunction(controlPoints: 0.18, 0.9, 0.2, 1)
    static let notchPanelHide = CAMediaTimingFunction(controlPoints: 0.35, 0, 0.85, 0.2)
}
