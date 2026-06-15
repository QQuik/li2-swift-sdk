//
//  Li2PasteButton.swift
//  Li2
//
//  SwiftUI bridge around UIKit's UIPasteControl (iOS 16+).
//
//  Copied verbatim from li2-deeplink-kit-ios/Sources/Li2DeepLink/Li2ClipboardPasteButton.swift.
//  Two changes vs the kit: (1) type renamed from Li2ClipboardPasteButton to Li2PasteButton;
//  (2) PasteReceiverView is internal (not public) — implementation detail.
//
//  Why this exists: a tap on UIPasteControl IS the clipboard consent, so the
//  system never shows the "Allow Paste / Don't Allow" alert. There is no
//  SwiftUI-native equivalent, so we host the system control inside a
//  UIPasteConfigurationSupporting UIView and surface the pasted value via a
//  closure. The button label/icon is system-owned ("Paste"); only colors,
//  corner style and display mode are configurable.
//
//  Enablement: UIPasteControl asks its `target` (a UIPasteConfigurationSupporting
//  object) whether the pasteboard is acceptable. With NO target it walks the
//  responder chain — which a UIViewRepresentable inside a SwiftUI
//  fullScreenCover is NOT reachable through, so the control fails closed to
//  disabled. The fix (mirrors Branch SDK's BranchPasteControl) is to set
//  `control.target` explicitly and implement canPaste(_:) / paste(itemProviders:).
//

#if canImport(UIKit)
import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// A SwiftUI Paste button that reads the clipboard without triggering the iOS
/// "Allow Paste" alert (the user's tap is the consent). Use it inside your
/// first-launch consent UI and forward the result to the resolver:
///
/// ```swift
/// Li2PasteButton { raw in
///     resolver.submitPasteControlResult(raw)
/// }
/// ```
@available(iOS 16.0, *)
public struct Li2PasteButton: UIViewRepresentable {
    /// Called with the pasted string, or `nil` if nothing loadable was on the clipboard.
    public var onPaste: (String?) -> Void

    /// Button background tint. Defaults to the system tint.
    public var backgroundColor: UIColor

    /// Button foreground (label/icon) color. Defaults to white.
    public var foregroundColor: UIColor

    public init(
        backgroundColor: UIColor = .tintColor,
        foregroundColor: UIColor = .white,
        onPaste: @escaping (String?) -> Void
    ) {
        self.backgroundColor = backgroundColor
        self.foregroundColor = foregroundColor
        self.onPaste = onPaste
    }

    public func makeCoordinator() -> Coordinator { Coordinator(onPaste: onPaste) }

    public func makeUIView(context: Context) -> PasteReceiverView {
        let receiver = PasteReceiverView()
        receiver.onPaste = context.coordinator.onPaste

        let config = UIPasteControl.Configuration()
        config.displayMode = .iconAndLabel
        config.cornerStyle = .capsule
        config.baseBackgroundColor = backgroundColor
        config.baseForegroundColor = foregroundColor

        let control = UIPasteControl(configuration: config)
        control.translatesAutoresizingMaskIntoConstraints = false
        // The decisive line: name the target explicitly so the control asks
        // `receiver` directly instead of failing to resolve it via the
        // responder chain inside the fullScreenCover.
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

    public func updateUIView(_ uiView: PasteReceiverView, context: Context) {
        uiView.onPaste = context.coordinator.onPaste
    }

    public final class Coordinator {
        let onPaste: (String?) -> Void
        init(onPaste: @escaping (String?) -> Void) { self.onPaste = onPaste }
    }
}

/// The UIPasteControl's explicit `target`. UIView already conforms to
/// UIPasteConfigurationSupporting (via UIResponder); being named as the
/// control's target — plus overriding canPaste(_:)/paste(itemProviders:) — is
/// what enables it inside a SwiftUI fullScreenCover.
@available(iOS 16.0, *)
final class PasteReceiverView: UIView {
    var onPaste: ((String?) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        pasteConfiguration = UIPasteConfiguration(
            acceptableTypeIdentifiers: [UTType.url.identifier, UTType.plainText.identifier]
        )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// Drives the control's enabled state: the system calls this on the target
    /// with the live pasteboard's item providers each time it re-evaluates.
    override func canPaste(_ itemProviders: [NSItemProvider]) -> Bool {
        itemProviders.contains {
            $0.hasItemConformingToTypeIdentifier(UTType.url.identifier)
                || $0.hasItemConformingToTypeIdentifier(UTType.plainText.identifier)
        }
    }

    override func paste(itemProviders: [NSItemProvider]) {
        guard let provider = itemProviders.first else {
            deliver(nil)
            return
        }
        if provider.canLoadObject(ofClass: NSURL.self) {
            provider.loadObject(ofClass: NSURL.self) { [weak self] object, _ in
                self?.deliver((object as? URL)?.absoluteString)
            }
        } else if provider.canLoadObject(ofClass: NSString.self) {
            provider.loadObject(ofClass: NSString.self) { [weak self] object, _ in
                self?.deliver((object as? NSString) as String?)
            }
        } else {
            deliver(nil)
        }
    }

    private func deliver(_ value: String?) {
        DispatchQueue.main.async { [weak self] in self?.onPaste?(value) }
    }
}
#endif
