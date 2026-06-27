import AppKit

@MainActor
final class NotchHoverDetector {
    var onHover: ((NSScreen) -> Void)?
    var onExit: (() -> Void)?

    private let panelFrameProvider: () -> NSRect?
    private var timer: Timer?
    private var isHoveringTrigger = false

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
    }

    @objc private func pollTimer() {
        let location = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(location) }) else {
            exitIfNeeded()
            return
        }

        if isInTriggerZone(location, screen: screen) {
            if !isHoveringTrigger {
                isHoveringTrigger = true
                onHover?(screen)
            }
            return
        }

        if let panelFrame = panelFrameProvider() {
            if panelFrame.contains(location) {
                return
            }

            exitIfNeeded(force: true)
            return
        }

        exitIfNeeded()
    }

    private func isInTriggerZone(_ location: NSPoint, screen: NSScreen) -> Bool {
        let top = screen.frame.maxY
        let centerX = screen.frame.midX
        let triggerWidth: CGFloat = min(220, screen.frame.width * 0.16)
        let triggerHeight: CGFloat = 48

        return abs(location.x - centerX) <= triggerWidth / 2
            && location.y >= top - triggerHeight
            && location.y <= top
    }

    private func exitIfNeeded(force: Bool = false) {
        guard force || isHoveringTrigger else { return }
        isHoveringTrigger = false
        onExit?()
    }
}
