//
//  ContentView.swift
//  pidgin
//
//  Created by go on 11/1/25.
//

import SwiftUI
import AVFAudio

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pidgin").font(.system(size: 22, weight: .bold))
            Text("⌘⇧1: 새로 그리기, ⌘⇧2: 저장된 영역으로 열기")
                .foregroundStyle(.secondary)

            Divider()
            
            // 사용자 입력 텍스트
            Group {
                Text("그림 설명").font(.system(size: 14, weight: .semibold))
                TextField("그리는 내용을 입력하세요 (예: 고양이, 풍경 등)", text: $appState.userText)
                    .textFieldStyle(.roundedBorder)
            }
            .padding(.vertical, 8)

            Divider()
            
            // TTS 설정
            Group {
                Text("TTS 설정").font(.system(size: 14, weight: .semibold))
                
                VStack(alignment: .leading, spacing: 8) {
                    // TTS 제공자 선택
                    VStack(alignment: .leading, spacing: 4) {
                        Text("TTS 제공자")
                            .font(.system(.caption))
                        Picker("", selection: $appState.ttsProvider) {
                            Text("OpenAI TTS").tag(AppState.TTSProvider.openAI)
                            Text("Apple TTS").tag(AppState.TTSProvider.apple)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 200)
                        .onChange(of: appState.ttsProvider) { newValue in
                            TextToSpeechService.shared.updateSettings(
                                rate: appState.ttsRate,
                                voiceGender: appState.ttsVoiceGender,
                                provider: newValue,
                                voiceIdentifier: appState.ttsVoiceIdentifier
                            )
                        }
                    }
                    
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
                                        voiceGender: appState.ttsVoiceGender,
                                        provider: appState.ttsProvider,
                                        voiceIdentifier: appState.ttsVoiceIdentifier
                                    )
                                }
                        }
                        
                        // Apple TTS일 때만 음성 선택 표시
                        if appState.ttsProvider == .apple {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("음성 선택")
                                    .font(.system(.caption))
                                Picker("", selection: $appState.ttsVoiceIdentifier) {
                                    Text("Yuna (기본)").tag("")
                                    ForEach(AppState.availableAppleVoices, id: \.identifier) { voice in
                                        Text(voice.name).tag(voice.identifier)
                                    }
                                }
                                .pickerStyle(.menu)
                                .frame(width: 200)
                                .onChange(of: appState.ttsVoiceIdentifier) { newValue in
                                    TextToSpeechService.shared.updateSettings(
                                        rate: appState.ttsRate,
                                        voiceGender: appState.ttsVoiceGender,
                                        provider: appState.ttsProvider,
                                        voiceIdentifier: newValue
                                    )
                                }
                            }
                        } else {
                            // OpenAI TTS일 때는 성별만 선택
                            VStack(alignment: .leading, spacing: 4) {
                                Text("음성 종류")
                                    .font(.system(.caption))
                                Picker("", selection: $appState.ttsVoiceGender) {
                                    Text("여성").tag(AppState.VoiceGender.female)
                                    Text("남성").tag(AppState.VoiceGender.male)
                                }
                                .pickerStyle(.segmented)
                                .frame(width: 120)
                                .onChange(of: appState.ttsVoiceGender) { newValue in
                                    TextToSpeechService.shared.updateSettings(
                                        rate: appState.ttsRate,
                                        voiceGender: newValue,
                                        provider: appState.ttsProvider,
                                        voiceIdentifier: appState.ttsVoiceIdentifier
                                    )
                                }
                            }
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
