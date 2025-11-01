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
                    // ContentView가 나타날 때 appState 연결
                    appDelegate.setAppState(appState)
                }
        }
        .windowStyle(.automatic)
    }
}
