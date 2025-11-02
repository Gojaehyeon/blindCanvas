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
            Text("⌘⇧1: 새로 그리기, ⌘⇧2: 저장된 영역으로 열기")
                .foregroundStyle(.secondary)

            Divider()
            
            // TTS 설정
            Group {
                Text("TTS 설정").font(.system(size: 14, weight: .semibold))
                
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("재생 속도: \(String(format: "%.1f", appState.ttsRate))")
                            .font(.system(.caption))
                        Slider(value: $appState.ttsRate, in: 0.0...1.0, step: 0.1)
                            .frame(width: 200)
                            .onChange(of: appState.ttsRate) { newValue in
                                // 설정 변경 시 즉시 반영
                                TextToSpeechService.shared.updateSettings(
                                    rate: newValue,
                                    voiceGender: appState.ttsVoiceGender
                                )
                            }
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("음성 종류")
                            .font(.system(.caption))
                        Picker("", selection: $appState.ttsVoiceGender) {
                            Text("음성 1").tag(AppState.VoiceGender.female)
                            Text("음성 2").tag(AppState.VoiceGender.male)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 120)
                        .onChange(of: appState.ttsVoiceGender) { newValue in
                            // 설정 변경 시 즉시 반영
                            TextToSpeechService.shared.updateSettings(
                                rate: appState.ttsRate,
                                voiceGender: newValue
                            )
                        }
                    }
                }
            }
            .padding(.vertical, 8)

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
