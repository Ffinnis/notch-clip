import AppKit

@MainActor
final class NotchHoverDetector {
    var onHover: ((NSScreen) -> Void)?
    var onExit: (() -> Void)?

    private let panelFrameProvider: () -> NSRect?
    private var timer: Timer?
    private var isHoveringTrigger = false
    private var pendingHide: DispatchWorkItem?

    init(panelFrameProvider: @escaping () -> NSRect?) {
        self.panelFrameProvider = panelFrameProvider
    }

    func start() {
        stop()
        timer = Timer.scheduledTimer(
            timeInterval: 0.1,
            target: self,
            selector: #selector(pollTimer),
            userInfo: nil,
            repeats: true
        )
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        pendingHide?.cancel()
        pendingHide = nil
    }

    @objc private func pollTimer() {
        let location = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(location) }) else {
            exitIfNeeded()
            return
        }

        if isInTriggerZone(location, screen: screen) {
            pendingHide?.cancel()
            pendingHide = nil
            if !isHoveringTrigger {
                isHoveringTrigger = true
                onHover?(screen)
            }
            return
        }

        if let panelFrame = panelFrameProvider(), panelFrame.insetBy(dx: -18, dy: -18).contains(location) {
            pendingHide?.cancel()
            pendingHide = nil
            return
        }

        exitIfNeeded()
    }

    private func isInTriggerZone(_ location: NSPoint, screen: NSScreen) -> Bool {
        let top = screen.frame.maxY
        let centerX = screen.frame.midX
        let triggerWidth: CGFloat = min(460, screen.frame.width * 0.28)
        let triggerHeight: CGFloat = 92

        return abs(location.x - centerX) <= triggerWidth / 2
            && location.y >= top - triggerHeight
            && location.y <= top
    }

    private func exitIfNeeded() {
        guard isHoveringTrigger else { return }
        isHoveringTrigger = false

        pendingHide?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                self?.onExit?()
            }
        }
        pendingHide = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: workItem)
    }
}
