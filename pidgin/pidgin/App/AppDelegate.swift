//
//  AppDelegate.swift
//  pidgin
//
//  Created by go on 11/1/25.
//

import Cocoa
import SwiftUI
import KeyboardShortcuts

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var overlayWindow: OverlayWindow?
    private var appState: AppState?

    // ⬇️ ESC 키를 가로채기 위한 로컬 모니터 핸들
    private var escMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        KeyboardShortcuts.setShortcut(.init(.one, modifiers: [.command, .shift]), for: .toggleOverlay)
        KeyboardShortcuts.onKeyUp(for: .toggleOverlay) { [weak self] in
            self?.toggleOverlay()
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    func setAppState(_ state: AppState) {
        self.appState = state
        overlayWindow?.bind(appState: state)
    }

    // MARK: - Overlay control

    func toggleOverlay() {
        if overlayWindow?.isVisible == true {
            dismissOverlay()
        } else {
            presentOverlay()
        }
    }

    func presentOverlay() {
        if overlayWindow == nil {
            overlayWindow = OverlayWindow()
            if let appState { overlayWindow?.bind(appState: appState) }
        }

        overlayWindow?.setLocked(false)
        overlayWindow?.makeKeyAndOrderFront(nil)
        overlayWindow?.centerOnMainScreenIfNeeded()
        overlayWindow?.makeFirstResponderToOverlay()

        // ⬇️ ESC 로컬 모니터 등록 (오버레이 보이는 동안만)
        escMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.overlayWindow?.isVisible == true else { return event }
            if event.keyCode == 53 { // ESC
                self.dismissOverlay()
                return nil // 이벤트 소비
            }
            return event
        }

        appState?.selectionState = .selecting
        appState?.overlayVisible = true
    }

    func dismissOverlay() {
        overlayWindow?.orderOut(nil)

        // ⬇️ ESC 모니터 해제
        if let escMonitor {
            NSEvent.removeMonitor(escMonitor)
            self.escMonitor = nil
        }

        appState?.overlayVisible = false
        appState?.reset()
    }
}
