import UIKit

/// Responsive keyboard height for `UIInputView` (see Apple: Configuring a Custom Keyboard Interface).
enum KeyboardPresentationLayout {
    private static weak var boundInputView: UIView?
    private static weak var heightConstraint: NSLayoutConstraint?

    /// Design height scaled to current width and orientation.
    static func targetContentHeight(for width: CGFloat, isLandscape: Bool = false) -> CGFloat {
        let w = max(320, width > 1 ? width : 390)
        return AppleKeyboardMetrics.totalDesignHeight(for: w, isLandscape: isLandscape)
    }

    /// Reliable width when `UIInputView` bounds are stale after keyboard switch.
    static func effectiveLayoutWidth(for inputView: UIView) -> CGFloat {
        if inputView.bounds.width > 1 { return inputView.bounds.width }
        if let windowWidth = inputView.window?.bounds.width, windowWidth > 1 { return windowWidth }
        return UIScreen.main.bounds.width
    }

    static func installHeightConstraint(on inputView: UIView, isLandscape: Bool = false) {
        reconcileHeight(for: inputView, isLandscape: isLandscape, force: true)
    }

    static func refreshHeightIfNeeded(for inputView: UIView, isLandscape: Bool = false) {
        reconcileHeight(for: inputView, isLandscape: isLandscape, force: false)
    }

    /// Keeps height stable when switching back from emoji/system keyboard (bounds often briefly wrong).
    static func reconcileHeight(for inputView: UIView, isLandscape: Bool, force: Bool) {
        let width = effectiveLayoutWidth(for: inputView)
        let target = targetContentHeight(for: width, isLandscape: isLandscape)

        if boundInputView !== inputView {
            heightConstraint?.isActive = false
            heightConstraint = nil
            boundInputView = inputView
        }

        if let hc = heightConstraint {
            if force || abs(hc.constant - target) > 0.5 {
                hc.constant = target
            }
        } else {
            let c = inputView.heightAnchor.constraint(equalToConstant: target)
            c.priority = UILayoutPriority(999)
            c.isActive = true
            heightConstraint = c
        }

        let rendered = inputView.bounds.height
        if force || rendered > 1, rendered < target * 0.9 {
            heightConstraint?.constant = target
            inputView.setNeedsLayout()
        }
    }
}
