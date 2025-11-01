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

        level = .statusBar                    // 거의 최상위
        isOpaque = false
        hasShadow = false
        backgroundColor = .clear
        ignoresMouseEvents = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        // SwiftUI 호스팅
        let root = overlayController.overlayView()
        contentView = NSHostingView(rootView: root)
    }

    // SwiftUI(NSViewRepresentable)와 상태 연결
    func bind(appState: AppState) {
        overlayController.bind(appState: appState)
    }

    func setLocked(_ locked: Bool) {
        overlayController.setLocked(locked)
        ignoresMouseEvents = locked
    }

    // 키 입력이 바로 들어오도록 포커스 이동
    func makeFirstResponderToOverlay() {
        if let view = contentView?.subviews.first {
            makeFirstResponder(view)
        } else {
            makeFirstResponder(contentView)
        }
    }

    // 멀티 모니터 환경에서 메인 스크린 중앙에 보정
    func centerOnMainScreenIfNeeded() {
        guard let screen = NSScreen.main else { return }
        setFrame(screen.frame, display: true)
    }

    // ESC → 닫기
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // ESC
            (NSApp.delegate as? AppDelegate)?.dismissOverlay()
            return
        }
        super.keyDown(with: event)
    }
}

// MARK: - Coordinator + View

private final class OverlayController {
    private weak var appState: AppState?
    private var locked: Bool = false

    func bind(appState: AppState) {
        self.appState = appState
        if appState.selectionState == .idle { appState.selectionState = .selecting }
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
        // 오버레이 표시 즉시 ESC가 먹히도록 포커스
        DispatchQueue.main.async { v.window?.makeFirstResponder(v) }
        return v
    }

    func updateNSView(_ nsView: SelectionOverlayView, context: Context) {
        nsView.isLocked = locked()
        nsView.needsDisplay = true
    }
}
