import SwiftUI
import UIKit

/// Ready-made first-launch consent sheet. Handles iOS version differences
/// automatically: iOS 16+ shows a `Li2PasteButton` (no OS alert); iOS 14–15
/// shows a "Continue" button that reads the clipboard via `UIPasteboard`
/// (triggers a passive banner, non-blocking).
///
/// Drop into a `.fullScreenCover` bound to `Li2DeepLinkManager.shared.isConsentPending`:
///
/// ```swift
/// .fullScreenCover(isPresented: $manager.isConsentPending) {
///     Li2ConsentView()
/// }
/// ```
///
/// Or customise fully:
/// ```swift
/// Li2ConsentView(
///     title: "Find your link",
///     message: "Tap below to paste the link you copied.",
///     showSkipButton: true
/// ) {
///     Image("AppIcon")
///         .resizable()
///         .frame(width: 64, height: 64)
///         .cornerRadius(14)
/// }
/// ```
public struct Li2ConsentView<Header: View>: View {

    private let title: String
    private let message: String
    private let showSkipButton: Bool
    private let header: Header

    @ObservedObject private var manager = Li2DeepLinkManager.shared
    @State private var hasClipboardContent = ClipboardProber.hasContent()

    public init(
        title: String = "Continue where you left off",
        message: String = "Tap below to check if you have a link waiting.",
        showSkipButton: Bool = true,
        @ViewBuilder header: () -> Header
    ) {
        self.title = title
        self.message = message
        self.showSkipButton = showSkipButton
        self.header = header()
    }

    public var body: some View {
        VStack(spacing: 24) {
            Spacer()

            header

            VStack(spacing: 12) {
                Text(title)
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)

            clipboardAction

            if showSkipButton {
                Button("Not now") {
                    manager.submitOptOut()
                }
                .foregroundStyle(.secondary)
                .font(.subheadline)
            }

            Spacer()
        }
        .padding()
        .onAppear { hasClipboardContent = ClipboardProber.hasContent() }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            hasClipboardContent = ClipboardProber.hasContent()
        }
    }

    @ViewBuilder
    private var clipboardAction: some View {
        if hasClipboardContent {
            Li2PasteButton(displayMode: .iconAndLabel) { raw in
                manager.submitPasteControlResult(raw)
            }
            .frame(height: 44)
            .padding(.horizontal, 32)
        } else {
            continueButton
        }
    }

    private var continueButton: some View {
        Button {
            manager.beginRawProbeOptIn()
        } label: {
            Text("Continue")
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.accentColor)
                .foregroundStyle(.white)
                .clipShape(Capsule())
        }
        .padding(.horizontal, 32)
    }

}

// Convenience init with no header
extension Li2ConsentView where Header == EmptyView {
    public init(
        title: String = "Continue where you left off",
        message: String = "Tap below to check if you have a link waiting.",
        showSkipButton: Bool = true
    ) {
        self.init(title: title, message: message, showSkipButton: showSkipButton) {
            EmptyView()
        }
    }
}
