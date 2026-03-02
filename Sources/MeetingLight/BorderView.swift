import Cocoa
import QuartzCore

class BorderView: NSView {
    var borderColor: NSColor = .white {
        didSet { shapeLayer.fillColor = borderColor.cgColor }
    }
    var borderThickness: CGFloat = 40 {
        didSet { updatePath() }
    }

    private let shapeLayer = CAShapeLayer()

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.addSublayer(shapeLayer)
        shapeLayer.fillRule = .evenOdd
        shapeLayer.fillColor = borderColor.cgColor
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        shapeLayer.frame = bounds
        CATransaction.commit()
        updatePath()
    }

    private func updatePath() {
        let outer = bounds
        guard borderThickness > 0, outer.width > 0, outer.height > 0 else {
            shapeLayer.path = nil
            return
        }

        let path = CGMutablePath()
        path.addRect(outer)
        let inner = outer.insetBy(dx: borderThickness, dy: borderThickness)
        if inner.width > 0, inner.height > 0 {
            path.addRect(inner)
        }

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        shapeLayer.path = path
        CATransaction.commit()
    }
}
