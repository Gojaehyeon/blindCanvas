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
    @Published var ttsVoiceGender: VoiceGender = .male  // 기본값: 남성 (하위 호환성)
    @Published var ttsProvider: TTSProvider = .apple  // 기본값: Apple TTS
    @Published var ttsVoiceIdentifier: String = ""  // 선택된 음성 ID (빈 문자열이면 Yuna 기본값)
    
    // 사용자 입력 텍스트 (그림 설명용)
    @Published var userText: String = ""
    
    // 사용 가능한 Apple TTS 음성 목록 (Yuna, Eddy만)
    static var availableAppleVoices: [AVSpeechSynthesisVoice] {
        let allVoices = AVSpeechSynthesisVoice.speechVoices()
        
        // Yuna와 Eddy만 찾기
        var voices: [AVSpeechSynthesisVoice] = []
        
        if let yuna = allVoices.first(where: { $0.name.localizedCaseInsensitiveContains("Yuna") }) {
            voices.append(yuna)
        }
        
        if let eddy = allVoices.first(where: { $0.name.localizedCaseInsensitiveContains("Eddy") }) {
            voices.append(eddy)
        }
        
        return voices
    }
    
    enum TTSProvider {
        case openAI    // OpenAI TTS (더 자연스러운 음성)
        case apple     // Apple TTS (더 빠른 응답)
    }
    
    enum VoiceGender {
        case male
        case female
        
        func preferredVoice() -> AVSpeechSynthesisVoice? {
            // 이 메서드는 하위 호환성을 위해 유지하지만, 실제로는 ttsVoiceIdentifier를 사용
            return nil
        }
    }
    
    /// 선택된 음성 반환 (Apple TTS용)
    func selectedAppleVoice() -> AVSpeechSynthesisVoice? {
        // ttsVoiceIdentifier가 설정되어 있으면 해당 음성 사용
        if !ttsVoiceIdentifier.isEmpty {
            if let voice = AVSpeechSynthesisVoice(identifier: ttsVoiceIdentifier) {
                return voice
            }
        }
        
        // 기본값: Yuna (ttsVoiceIdentifier가 비어있을 때)
        let availableVoices = AppState.availableAppleVoices
        return availableVoices.first(where: { $0.name.localizedCaseInsensitiveContains("Yuna") })
            ?? availableVoices.first
            ?? AVSpeechSynthesisVoice(language: "ko-KR")
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
