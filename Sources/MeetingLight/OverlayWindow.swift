import Cocoa

class OverlayWindow: NSWindow {
    private let borderView = BorderView()
    private let state: LightState
    private var mouseMonitor: Any?
    private var isHovered = false
    private var isAnimating = false
    private var wasEnabled = false

    private var animTimer: Timer?
    private var animStartTime: CFTimeInterval = 0
    private var animFrom: CGFloat = 0
    private var animTo: CGFloat = 0
    private var animCompletion: (() -> Void)?

    private static let animDuration: CFTimeInterval = 0.25

    init(state: LightState) {
        self.state = state

        let screenFrame = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)

        super.init(
            contentRect: screenFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        self.level = .screenSaver
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = false
        self.ignoresMouseEvents = true
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]

        borderView.frame = screenFrame
        borderView.autoresizingMask = [.width, .height]
        self.contentView = borderView

        startMouseTracking()
        applyState()
    }

    private func startMouseTracking() {
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] _ in
            self?.updateHoverState()
        }
    }

    private func updateHoverState() {
        guard state.isEnabled, !isAnimating else { return }

        let mouseLocation = NSEvent.mouseLocation
        let thickness = CGFloat(state.borderSizePercent) * frame.height
        let inner = frame.insetBy(dx: thickness, dy: thickness)
        let cursorInBorder = frame.contains(mouseLocation) && !inner.contains(mouseLocation)

        if cursorInBorder != isHovered {
            isHovered = cursorInBorder
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.15
                borderView.animator().alphaValue = cursorInBorder ? 0.2 : 1.0
            }
        }
    }

    func applyState() {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.frame

        if self.frame != screenFrame {
            self.setFrame(screenFrame, display: false)
        }

        borderView.borderColor = state.currentColor

        if state.isEnabled && !wasEnabled {
            wasEnabled = true
            let target = CGFloat(state.borderSizePercent) * screenFrame.height
            self.orderFrontRegardless()
            animate(from: 0, to: target)
        } else if !state.isEnabled && wasEnabled {
            wasEnabled = false
            let current = borderView.borderThickness
            if isHovered {
                isHovered = false
                borderView.alphaValue = 1.0
            }
            animate(from: current, to: 0) { [weak self] in
                self?.orderOut(nil)
            }
        } else if state.isEnabled && !isAnimating {
            let target = CGFloat(state.borderSizePercent) * screenFrame.height
            borderView.borderThickness = target
            self.orderFrontRegardless()
        }
    }

    // MARK: - Animation

    private func animate(from: CGFloat, to: CGFloat, completion: (() -> Void)? = nil) {
        stopAnimation()
        isAnimating = true
        animFrom = from
        animTo = to
        animStartTime = CACurrentMediaTime()
        animCompletion = completion

        borderView.borderThickness = from

        let timer = Timer(timeInterval: 1.0 / 120.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(timer, forMode: .common)
        animTimer = timer
    }

    private func tick() {
        let elapsed = CACurrentMediaTime() - animStartTime
        let t = min(elapsed / Self.animDuration, 1.0)
        let eased = 1.0 - pow(1.0 - t, 3.0)

        borderView.borderThickness = animFrom + (animTo - animFrom) * CGFloat(eased)

        if t >= 1.0 {
            let completion = animCompletion
            stopAnimation()
            completion?()
        }
    }

    private func stopAnimation() {
        animTimer?.invalidate()
        animTimer = nil
        isAnimating = false
        animCompletion = nil
    }

    deinit {
        stopAnimation()
        if let monitor = mouseMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}
