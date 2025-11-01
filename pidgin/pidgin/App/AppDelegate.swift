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
        // ⌘⇧1: 오버레이 토글
        KeyboardShortcuts.setShortcut(.init(.one, modifiers: [.command, .shift]), for: .toggleOverlay)
        KeyboardShortcuts.onKeyUp(for: .toggleOverlay) { [weak self] in
            self?.toggleOverlay()
        }
        
        // ⌘⇧2: 최근 저장된 영역으로 바로 열기
        KeyboardShortcuts.setShortcut(.init(.two, modifiers: [.command, .shift]), for: .showLastRegion)
        KeyboardShortcuts.onKeyUp(for: .showLastRegion) { [weak self] in
            self?.showLastRegion()
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
    
    /// 최근 저장된 영역으로 바로 열기
    func showLastRegion() {
        guard let appState = appState else {
            print("❌ showLastRegion: appState is nil")
            return
        }
        
        print("🔍 showLastRegion called")
        print("📊 lastLockedRect: \(appState.lastLockedRect)")
        print("📊 selectedRect: \(appState.selectedRect)")
        
        // 저장된 영역이 없으면 일반 토글과 동일하게 동작
        if appState.lastLockedRect == .zero {
            print("⚠️ No saved region, falling back to toggle")
            toggleOverlay()
            return
        }
        
        // 이미 열려있으면 닫기
        if overlayWindow?.isVisible == true {
            print("📌 Overlay already visible, dismissing")
            dismissOverlay()
            return
        }
        
        // 저장된 영역이 있으면 바로 Locked 상태로 열기
        print("✅ Using saved region, opening with lastLockedRect")
        presentOverlayWithLastRegion()
    }
    
    private func presentOverlayWithLastRegion() {
        guard let appState = appState else {
            print("❌ presentOverlayWithLastRegion: appState is nil")
            return
        }
        
        if overlayWindow == nil {
            print("🆕 Creating new OverlayWindow")
            overlayWindow = OverlayWindow()
        }
        
        print("🔗 Calling bind(appState)")
        
        // 저장된 영역으로 바로 설정
        appState.selectedRect = appState.lastLockedRect
        appState.selectionState = .locked
        
        overlayWindow?.bind(appState: appState)
        
        overlayWindow?.setLocked(true)
        overlayWindow?.makeKeyAndOrderFront(nil)
        overlayWindow?.centerOnMainScreenIfNeeded()
        
        print("👁️ Window should be visible now with last region")
        
        // 뷰가 생성된 후 first responder 및 저장된 영역 설정
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            print("⏰ Delayed first responder setup")
            self.overlayWindow?.makeFirstResponderToOverlay()
            
            // 저장된 영역을 뷰에 강제로 설정
            if let view = self.overlayWindow?.getSelectionView() {
                print("🔧 Force setting selectionRect to view: \(appState.lastLockedRect)")
                view.selectionRect = appState.lastLockedRect
                view.isLocked = true
                view.needsDisplay = true
            }
        }

        appState.overlayVisible = true
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
        
        // ⌘⇧1은 항상 새로 그리기 모드로 시작 (lastLockedRect 사용 안 함)
        appState.selectionState = .selecting
        appState.selectedRect = .zero
        
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
            let savedRect = appState?.lastLockedRect ?? .zero
            appState?.reset()
            appState?.lastLockedRect = savedRect
            return
        }
        
        guard window.isVisible else {
            print("⚠️ Window is not visible, already dismissed")
            appState?.overlayVisible = false
            appState?.isTTSPlaying = false
            let savedRect = appState?.lastLockedRect ?? .zero
            appState?.reset()
            appState?.lastLockedRect = savedRect
            return
        }
        
        print("👋 Hiding overlay window")
        window.resignKey()
        window.orderOut(nil)
        window.isReleasedWhenClosed = false // 창을 완전히 닫지 않고 숨김
        
        appState?.overlayVisible = false
        appState?.isTTSPlaying = false
        
        // reset()은 lastLockedRect를 유지하지만, 상태만 리셋
        let savedRect = appState?.lastLockedRect ?? .zero
        appState?.reset()
        appState?.lastLockedRect = savedRect  // lastLockedRect 복원
        print("💾 Preserved lastLockedRect after reset: \(appState?.lastLockedRect ?? .zero)")
        
        // 윈도우가 완전히 사라졌는지 확인
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            print("✅ Overlay dismissed, isVisible=\(window.isVisible)")
        }
    }
}
