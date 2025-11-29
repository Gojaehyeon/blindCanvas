//
//  AnalysisService.swift
//  pidgin
//
//  Created by go on 11/1/25.
//

import Foundation
import AppKit

@MainActor
final class AnalysisService {
    static let shared = AnalysisService()
    
    private let captureService = ScreenCaptureService.shared
    private let gptClient = GPTClient.shared
    private let ttsService = TextToSpeechService.shared
    
    private init() {}
    
    /// 현재 진행 중인 분석 요청 취소
    func cancelCurrentAnalysis() {
        gptClient.cancelCurrentRequest()
    }
    
    /// 전맹 시각장애인을 위한 그림 해설 분석 (Enter 키로 호출)
    /// - Parameters:
    ///   - rect: 캡처할 화면 영역
    ///   - userText: 사용자가 입력한 그림 설명
    ///   - appState: 상태 업데이트용 AppState
    func analyzeRegionForBlindUser(
        _ rect: CGRect,
        userText: String,
        appState: AppState
    ) async {
        // 오버레이가 보이는 상태인지 확인
        guard appState.overlayVisible else {
            return
        }
        
        // TTS 설정 업데이트 (분석 시작 전에 미리 설정)
        ttsService.updateSettings(rate: appState.ttsRate, voiceGender: appState.ttsVoiceGender, provider: appState.ttsProvider, voiceIdentifier: appState.ttsVoiceIdentifier)
        
        // 1. 상태를 requesting로 변경
        appState.selectionState = .requesting
        appState.analysisMode = nil
        appState.errorMessage = nil
        
        do {
            // 2. 화면 캡처
            guard let image = try await captureService.captureRegion(rect) else {
                throw AnalysisError.captureFailed
            }
            
            // 오버레이가 여전히 보이는지 다시 확인 (캡처 후)
            guard appState.overlayVisible else {
                appState.selectionState = .locked
                return
            }
            
            // 3. 프롬프트 생성 (전맹 시각장애인용)
            let prompt = PromptBuilder.blindUserPrompt(userText: userText)
            
            // 4. GPT 분석 요청
            let response = try await gptClient.analyzeImage(image, withPrompt: prompt)
            
            // 오버레이가 여전히 보이는지 다시 확인 (GPT 응답 후)
            guard appState.overlayVisible else {
                appState.selectionState = .locked
                return
            }
            
            // 5. 응답 저장
            appState.analysisResponse = response
            
            // 6. TTS 재생 시작 (재생이 실제로 시작될 때까지 requesting 상태 유지)
            ttsService.speak(text: response, onStarted: {
                Task { @MainActor in
                    // 재생이 시작되면 requesting 상태 해제
                    appState.selectionState = .locked
                    appState.isTTSPlaying = true
                }
            }) {
                Task { @MainActor in
                    // 오버레이가 여전히 보이는지 확인 후 상태 업데이트
                    appState.isTTSPlaying = false
                    if appState.overlayVisible {
                        appState.selectionState = .locked
                    }
                }
            }
            
        } catch {
            // 에러 처리 (취소된 경우는 에러 메시지 표시 안 함)
            if case GPTError.requestCancelled = error {
                // 취소된 경우는 상태만 리셋
                if appState.overlayVisible {
                    appState.selectionState = .locked
                }
                appState.isTTSPlaying = false
            } else {
                appState.errorMessage = error.localizedDescription
                if appState.overlayVisible {
                    appState.selectionState = .locked
                }
                appState.isTTSPlaying = false
            }
        }
    }
}

enum AnalysisError: Error, LocalizedError {
    case captureFailed
    
    var errorDescription: String? {
        switch self {
        case .captureFailed:
            return "화면 캡처에 실패했습니다."
        }
    }
}

