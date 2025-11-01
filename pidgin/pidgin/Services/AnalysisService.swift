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
        // 1. 상태를 requesting로 변경
        appState.selectionState = .requesting
        appState.analysisMode = mode
        appState.errorMessage = nil
        
        do {
            // 2. 화면 캡처
            guard let image = try await captureService.captureRegion(rect) else {
                throw AnalysisError.captureFailed
            }
            
            // 3. 프롬프트 생성
            let prompt = PromptBuilder.prompt(for: mode)
            
            // 4. GPT 분석 요청
            let response = try await gptClient.analyzeImage(image, withPrompt: prompt)
            
            // 5. 응답 저장
            appState.analysisResponse = response
            
            // 6. TTS 재생 시작
            appState.isTTSPlaying = true
            ttsService.speak(text: response) {
                Task { @MainActor in
                    appState.isTTSPlaying = false
                    // TTS 재생 완료 후 locked 상태로 복귀
                    appState.selectionState = .locked
                }
            }
            
        } catch {
            // 에러 처리
            appState.errorMessage = error.localizedDescription
            appState.selectionState = .locked
            appState.isTTSPlaying = false
            
            print("❌ Analysis error: \(error)")
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

