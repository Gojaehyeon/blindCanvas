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
    
    private let apiKey: String
    private let baseURL = URL(string: "https://api.openai.com/v1/audio/speech")!
    private var currentPlayer: AVPlayer?
    private var currentPlayerItem: AVPlayerItem?
    private var currentTempURL: URL?
    private var currentCompletion: (() -> Void)?
    private var onPlaybackStarted: (() -> Void)?
    
    // 설정 (AppState에서 주입받음)
    var rate: Float = 0.5  // 0.0 ~ 1.0, OpenAI는 0.25 ~ 4.0이므로 변환 필요
    var voiceGender: AppState.VoiceGender = .female
    
    // OpenAI TTS 음성 옵션
    enum OpenAIVoice: String {
        case alloy = "alloy"
        case echo = "echo"
        case fable = "fable"
        case onyx = "onyx"
        case nova = "nova"      // 한국어에 적합
        case shimmer = "shimmer" // 한국어에 적합
    }
    
    override init() {
        self.apiKey = Secrets.openAIKey
        super.init()
        
        // AVPlayer 재생 완료 알림 설정
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerDidFinishPlaying),
            name: .AVPlayerItemDidPlayToEndTime,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        
        // deinit에서는 @MainActor 메서드를 호출할 수 없으므로 직접 정리
        currentPlayer?.pause()
        
        // Observer 제거
        if let playerItem = currentPlayerItem {
            playerItem.removeObserver(self, forKeyPath: "status")
        }
        
        // 임시 파일 정리
        if let tempURL = currentTempURL {
            try? FileManager.default.removeItem(at: tempURL)
        }
        
        currentPlayer = nil
        currentPlayerItem = nil
        currentTempURL = nil
        currentCompletion = nil
    }
    
    /// 설정 업데이트
    func updateSettings(rate: Float, voiceGender: AppState.VoiceGender) {
        self.rate = rate
        self.voiceGender = voiceGender
    }
    
    /// OpenAI rate를 변환 (0.0~1.0 -> 0.5~1.5)
    private func convertRate(_ rate: Float) -> Float {
        // 0.0 -> 0.5 (느림), 0.5 -> 1.0 (보통), 1.0 -> 1.5 (빠름)
        // OpenAI speed 범위는 0.25~4.0이지만, 더 자연스러운 범위로 제한
        return 0.5 + (rate * 1.0)
    }
    
    /// 성별에 맞는 OpenAI 음성 선택
    private func selectedVoice() -> OpenAIVoice {
        switch voiceGender {
        case .female:
            return .nova  // 한국어 여성 음성에 적합
        case .male:
            return .onyx  // 한국어 남성 음성에 적합
        }
    }
    
    /// 텍스트를 음성으로 재생
    /// - Parameters:
    ///   - text: 재생할 텍스트
    ///   - onStarted: 재생 시작 콜백 (실제로 재생이 시작될 때 호출)
    ///   - completion: 재생 완료 콜백
    func speak(
        text: String,
        onStarted: (() -> Void)? = nil,
        completion: (() -> Void)? = nil
    ) {
        // 기존 재생 중지
        stop()
        
        currentCompletion = completion
        onPlaybackStarted = onStarted
        
        // OpenAI TTS API 호출 (비동기로 실행하되 즉시 시작)
        Task { @MainActor in
            do {
                let audioData = try await generateSpeech(text: text)
                await playAudio(data: audioData)
            } catch {
                print("TTS 오류: \(error.localizedDescription)")
                // 에러 발생 시 completion 호출
                currentCompletion?()
                currentCompletion = nil
                onPlaybackStarted = nil
            }
        }
    }
    
    /// OpenAI TTS API를 사용하여 음성 생성
    private func generateSpeech(text: String) async throws -> Data {
        let requestBody: [String: Any] = [
            "model": "tts-1-hd",  // 고품질 모델
            "input": text,
            "voice": selectedVoice().rawValue,
            "speed": convertRate(rate)
        ]
        
        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30.0
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TTSError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = errorData["error"] as? [String: Any],
               let message = error["message"] as? String {
                throw TTSError.apiError(message)
            }
            throw TTSError.httpError(httpResponse.statusCode)
        }
        
        return data
    }
    
    /// 오디오 데이터 재생
    private func playAudio(data: Data) async {
        // 임시 파일에 저장
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp3")
        
        do {
            try data.write(to: tempURL)
            currentTempURL = tempURL
            
            let playerItem = AVPlayerItem(url: tempURL)
            let player = AVPlayer(playerItem: playerItem)
            
            currentPlayer = player
            currentPlayerItem = playerItem
            
            // 재생 완료 후 임시 파일 삭제
            playerItem.addObserver(self, forKeyPath: "status", options: [.new], context: nil)
            
            // 재생 시작을 기다림 (status가 readyToPlay가 될 때까지)
            await waitForPlayerReady(playerItem: playerItem)
            
            // 재생 시작
            player.play()
            
            // 재생이 시작되었음을 알림
            onPlaybackStarted?()
            onPlaybackStarted = nil
            
        } catch {
            print("오디오 재생 오류: \(error.localizedDescription)")
            currentCompletion?()
            currentCompletion = nil
        }
    }
    
    /// AVPlayerItem이 재생 준비될 때까지 대기
    private func waitForPlayerReady(playerItem: AVPlayerItem) async {
        if playerItem.status == .readyToPlay {
            return
        }
        
        // status 변경을 기다림
        await withCheckedContinuation { continuation in
            var observation: NSKeyValueObservation?
            observation = playerItem.observe(\.status, options: [.new]) { item, _ in
                if item.status == .readyToPlay || item.status == .failed {
                    observation?.invalidate()
                    continuation.resume()
                }
            }
        }
    }
    
    /// AVPlayerItem 상태 관찰
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "status" {
            if let playerItem = object as? AVPlayerItem {
                if playerItem.status == .readyToPlay {
                    // 재생 준비 완료
                } else if playerItem.status == .failed {
                    // 재생 실패
                    currentCompletion?()
                    currentCompletion = nil
                    currentPlayer = nil
                }
            }
        }
    }
    
    /// 재생 완료 알림
    @objc private func playerDidFinishPlaying() {
        // 임시 파일 정리
        if let tempURL = currentTempURL {
            try? FileManager.default.removeItem(at: tempURL)
            currentTempURL = nil
        }
        
        // Observer 제거
        if let playerItem = currentPlayerItem {
            playerItem.removeObserver(self, forKeyPath: "status")
            currentPlayerItem = nil
        }
        
        currentCompletion?()
        currentCompletion = nil
        currentPlayer = nil
    }
    
    /// 음성 재생 중지
    func stop() {
        currentPlayer?.pause()
        
        // Observer 제거
        if let playerItem = currentPlayerItem {
            playerItem.removeObserver(self, forKeyPath: "status")
            currentPlayerItem = nil
        }
        
        // 임시 파일 정리
        if let tempURL = currentTempURL {
            try? FileManager.default.removeItem(at: tempURL)
            currentTempURL = nil
        }
        
        currentCompletion = nil
        currentPlayer = nil
    }
    
    var isSpeaking: Bool {
        return currentPlayer?.rate ?? 0 > 0
    }
}

// MARK: - Errors

enum TTSError: Error, LocalizedError {
    case invalidResponse
    case httpError(Int)
    case apiError(String)
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "잘못된 응답을 받았습니다."
        case .httpError(let code):
            return "HTTP 오류: \(code)"
        case .apiError(let message):
            return "API 오류: \(message)"
        case .networkError(let error):
            return "네트워크 오류: \(error.localizedDescription)"
        }
    }
}

