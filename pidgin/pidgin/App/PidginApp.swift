//
//  PidginApp.swift
//  pidgin
//
//  Created by go on 11/1/25.
//

import SwiftUI

@main
struct PidginApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .onAppear {
                    (NSApp.delegate as? AppDelegate)?.setAppState(appState)
                }
        }
        .windowStyle(.automatic)
    }
}
