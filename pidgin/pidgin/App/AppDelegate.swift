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
        
        // PidginApp의 appState를 가져와서 연결
        // PidginApp이 이미 초기화되어 있어야 함
        DispatchQueue.main.async { [weak self] in
            if let pidginApp = NSApp.delegate as? AppDelegate {
                // ContentView의 onAppear에서 설정될 때까지 대기
                // 여기서는 일단 nil 체크만
            }
        }
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
        print("🎬 presentOverlay() called")
        print("📦 overlayWindow: \(overlayWindow != nil ? "exists" : "nil")")
        print("📦 appState: \(appState != nil ? "exists" : "nil")")
        
        // appState가 nil이면 ContentView에서 설정될 때까지 대기
        if appState == nil {
            print("⚠️ appState is nil, trying to get from ContentView...")
            // 잠시 후 다시 시도 (ContentView.onAppear가 실행되었을 수 있음)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                if let self = self, let appState = self.appState {
                    print("✅ appState found after delay, creating overlay")
                    self.presentOverlayInternal()
                } else {
                    print("❌ appState still nil, cannot create overlay")
                }
            }
            return
        }
        
        presentOverlayInternal()
    }
    
    private func presentOverlayInternal() {
        guard let appState = appState else {
            print("❌ presentOverlayInternal: appState is still nil")
            return
        }
        
        if overlayWindow == nil {
            print("🆕 Creating new OverlayWindow")
            overlayWindow = OverlayWindow()
        }
        
        print("🔗 Calling bind(appState)")
        overlayWindow?.bind(appState: appState)

        
        overlayWindow?.setLocked(false)
        overlayWindow?.makeKeyAndOrderFront(nil)
        overlayWindow?.centerOnMainScreenIfNeeded()
        
        print("👁️ Window should be visible now")
        
        // 뷰가 생성된 후 first responder 설정 (약간의 지연 필요)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            print("⏰ Delayed first responder setup")
            self.overlayWindow?.makeFirstResponderToOverlay()
        }

        // 키 입력은 SelectionOverlayView에서 직접 처리
        // escMonitor는 사용하지 않음 (ESC도 SelectionOverlayView에서 처리)

        appState.selectionState = .selecting
        appState.overlayVisible = true
    }

    func dismissOverlay() {
        print("🚪 dismissOverlay() called")
        print("📦 overlayWindow exists: \(overlayWindow != nil)")
        print("📦 overlayWindow isVisible: \(overlayWindow?.isVisible ?? false)")
        
        // TTS 재생 중지
        TextToSpeechService.shared.stop()
        
        // 먼저 ESC 모니터 해제 (중복 호출 방지)
        if let escMonitor {
            NSEvent.removeMonitor(escMonitor)
            self.escMonitor = nil
            print("🗑️ ESC monitor removed")
        }
        
        guard let window = overlayWindow else {
            print("⚠️ overlayWindow is nil")
            appState?.overlayVisible = false
            appState?.isTTSPlaying = false
            appState?.reset()
            return
        }
        
        guard window.isVisible else {
            print("⚠️ Window is not visible, already dismissed")
            appState?.overlayVisible = false
            appState?.isTTSPlaying = false
            appState?.reset()
            return
        }
        
        print("👋 Hiding overlay window")
        window.resignKey()
        window.orderOut(nil)
        window.isReleasedWhenClosed = false // 창을 완전히 닫지 않고 숨김
        
        appState?.overlayVisible = false
        appState?.isTTSPlaying = false
        appState?.reset()
        
        // 윈도우가 완전히 사라졌는지 확인
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            print("✅ Overlay dismissed, isVisible=\(window.isVisible)")
        }
    }
}
