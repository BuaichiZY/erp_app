import SwiftUI
import UIKit

/// The compositor moves the labels at the display refresh rate without rebuilding SwiftUI every frame.
struct DanmakuOverlay: UIViewRepresentable {
    let items: [JSON]
    var compact = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeUIView(context: Context) -> DanmakuCanvas { DanmakuCanvas() }
    func updateUIView(_ view: DanmakuCanvas, context: Context) {
        view.configure(items.prefix(5).map { $0.text("body") }.filter { !$0.isEmpty }, reduceMotion: reduceMotion, compact: compact)
    }
    static func dismantleUIView(_ view: DanmakuCanvas, coordinator: ()) { view.stop() }
}
final class DanmakuCanvas: UIView {
    private var messages: [String] = []
    private var reduced = false
    private var compact = false
    private var renderedSize = CGSize.zero
    override init(frame: CGRect) { super.init(frame: frame); clipsToBounds = true; isUserInteractionEnabled = false; isAccessibilityElement = false }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    func configure(_ messages: [String], reduceMotion: Bool, compact: Bool) {
        guard self.messages != messages || reduced != reduceMotion || self.compact != compact else { return }
        self.messages = messages; reduced = reduceMotion; self.compact = compact; renderedSize = .zero; setNeedsLayout()
    }
    func stop() { subviews.forEach { $0.layer.removeAllAnimations(); $0.removeFromSuperview() } }
    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.size != renderedSize, bounds.width > 0, bounds.height > 0 else { return }
        renderedSize = bounds.size; stop()
        for (index, message) in messages.enumerated() {
            let label = UILabel(); label.text = "  " + message + "  "; label.font = .preferredFont(forTextStyle: compact ? .caption2 : .caption1)
            label.textColor = .white; label.backgroundColor = .black.withAlphaComponent(0.5)
            label.sizeToFit(); let width = min(bounds.width * 0.85, label.bounds.width), height = max(compact ? 24 : 32, label.bounds.height + (compact ? 8 : 14))
            label.frame = CGRect(x: reduced ? 12 : bounds.width, y: bounds.height * ((compact ? 0.16 : 0.23) + CGFloat(index) * (compact ? 0.1 : 0.13)), width: width, height: height)
            label.layer.cornerRadius = height / 2; label.clipsToBounds = true; addSubview(label)
            guard !reduced else { continue }
            let animation = CABasicAnimation(keyPath: "transform.translation.x")
            animation.fromValue = 0; animation.toValue = -(bounds.width + width)
            animation.duration = DanmakuTiming.duration(containerWidth: Double(bounds.width), messageWidth: Double(width)); animation.repeatCount = .infinity
            animation.timingFunction = CAMediaTimingFunction(name: .linear)
            animation.beginTime = layer.convertTime(CACurrentMediaTime(), from: nil) - animation.duration * Double(index) / Double(max(1, messages.count))
            label.layer.add(animation, forKey: "danmaku.travel")
        }
    }
}
