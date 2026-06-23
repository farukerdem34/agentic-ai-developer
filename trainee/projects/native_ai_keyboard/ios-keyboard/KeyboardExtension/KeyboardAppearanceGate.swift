import UIKit

/// Hides the keyboard until height, window attachment, and chrome are stable (globe switch).
final class KeyboardAppearanceGate {
    /// Globe-switch loading + iOS 26 glass mask. `false` = direct open (A/B test).
    /// Set back to `true` to restore loading overlay.
    static var isEnabled = true

    struct LayoutSnapshot {
        let hostHeight: CGFloat
        let targetHeight: CGFloat
        let shellHeight: CGFloat
        let inWindow: Bool
        let contentReady: Bool
    }

    var onBeforeReveal: (() -> Void)?
    var onDidReveal: (() -> Void)?

    var maskingOverlay: UIView { overlay }
    private let overlay = UIView()
    private let spinner = UIActivityIndicatorView(style: .medium)

    private weak var hostView: UIView?
    private weak var contentView: UIView?

    private var isActive = false
    private var shownAt: CFTimeInterval = 0
    private var stableLayoutPasses = 0
    private var lastStableHeight: CGFloat?
    private var revealWorkItem: DispatchWorkItem?
    private var maxRevealWorkItem: DispatchWorkItem?

    private let minVisibleDuration: TimeInterval = 0.52
    private let maxVisibleDuration: TimeInterval = 1.15
    private let postFinalizeDelay: TimeInterval = 0.1
    private let stablePassesRequired = 5
    private let heightTolerance: CGFloat = 2.5

    var isBlockingDisplay: Bool { Self.isEnabled && isActive }

    func install(on host: UIView, contentView: UIView) {
        guard Self.isEnabled else { return }
        hostView = host
        self.contentView = contentView

        overlay.translatesAutoresizingMaskIntoConstraints = false
        overlay.isUserInteractionEnabled = true
        overlay.alpha = 0
        overlay.isHidden = true

        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.hidesWhenStopped = false
        overlay.addSubview(spinner)

        host.addSubview(overlay)
        NSLayoutConstraint.activate([
            overlay.leadingAnchor.constraint(equalTo: host.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: host.trailingAnchor),
            overlay.topAnchor.constraint(equalTo: host.topAnchor),
            overlay.bottomAnchor.constraint(equalTo: host.bottomAnchor),
            spinner.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: overlay.centerYAnchor),
        ])
    }

    func beginTransition(isDark: Bool) {
        guard Self.isEnabled, hostView != nil else { return }

        revealWorkItem?.cancel()
        maxRevealWorkItem?.cancel()
        isActive = true
        stableLayoutPasses = 0
        lastStableHeight = nil
        shownAt = CACurrentMediaTime()

        applyOverlayColors(isDark: isDark)
        overlay.isHidden = false
        overlay.alpha = 1
        bringToFront()
        spinner.startAnimating()
        contentView?.isHidden = true
        contentView?.alpha = 1

        let maxWork = DispatchWorkItem { [weak self] in
            self?.finalizeAndReveal()
        }
        maxRevealWorkItem = maxWork
        DispatchQueue.main.asyncAfter(deadline: .now() + maxVisibleDuration, execute: maxWork)
    }

    func updateTransitionColors(isDark: Bool) {
        guard Self.isEnabled, isActive else { return }
        applyOverlayColors(isDark: isDark)
    }

    func bringToFront() {
        guard let hostView, !overlay.isHidden else { return }
        hostView.bringSubviewToFront(overlay)
    }

    func noteLayoutPass(_ snapshot: LayoutSnapshot) {
        guard Self.isEnabled, isActive else { return }

        let heightDelta = abs(snapshot.hostHeight - snapshot.targetHeight)
        let heightMatches = heightDelta <= heightTolerance && snapshot.hostHeight > 80
        let shellFills = snapshot.shellHeight >= snapshot.hostHeight * 0.98 || snapshot.shellHeight >= snapshot.targetHeight * 0.94
        let heightUnchanged: Bool
        if let lastStableHeight {
            heightUnchanged = abs(lastStableHeight - snapshot.hostHeight) <= 1
        } else {
            heightUnchanged = true
        }

        if snapshot.inWindow,
           snapshot.contentReady,
           heightMatches,
           shellFills,
           heightUnchanged
        {
            stableLayoutPasses += 1
            lastStableHeight = snapshot.hostHeight
        } else {
            stableLayoutPasses = 0
            if heightMatches {
                lastStableHeight = snapshot.hostHeight
            } else {
                lastStableHeight = nil
            }
        }

        guard stableLayoutPasses >= stablePassesRequired else { return }

        let elapsed = CACurrentMediaTime() - shownAt
        let delay = max(0, minVisibleDuration - elapsed)

        revealWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.finalizeAndReveal()
        }
        revealWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    func endTransitionImmediately() {
        guard Self.isEnabled || isActive else { return }
        revealWorkItem?.cancel()
        maxRevealWorkItem?.cancel()
        isActive = false
        stableLayoutPasses = 0
        lastStableHeight = nil
        spinner.stopAnimating()
        overlay.isHidden = true
        overlay.alpha = 0
        contentView?.isHidden = false
        contentView?.alpha = 1
        onDidReveal?()
    }

    private func applyOverlayColors(isDark: Bool) {
        let fill = KeyboardHostChromePolicy.loadingMaskColor(isDark: isDark)
        overlay.isOpaque = true
        overlay.backgroundColor = fill
        spinner.color = isDark ? UIColor(white: 0.92, alpha: 1) : UIColor(white: 0.45, alpha: 1)
    }

    private func finalizeAndReveal() {
        guard isActive else { return }
        revealWorkItem?.cancel()
        maxRevealWorkItem?.cancel()

        onBeforeReveal?()

        DispatchQueue.main.asyncAfter(deadline: .now() + postFinalizeDelay) { [weak self] in
            self?.reveal(animated: true)
        }
    }

    private func reveal(animated: Bool) {
        guard isActive else { return }
        isActive = false
        stableLayoutPasses = 0
        lastStableHeight = nil
        spinner.stopAnimating()

        contentView?.isHidden = false
        contentView?.alpha = 1

        let hideOverlay = {
            self.overlay.alpha = 0
        }
        let completion = { (_: Bool) in
            self.overlay.isHidden = true
        }

        if animated {
            UIView.animate(
                withDuration: 0.24,
                delay: 0,
                options: [.curveEaseOut, .beginFromCurrentState],
                animations: hideOverlay,
                completion: { finished in
                    completion(finished)
                    self.onDidReveal?()
                }
            )
        } else {
            hideOverlay()
            completion(true)
            onDidReveal?()
        }
    }
}
