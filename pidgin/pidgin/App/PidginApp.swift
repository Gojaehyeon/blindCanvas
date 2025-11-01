//
//  PidginApp.swift
//  pidgin
//
//  Created by go on 11/1/25.
//

import SwiftUI
import KeyboardShortcuts

@main
struct PidginApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState()

    init() {
        // 최초 기본 단축키 지정 (사용자가 변경 가능)
        KeyboardShortcuts.setShortcut(.init(.one, modifiers: [.command, .shift]), for: .toggleOverlay)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .onAppear {
                    if let delegate = NSApp.delegate as? AppDelegate {
                        delegate.setAppState(appState)
                    }
                }
                // 전역 단축키: 키업 시 오버레이 토글
                .onReceive(KeyboardShortcuts.onKeyUpPublisher(for: .toggleOverlay)) { _ in
                    if appState.overlayVisible {
                        appDelegate.dismissOverlay()
                    } else {
                        appDelegate.presentOverlay()
                    }
                }
        }
        .windowStyle(.automatic)
    }
}
