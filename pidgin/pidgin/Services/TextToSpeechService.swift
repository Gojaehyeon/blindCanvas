//
//  TextToSpeechService.swift
//  pidgin
//
//  Created by go on 11/1/25.
//

import AVFoundation
import Foundation

@MainActor
final class TextToSpeechService: NSObject {
    static let shared = TextToSpeechService()
    
    private let synthesizer = AVSpeechSynthesizer()
    private var currentCompletion: (() -> Void)?
    
    override init() {
        super.init()
        synthesizer.delegate = self
    }
    
    /// 텍스트를 음성으로 재생
    /// - Parameters:
    ///   - text: 재생할 텍스트
    ///   - voice: 음성 종류 (nil이면 시스템 기본값)
    ///   - rate: 말하는 속도 (0.0 ~ 1.0, 기본값 0.5)
    ///   - pitch: 음성 피치 (0.5 ~ 2.0, 기본값 1.0)
    ///   - completion: 재생 완료 콜백
    func speak(
        text: String,
        voice: AVSpeechSynthesisVoice? = nil,
        rate: Float = 0.5,
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
            // 한국어 음성 우선 선택
            utterance.voice = AVSpeechSynthesisVoice(language: "ko-KR") 
                ?? AVSpeechSynthesisVoice(language: "en-US")
        }
        
        utterance.rate = rate
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

