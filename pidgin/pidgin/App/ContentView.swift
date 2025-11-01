//
//  ContentView.swift
//  pidgin
//
//  Created by go on 11/1/25.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var userText: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pidgin").font(.system(size: 22, weight: .bold))
            Text("⌘⇧1 또는 아래 버튼으로 오버레이를 열고, ESC로 닫을 수 있습니다.")
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Button {
                    (NSApp.delegate as? AppDelegate)?.toggleOverlay()
                } label: {
                    Label("영역 지정 (⌘⇧1)", systemImage: "cursorarrow.rays")
                }
                .keyboardShortcut("1", modifiers: [.command, .shift])

                Spacer()
            }

            Divider()

            Group {
                Text("상태: \(statusText)")
                Text("선택영역: \(formattedRect(appState.selectedRect))")
            }
            .font(.system(.caption, design: .monospaced))
            .foregroundStyle(.secondary)
        }
        .padding(16)
        .onAppear {
            (NSApp.delegate as? AppDelegate)?.setAppState(appState)
        }
        .frame(minWidth: 560, minHeight: 220)
    }

    private var statusText: String {
        switch appState.selectionState {
        case .idle: return "Idle"
        case .selecting: return "Selecting"
        case .locked: return "Locked"
        case .requesting: return "Requesting..."
        }
    }

    private func formattedRect(_ r: CGRect) -> String {
        String(format: "x:%.0f y:%.0f w:%.0f h:%.0f", r.origin.x, r.origin.y, r.size.width, r.size.height)
    }
}
