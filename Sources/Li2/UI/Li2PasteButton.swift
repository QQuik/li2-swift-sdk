import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// A SwiftUI Paste button that reads the clipboard without triggering the iOS
/// "Allow Paste" alert — the user's tap IS the consent. Available on iOS 16+.
///
/// Use inside a custom consent UI and forward the result to the manager:
/// ```swift
/// Li2PasteButton { raw in
///     Li2DeepLinkManager.shared.submitPasteControlResult(raw)
/// }
/// ```
///
/// For the built-in consent UI with automatic iOS version handling, use
/// `Li2ConsentView` instead.
@available(iOS 16.0, *)
public struct Li2PasteButton: UIViewRepresentable {

    /// Controls which elements of the system Paste button are shown.
    /// Maps 1:1 to `UIPasteControl.DisplayMode`.
    public typealias DisplayMode = UIPasteControl.DisplayMode

    public var displayMode: DisplayMode
    public var backgroundColor: UIColor
    public var foregroundColor: UIColor
    public var onPaste: (String?) -> Void

    public init(
        displayMode: DisplayMode = .labelAndIcon,
        backgroundColor: UIColor = .tintColor,
        foregroundColor: UIColor = .white,
        onPaste: @escaping (String?) -> Void
    ) {
        self.displayMode = displayMode
        self.backgroundColor = backgroundColor
        self.foregroundColor = foregroundColor
        self.onPaste = onPaste
    }

    public func makeCoordinator() -> Coordinator { Coordinator(onPaste: onPaste) }

    public func makeUIView(context: Context) -> _Li2PasteReceiverView {
        let receiver = _Li2PasteReceiverView()
        receiver.onPaste = context.coordinator.onPaste

        let config = UIPasteControl.Configuration()
        config.displayMode = displayMode
        config.cornerStyle = .capsule
        config.baseBackgroundColor = backgroundColor
        config.baseForegroundColor = foregroundColor

        let control = UIPasteControl(configuration: config)
        control.translatesAutoresizingMaskIntoConstraints = false
        // Explicitly set target so the control works inside a fullScreenCover
        // where the SwiftUI responder chain is unreachable. Without this the
        // button is always disabled. (Mirrors Branch SDK's BranchPasteControl.)
        control.target = receiver
        receiver.addSubview(control)
        NSLayoutConstraint.activate([
            control.topAnchor.constraint(equalTo: receiver.topAnchor),
            control.bottomAnchor.constraint(equalTo: receiver.bottomAnchor),
            control.leadingAnchor.constraint(equalTo: receiver.leadingAnchor),
            control.trailingAnchor.constraint(equalTo: receiver.trailingAnchor)
        ])
        return receiver
    }

    public func updateUIView(_ uiView: _Li2PasteReceiverView, context: Context) {
        uiView.onPaste = context.coordinator.onPaste
    }

    public final class Coordinator {
        let onPaste: (String?) -> Void
        init(onPaste: @escaping (String?) -> Void) { self.onPaste = onPaste }
    }
}

/// UIView subclass that serves as the explicit `UIPasteControl.target`.
/// Prefixed with `_Li2` to signal it is a semi-internal implementation detail —
/// public only because UIKit requires it to be accessible to the view hierarchy.
@available(iOS 16.0, *)
public final class _Li2PasteReceiverView: UIView {
    var onPaste: ((String?) -> Void)?

    public override init(frame: CGRect) {
        super.init(frame: frame)
        pasteConfiguration = UIPasteConfiguration(
            acceptableTypeIdentifiers: [UTType.url.identifier, UTType.plainText.identifier]
        )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    public override func canPaste(_ itemProviders: [NSItemProvider]) -> Bool {
        itemProviders.contains {
            $0.hasItemConformingToTypeIdentifier(UTType.url.identifier)
                || $0.hasItemConformingToTypeIdentifier(UTType.plainText.identifier)
        }
    }

    public override func paste(itemProviders: [NSItemProvider]) {
        guard let provider = itemProviders.first else { deliver(nil); return }
        if provider.canLoadObject(ofClass: NSURL.self) {
            provider.loadObject(ofClass: NSURL.self) { [weak self] obj, _ in
                self?.deliver((obj as? URL)?.absoluteString)
            }
        } else if provider.canLoadObject(ofClass: NSString.self) {
            provider.loadObject(ofClass: NSString.self) { [weak self] obj, _ in
                self?.deliver((obj as? NSString) as String?)
            }
        } else {
            deliver(nil)
        }
    }

    private func deliver(_ value: String?) {
        DispatchQueue.main.async { [weak self] in self?.onPaste?(value) }
    }
}
