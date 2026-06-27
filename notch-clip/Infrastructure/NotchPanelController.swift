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
    private var isHiding = false

    var panelFrame: NSRect? {
        guard panel?.isVisible == true, !isHiding else { return nil }
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
        animationGeneration += 1
        isHiding = false
        panel.ignoresMouseEvents = false

        if panel.isVisible == false {
            transitionState.progress = 0
            panel.alphaValue = 1
            panel.setFrame(targetFrame, display: false)
            setRevealMask(on: panel, progress: 0)
            panel.makeKeyAndOrderFront(nil)
            panel.orderFrontRegardless()
        } else if panel.frame != targetFrame {
            panel.setFrame(targetFrame, display: false)
            setRevealMask(on: panel, progress: transitionState.progress)
        }

        withAnimation(.timingCurve(0.18, 0.9, 0.2, 1, duration: 0.36)) {
            transitionState.progress = 1
        }
        animateRevealMask(on: panel, to: 1, duration: 0.36, timingFunction: .notchPanelShow)
    }

    func hide(reason: PanelHideReason) {
        guard let panel, panel.isVisible else {
            isHiding = false
            return
        }
        guard !isHiding else { return }

        let screen = currentScreen ?? screen(containing: panel.frame) ?? NSScreen.main ?? NSScreen.screens.first
        guard let screen else {
            isHiding = false
            panel.orderOut(nil)
            return
        }

        let targetFrame = frame(for: screen)
        animationGeneration += 1
        let animationGeneration = animationGeneration
        isHiding = true
        panel.ignoresMouseEvents = true

        if panel.frame != targetFrame {
            panel.setFrame(targetFrame, display: false)
            setRevealMask(on: panel, progress: transitionState.progress)
        }

        withAnimation(.timingCurve(0.35, 0, 0.85, 0.2, duration: 0.24)) {
            transitionState.progress = 0
        }
        animateRevealMask(on: panel, to: 0, duration: 0.24, timingFunction: .notchPanelHide)

        scheduleAnimationCompletion(after: 0.24, generation: animationGeneration) { [weak panel] in
            if let panel {
                self.setRevealMask(on: panel, progress: 0)
                panel.ignoresMouseEvents = false
                panel.orderOut(nil)
            }
            self.isHiding = false
        }
    }

    private func scheduleAnimationCompletion(
        after duration: TimeInterval,
        generation: Int,
        completion: @MainActor @escaping () -> Void
    ) {
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            guard let self, self.animationGeneration == generation else { return }
            completion()
        }
    }

    func toggle() {
        if panel?.isVisible == true, !isHiding {
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
        let hostingView = NSHostingView(rootView: ClipboardPanelView(store: store, transition: transitionState))
        hostingView.wantsLayer = true
        hostingView.layer?.drawsAsynchronously = true

        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .statusBar
        panel.animationBehavior = .none
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .transient]
        panel.contentView = hostingView
        return panel
    }

    private func frame(for screen: NSScreen) -> NSRect {
        let width = min(max(screen.frame.width - 420, 860), 1080)
        let height: CGFloat = 330
        let x = screen.frame.midX - width / 2
        let y = screen.frame.maxY - height
        return NSRect(x: x, y: y, width: width, height: height)
    }

    private func screen(containing frame: NSRect) -> NSScreen? {
        NSScreen.screens.first { $0.frame.intersects(frame) }
    }

    private func setRevealMask(on panel: NSPanel, progress: CGFloat) {
        guard let contentView = panel.contentView else { return }

        contentView.layoutSubtreeIfNeeded()
        guard let layer = contentView.layer else { return }

        let maskLayer = revealMaskLayer(for: layer)
        maskLayer.removeAnimation(forKey: "revealPath")
        maskLayer.frame = layer.bounds
        maskLayer.isGeometryFlipped = false
        maskLayer.path = revealPath(in: layer.bounds, progress: progress)
    }

    private func animateRevealMask(
        on panel: NSPanel,
        to progress: CGFloat,
        duration: TimeInterval,
        timingFunction: CAMediaTimingFunction
    ) {
        guard let contentView = panel.contentView else { return }

        contentView.layoutSubtreeIfNeeded()
        guard let layer = contentView.layer else { return }

        let maskLayer = revealMaskLayer(for: layer)
        maskLayer.frame = layer.bounds
        maskLayer.isGeometryFlipped = false

        let targetPath = revealPath(in: layer.bounds, progress: progress)
        let startPath = maskLayer.presentation()?.path
            ?? maskLayer.path
            ?? revealPath(in: layer.bounds, progress: transitionState.progress)

        maskLayer.removeAnimation(forKey: "revealPath")
        maskLayer.path = targetPath

        let animation = CABasicAnimation(keyPath: "path")
        animation.fromValue = startPath
        animation.toValue = targetPath
        animation.duration = duration
        animation.timingFunction = timingFunction
        animation.isRemovedOnCompletion = true
        maskLayer.add(animation, forKey: "revealPath")
    }

    private func revealMaskLayer(for layer: CALayer) -> CAShapeLayer {
        if let maskLayer = layer.mask as? CAShapeLayer {
            return maskLayer
        }

        let maskLayer = CAShapeLayer()
        maskLayer.fillColor = NSColor.black.cgColor
        layer.mask = maskLayer
        return maskLayer
    }

    private func revealPath(in bounds: CGRect, progress: CGFloat) -> CGPath {
        let clampedProgress = min(max(progress, 0), 1)
        let widthProgress = 0.18 + clampedProgress * 0.82
        let heightProgress = 0.05 + clampedProgress * 0.95
        let width = bounds.width * widthProgress
        let height = bounds.height * heightProgress
        let rect = CGRect(
            x: bounds.midX - width / 2,
            y: bounds.minY,
            width: width,
            height: height
        )

        return CGPath.bottomRoundedRect(rect, cornerRadius: 22)
    }
}

private extension CGPath {
    static func bottomRoundedRect(_ rect: CGRect, cornerRadius: CGFloat) -> CGPath {
        let path = CGMutablePath()
        let radius = min(cornerRadius, rect.width / 2, rect.height / 2)

        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - radius, y: rect.maxY),
            control: CGPoint(x: rect.maxX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY - radius),
            control: CGPoint(x: rect.minX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.closeSubpath()

        return path
    }
}

private extension CAMediaTimingFunction {
    static let notchPanelShow = CAMediaTimingFunction(controlPoints: 0.18, 0.9, 0.2, 1)
    static let notchPanelHide = CAMediaTimingFunction(controlPoints: 0.35, 0, 0.85, 0.2)
}
