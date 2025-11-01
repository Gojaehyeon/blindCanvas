//
//  OverlayWindow.swift
//  pidgin
//
//  Created by go on 11/1/25.
//

import Cocoa
import SwiftUI

final class OverlayWindow: NSPanel {
    private var overlayController = OverlayController()

    init() {
        let screenRect = NSScreen.main?.frame ?? .zero
        super.init(
            contentRect: screenRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        level = .statusBar
        isOpaque = false
        hasShadow = false
        backgroundColor = .clear
        ignoresMouseEvents = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        contentView = NSHostingView(rootView: overlayController.overlayView())
    }

    func bind(appState: AppState) {
        overlayController.bind(appState: appState)
    }

    func setLocked(_ locked: Bool) {
        overlayController.setLocked(locked)
        ignoresMouseEvents = locked
    }

    // 키 포커스가 가도록 도우미
    func makeFirstResponderToOverlay() {
        if let view = (contentView as? NSHostingView<AnyView>)?.subviews.first
            ?? contentView?.subviews.first {
            self.makeFirstResponder(view)
        } else {
            self.makeFirstResponder(self.contentView)
        }
    }

    // ESC가 눌리면 닫기
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // ESC
            if let delegate = NSApp.delegate as? AppDelegate {
                delegate.dismissOverlay()
                return
            }
        }
        super.keyDown(with: event)
    }
}

// MARK: - Coordinator + View (기존 코드 유지)
private final class OverlayController {
    private weak var appState: AppState?
    private var locked: Bool = false

    func bind(appState: AppState) {
        self.appState = appState
    }

    func setLocked(_ locked: Bool) {
        self.locked = locked
    }

    @ViewBuilder
    func overlayView() -> some View {
        OverlayView(locked: { self.locked },
                    onRectChange: { [weak self] rect in self?.appState?.selectedRect = rect })
            .ignoresSafeArea()
    }
}

private struct OverlayView: NSViewRepresentable {
    let locked: () -> Bool
    let onRectChange: (CGRect) -> Void

    func makeNSView(context: Context) -> SelectionOverlayView {
        let v = SelectionOverlayView()
        v.rectChanged = onRectChange
        v.isLocked = locked()
        // 뷰가 키를 받을 수 있도록
        DispatchQueue.main.async { v.window?.makeFirstResponder(v) }
        return v
    }

    func updateNSView(_ nsView: SelectionOverlayView, context: Context) {
        nsView.isLocked = locked()
        nsView.needsDisplay = true
    }
}
