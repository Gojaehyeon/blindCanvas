//
//  AppDelegate.swift
//  pidgin
//
//  Created by go on 11/1/25.
//

import Cocoa
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var overlayWindow: OverlayWindow?
    private var appState: AppState?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 자동으로 오버레이를 만들지 않음
        NSApp.activate(ignoringOtherApps: true)
    }

    func setAppState(_ state: AppState) {
        self.appState = state
    }

    // MARK: - Overlay control
    func presentOverlay() {
        guard let appState else { return }

        if overlayWindow == nil {
            overlayWindow = OverlayWindow()
        }
        overlayWindow?.bind(appState: appState)
        overlayWindow?.setLocked(false)
        overlayWindow?.orderFrontRegardless()
        overlayWindow?.makeKey()                    // 키 이벤트 받도록
        overlayWindow?.makeFirstResponderToOverlay()// ESC 인식
        appState.selectionState = .selecting
        appState.overlayVisible = true
    }

    func dismissOverlay() {
        guard let appState else { return }
        overlayWindow?.orderOut(nil)
        appState.overlayVisible = false
        appState.reset()
    }
}
