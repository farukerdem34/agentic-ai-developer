import UIKit

protocol KeyboardChromeOptionsDelegate: AnyObject {
    func chromeOptionsLocalize(_ key: String) -> String
    func chromeOptionsDidChangeAccent()
    func chromeOptionsIsDark() -> Bool
}

/// When the panel is visible, captures taps outside the card to dismiss; passes through when hidden.
private final class PassthroughOverlay: UIView {
    weak var dismissCard: UIView?

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard !isHidden, alpha > 0.01, bounds.contains(point) else { return nil }
        if let card = dismissCard {
            let cardPoint = convert(point, to: card)
            if card.bounds.contains(cardPoint) {
                return card.hitTest(cardPoint, with: event) ?? card
            }
            return self
        }
        return super.hitTest(point, with: event)
    }
}

/// Settings card drops below the toolbar inside the keyboard chrome.
final class KeyboardChromeOptionsPresenter {
    private weak var delegate: KeyboardChromeOptionsDelegate?
    private weak var layoutView: UIView?
    private weak var toolbarAnchor: UIView?

    private let overlay = PassthroughOverlay()
    private let card = UIStackView()
    private let titleLabel = UILabel()
    private let accentRow = UIStackView()
    private var isVisible = false

    init(delegate: KeyboardChromeOptionsDelegate) {
        self.delegate = delegate
    }

    func install(on layoutView: UIView, toolbarAnchor: UIView) {
        guard self.layoutView == nil else { return }
        self.layoutView = layoutView
        self.toolbarAnchor = toolbarAnchor

        overlay.translatesAutoresizingMaskIntoConstraints = false
        overlay.isHidden = true
        overlay.alpha = 0
        overlay.isUserInteractionEnabled = true
        overlay.layer.zPosition = 1000
        overlay.backgroundColor = .clear
        layoutView.addSubview(overlay)

        card.axis = .vertical
        card.spacing = 10
        card.alignment = .fill
        card.isLayoutMarginsRelativeArrangement = true
        card.layoutMargins = UIEdgeInsets(top: 10, left: 12, bottom: 10, right: 12)
        card.translatesAutoresizingMaskIntoConstraints = false
        card.layer.cornerRadius = 14
        card.clipsToBounds = true
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.18
        card.layer.shadowRadius = 8
        card.layer.shadowOffset = CGSize(width: 0, height: 2)
        overlay.addSubview(card)
        overlay.dismissCard = card

        let outsideTap = UITapGestureRecognizer(target: self, action: #selector(overlayTapped(_:)))
        outsideTap.cancelsTouchesInView = true
        overlay.addGestureRecognizer(outsideTap)

        accentRow.axis = .horizontal
        accentRow.spacing = 8
        accentRow.alignment = .center
        accentRow.distribution = .fillEqually

        titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        titleLabel.text = delegate?.chromeOptionsLocalize("keyboard.chrome_menu_title")
        titleLabel.numberOfLines = 1

        card.addArrangedSubview(titleLabel)
        card.addArrangedSubview(accentRow)

        NSLayoutConstraint.activate([
            overlay.topAnchor.constraint(equalTo: layoutView.topAnchor),
            overlay.leadingAnchor.constraint(equalTo: layoutView.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: layoutView.trailingAnchor),
            overlay.bottomAnchor.constraint(equalTo: layoutView.bottomAnchor),

            card.topAnchor.constraint(equalTo: toolbarAnchor.bottomAnchor, constant: 8),
            card.leadingAnchor.constraint(equalTo: layoutView.leadingAnchor, constant: 12),
            card.trailingAnchor.constraint(equalTo: layoutView.trailingAnchor, constant: -12),
        ])

        rebuildContent()
        applyAppearance()
    }

    var panelIsVisible: Bool { isVisible }

    func toggle() {
        if isVisible {
            hide()
        } else {
            rebuildContent()
            show()
        }
    }

    func hide() {
        guard isVisible else { return }
        isVisible = false
        UIView.animate(withDuration: 0.15, animations: {
            self.overlay.alpha = 0
        }, completion: { _ in
            self.overlay.isHidden = true
            self.overlay.backgroundColor = .clear
        })
    }

    @objc private func overlayTapped(_ gesture: UITapGestureRecognizer) {
        guard isVisible else { return }
        let point = gesture.location(in: overlay)
        let cardFrame = card.convert(card.bounds, to: overlay)
        if !cardFrame.contains(point) {
            hide()
        }
    }

    func rebuildIfVisible() {
        rebuildContent()
        if isVisible {
            applyAppearance()
        }
    }

    func applyAppearance() {
        let isDark = delegate?.chromeOptionsIsDark() ?? false
        let palette = KeyboardNativePalette.colors(isDark: isDark)
        card.backgroundColor = palette.chromeCard
        titleLabel.textColor = palette.primaryText
        titleLabel.text = delegate?.chromeOptionsLocalize("keyboard.chrome_menu_title")
        overlay.backgroundColor = .clear
    }

    private func show() {
        guard let layoutView else { return }
        layoutView.bringSubviewToFront(overlay)
        isVisible = true
        overlay.isHidden = false
        applyAppearance()
        UIView.animate(withDuration: 0.2) {
            self.overlay.alpha = 1
        }
        logPanelFrame()
    }

    private func logPanelFrame() {
        guard let layoutView else { return }
        layoutView.layoutIfNeeded()
        let cardFrame = card.convert(card.bounds, to: layoutView)
        KeyboardExtensionDiagnostics.log(
            String(format: "chromePanel frame=%.0f,%.0f %.0fx%.0f", cardFrame.minX, cardFrame.minY, cardFrame.width, cardFrame.height)
        )
    }

    private func rebuildContent() {
        titleLabel.text = delegate?.chromeOptionsLocalize("keyboard.chrome_menu_title")

        accentRow.arrangedSubviews.forEach {
            accentRow.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        let currentAccent = AppGroupStore.shared.keyboardChromeAccent
        for accent in KeyboardChromeAccent.allCases {
            let btn = accentOptionButton(accent: accent, selected: accent == currentAccent)
            btn.addAction(UIAction { [weak self] _ in
                AppGroupStore.shared.keyboardChromeAccent = accent
                self?.delegate?.chromeOptionsDidChangeAccent()
            }, for: .touchUpInside)
            accentRow.addArrangedSubview(btn)
        }
    }

    private func accentOptionButton(accent: KeyboardChromeAccent, selected: Bool) -> UIButton {
        let b = UIButton(type: .custom)
        b.isExclusiveTouch = true
        b.accessibilityLabel = delegate?.chromeOptionsLocalize(accent.localizationKey)
        b.translatesAutoresizingMaskIntoConstraints = false
        b.heightAnchor.constraint(equalToConstant: 36).isActive = true

        let dot = UIView()
        dot.isUserInteractionEnabled = false
        dot.backgroundColor = accent.uiColor
        dot.translatesAutoresizingMaskIntoConstraints = false
        dot.layer.cornerRadius = 14
        dot.clipsToBounds = true
        b.addSubview(dot)
        NSLayoutConstraint.activate([
            dot.centerXAnchor.constraint(equalTo: b.centerXAnchor),
            dot.centerYAnchor.constraint(equalTo: b.centerYAnchor),
            dot.widthAnchor.constraint(equalToConstant: 28),
            dot.heightAnchor.constraint(equalToConstant: 28),
        ])

        if selected {
            b.layer.borderWidth = 2
            b.layer.borderColor = accent.uiColor.cgColor
            b.layer.cornerRadius = 18
        }
        return b
    }
}
