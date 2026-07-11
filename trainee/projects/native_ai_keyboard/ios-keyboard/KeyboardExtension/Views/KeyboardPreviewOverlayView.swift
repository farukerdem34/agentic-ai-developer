import UIKit

/// AI preview overlay zone (populated by `KeyboardAICoordinator`).
final class KeyboardPreviewOverlayView: UIView {
    let titleLabel = UILabel()
    let closeButton = UIButton(type: .system)
    let textView = UITextView()
    let buttonRow = UIStackView()
    let leadingActions = UIStackView()
    let copyButton = UIButton(type: .system)
    let regenerateButton = UIButton(type: .system)
    let applyButton = UIButton(type: .system)

    /// Kept for localization/call-site compatibility; wired to `closeButton`.
    var discardButton: UIButton { closeButton }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isHidden = true
        layer.masksToBounds = true

        titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        titleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

        textView.font = .systemFont(ofSize: 15)
        textView.isEditable = false
        textView.backgroundColor = .clear

        leadingActions.axis = .horizontal
        leadingActions.spacing = 8
        leadingActions.alignment = .center
        leadingActions.addArrangedSubview(copyButton)
        leadingActions.addArrangedSubview(regenerateButton)

        buttonRow.axis = .horizontal
        buttonRow.spacing = 12
        buttonRow.alignment = .center
        buttonRow.distribution = .fill
        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        spacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        buttonRow.addArrangedSubview(leadingActions)
        buttonRow.addArrangedSubview(spacer)
        buttonRow.addArrangedSubview(applyButton)
    }

    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
