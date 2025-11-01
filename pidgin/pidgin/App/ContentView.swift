//
//  ContentView.swift
//  pidgin
//
//  Created by go on 11/1/25.
//

import SwiftUI
import KeyboardShortcuts

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var userText: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pidgin").font(.system(size: 22, weight: .bold))

            HStack(spacing: 8) {
                Button {
                    KeyboardShortcuts.trigger(.toggleOverlay)   // ← 오버레이 호출
                } label: {
                    Label("영역 지정", systemImage: "cursorarrow.rays")
                }
                .keyboardShortcut("1", modifiers: [.command, .shift]) // 보조(로컬)
                .help("⌘⇧1")

                Spacer()
            }

            // (나머지 기존 UI 유지)
            // ...
        }
        .padding(16)
        .frame(minWidth: 560, minHeight: 220)
    }
}
