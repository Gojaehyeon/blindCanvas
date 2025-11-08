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
    
    /// 전체 분석 파이프라인 실행: 캡처 → GPT 분석 → TTS 재생
    /// - Parameters:
    ///   - rect: 캡처할 화면 영역
    ///   - mode: 분석 모드 (시적/구조적)
    ///   - appState: 상태 업데이트용 AppState
    func analyzeRegion(
        _ rect: CGRect,
        mode: AppState.AnalysisMode,
        appState: AppState
    ) async {
        // 오버레이가 보이는 상태인지 확인
        guard appState.overlayVisible else {
            return
        }
        
        // TTS 설정 업데이트 (분석 시작 전에 미리 설정)
        ttsService.updateSettings(rate: appState.ttsRate, voiceGender: appState.ttsVoiceGender)
        
        // 1. 상태를 requesting로 변경
        appState.selectionState = .requesting
        appState.analysisMode = mode
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
            
            // 3. 프롬프트 생성
            let prompt = PromptBuilder.prompt(for: mode)
            
            // 4. GPT 분석 요청
            let response = try await gptClient.analyzeImage(image, withPrompt: prompt)
            
            // 오버레이가 여전히 보이는지 다시 확인 (GPT 응답 후)
            guard appState.overlayVisible else {
                appState.selectionState = .locked
                return
            }
            
            // 5. 응답 저장
            appState.analysisResponse = response
            
            // 6. requesting 상태를 먼저 해제하고 TTS 재생 시작
            appState.selectionState = .locked
            appState.isTTSPlaying = true
            
            // TTS 설정 적용하여 재생
            ttsService.speak(text: response) {
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

