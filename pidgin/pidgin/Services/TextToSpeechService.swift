//
//  TextToSpeechService.swift
//  pidgin
//
//  Created by go on 11/1/25.
//

import AVFoundation
import Foundation
import AppKit

@MainActor
final class TextToSpeechService: NSObject {
    static let shared = TextToSpeechService()
    
    private let synthesizer = AVSpeechSynthesizer()
    private var currentCompletion: (() -> Void)?
    
    // 설정 (AppState에서 주입받음)
    var rate: Float = 0.5
    var voiceGender: AppState.VoiceGender = .female
    
    override init() {
        super.init()
        synthesizer.delegate = self
    }
    
    /// 설정 업데이트
    func updateSettings(rate: Float, voiceGender: AppState.VoiceGender) {
        self.rate = rate
        self.voiceGender = voiceGender
    }
    
    /// 텍스트를 음성으로 재생
    /// - Parameters:
    ///   - text: 재생할 텍스트
    ///   - completion: 재생 완료 콜백
    func speak(
        text: String,
        completion: (() -> Void)? = nil
    ) {
        // 기존 재생 중지
        stop()
        
        currentCompletion = completion
        
        let utterance = AVSpeechUtterance(string: text)
        
        // 설정된 성별에 맞는 음성 선택
        let selectedVoice = voiceGender.preferredVoice() 
            ?? AVSpeechSynthesisVoice(language: "ko-KR")
            ?? AVSpeechSynthesisVoice(language: "en-US")
        
        utterance.voice = selectedVoice
        utterance.rate = rate
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        
        synthesizer.speak(utterance)
    }
    
    /// 텍스트를 음성으로 재생 (커스텀 파라미터)
    /// - Parameters:
    ///   - text: 재생할 텍스트
    ///   - voice: 음성 종류 (nil이면 설정된 기본값 사용)
    ///   - rate: 말하는 속도 (nil이면 설정된 기본값 사용)
    ///   - pitch: 음성 피치 (0.5 ~ 2.0, 기본값 1.0)
    ///   - completion: 재생 완료 콜백
    func speak(
        text: String,
        voice: AVSpeechSynthesisVoice? = nil,
        rate: Float? = nil,
        pitch: Float = 1.0,
        completion: (() -> Void)? = nil
    ) {
        // 기존 재생 중지
        stop()
        
        currentCompletion = completion
        
        let utterance = AVSpeechUtterance(string: text)
        
        // 음성 설정
        if let voice = voice {
            utterance.voice = voice
        } else {
            utterance.voice = voiceGender.preferredVoice() 
                ?? AVSpeechSynthesisVoice(language: "ko-KR")
                ?? AVSpeechSynthesisVoice(language: "en-US")
        }
        
        utterance.rate = rate ?? self.rate
        utterance.pitchMultiplier = pitch
        utterance.volume = 1.0
        
        synthesizer.speak(utterance)
    }
    
    /// 음성 재생 중지
    func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        currentCompletion = nil
    }
    
    var isSpeaking: Bool {
        synthesizer.isSpeaking
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension TextToSpeechService: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        Task { @MainActor in
            currentCompletion?()
            currentCompletion = nil
        }
    }
    
    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didCancel utterance: AVSpeechUtterance
    ) {
        Task { @MainActor in
            currentCompletion?()
            currentCompletion = nil
        }
    }
}

