//
//  AppState.swift
//  pidgin
//
//  Created by go on 11/1/25.
//

import Foundation
import CoreGraphics
import AppKit
import Combine
import AVFoundation

@MainActor
final class AppState: ObservableObject {
    enum SelectionState { 
        case idle
        case selecting
        case locked
        case requesting  // AI 분석 요청 중
    }
    
    enum AnalysisMode {
        case poetic      // 시적 해석
        case structural  // 구조적 해석
    }
    
    @Published var selectionState: SelectionState = .idle
    @Published var selectedRect: CGRect = .zero
    @Published var overlayVisible: Bool = false
    @Published var analysisMode: AnalysisMode? = nil
    @Published var analysisResponse: String? = nil
    @Published var isTTSPlaying: Bool = false
    @Published var errorMessage: String? = nil
    
    // 마지막으로 Lock된 영역 저장
    @Published var lastLockedRect: CGRect = .zero
    
    // TTS 설정
    @Published var ttsRate: Float = 0.5  // 0.0 ~ 1.0, 기본값 0.5
    @Published var ttsVoiceGender: VoiceGender = .male  // 기본값: 남성
    
    // 사용자 입력 텍스트 (그림 설명용)
    @Published var userText: String = ""
    
    enum VoiceGender {
        case male
        case female
        
        func preferredVoice() -> AVSpeechSynthesisVoice? {
            // 한국어 음성 중에서 성별에 맞는 음성 선택
            let allVoices = AVSpeechSynthesisVoice.speechVoices()
            let koreanVoices = allVoices.filter { $0.language == "ko-KR" }
            
            if self == .female {
                // 여성 음성: gender 속성 우선, 없으면 이름으로 추정
                let femaleVoice = koreanVoices.first { voice in
                    voice.gender == .female || 
                    voice.name.localizedCaseInsensitiveContains("Yuna") ||
                    voice.name.localizedCaseInsensitiveContains("Sora") ||
                    voice.name.localizedCaseInsensitiveContains("Nara") ||
                    voice.name.localizedCaseInsensitiveContains("Yeri")
                }
                if let voice = femaleVoice {
                    return voice
                }
            } else {
                // 남성 음성: gender 속성 우선, 없으면 이름으로 추정
                let maleVoice = koreanVoices.first { voice in
                    voice.gender == .male ||
                    voice.name.localizedCaseInsensitiveContains("Eddy") ||
                    voice.name.localizedCaseInsensitiveContains("Yunjae") ||
                    voice.name.localizedCaseInsensitiveContains("Yunja") ||
                    voice.name.localizedCaseInsensitiveContains("Injoon") ||
                    voice.name.localizedCaseInsensitiveContains("Injun") ||
                    voice.name.localizedCaseInsensitiveContains("Flo")
                }
                if let voice = maleVoice {
                    return voice
                }
            }
            
            // 기본 한국어 음성 (성별 구분 없이 첫 번째)
            let defaultVoice = koreanVoices.first ?? AVSpeechSynthesisVoice(language: "ko-KR")
            return defaultVoice
        }
    }
    
    var isLocked: Bool { selectionState == .locked }
    var isRequesting: Bool { selectionState == .requesting }
    
    func reset() {
        let preservedRect = lastLockedRect
        selectionState = .idle
        selectedRect = .zero
        analysisMode = nil
        analysisResponse = nil
        errorMessage = nil
        // lastLockedRect는 유지 (다음에 재사용)
        lastLockedRect = preservedRect
    }
    
    func resetToNewSelection() {
        // 새로 그리기 모드: 모든 것을 리셋
        reset()
        lastLockedRect = .zero
    }
}
