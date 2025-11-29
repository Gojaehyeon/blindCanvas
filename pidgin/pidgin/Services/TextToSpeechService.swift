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
    var provider: AppState.TTSProvider = .openAI
    var voiceIdentifier: String = ""  // 선택된 음성 ID (Apple TTS용)
    
    // Apple TTS용
    private let synthesizer = AVSpeechSynthesizer()
    
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
        synthesizer.delegate = self
        
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
    func updateSettings(rate: Float, voiceGender: AppState.VoiceGender, provider: AppState.TTSProvider, voiceIdentifier: String = "") {
        self.rate = rate
        self.voiceGender = voiceGender
        self.provider = provider
        self.voiceIdentifier = voiceIdentifier
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
        
        // 제공자에 따라 다른 TTS 사용
        switch provider {
        case .openAI:
            // OpenAI TTS API 호출 (비동기로 실행하되 즉시 시작)
            Task { @MainActor in
                let startTime = Date()
                do {
                    print("🎤 GPT TTS 시작: \(text.prefix(50))...")
                    let apiStartTime = Date()
                    let audioData = try await generateSpeech(text: text)
                    let apiTime = Date().timeIntervalSince(apiStartTime)
                    print("⏱️ API 호출 완료: \(String(format: "%.2f", apiTime))초, 데이터 크기: \(audioData.count) bytes")
                    
                    let playStartTime = Date()
                    await playAudio(data: audioData)
                    let playTime = Date().timeIntervalSince(playStartTime)
                    print("⏱️ 재생 시작 완료: \(String(format: "%.2f", playTime))초")
                    
                    let totalTime = Date().timeIntervalSince(startTime)
                    print("⏱️ 총 소요 시간: \(String(format: "%.2f", totalTime))초")
                } catch {
                    print("❌ TTS 오류: \(error.localizedDescription)")
                    // 에러 발생 시 completion 호출
                    currentCompletion?()
                    currentCompletion = nil
                    onPlaybackStarted = nil
                }
            }
        case .apple:
            // Apple TTS 사용 (즉시 재생)
            speakWithAppleTTS(text: text)
        }
    }
    
    /// Apple TTS로 재생
    private func speakWithAppleTTS(text: String) {
        let utterance = AVSpeechUtterance(string: text)
        
        // 선택된 음성 ID가 있으면 해당 음성 사용
        let selectedVoice: AVSpeechSynthesisVoice?
        if !voiceIdentifier.isEmpty {
            selectedVoice = AVSpeechSynthesisVoice(identifier: voiceIdentifier)
        } else {
            // 기본값: Yuna
            let allVoices = AVSpeechSynthesisVoice.speechVoices()
            selectedVoice = allVoices.first { $0.name.localizedCaseInsensitiveContains("Yuna") }
        }
        
        utterance.voice = selectedVoice 
            ?? AVSpeechSynthesisVoice(language: "ko-KR")
            ?? AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = rate
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        
        // 재생 시작 알림
        onPlaybackStarted?()
        onPlaybackStarted = nil
        
        synthesizer.speak(utterance)
    }
    
    /// OpenAI TTS API를 사용하여 음성 생성
    private func generateSpeech(text: String) async throws -> Data {
        let requestBody: [String: Any] = [
            "model": "tts-1",  // 빠른 모델 (tts-1-hd보다 훨씬 빠름)
            "input": text,
            "voice": selectedVoice().rawValue,
            "speed": convertRate(rate)
        ]
        
        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15.0  // 타임아웃 줄임
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        // 최적화된 URLSession 사용 (캐시 비활성화, 빠른 연결)
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15.0
        config.timeoutIntervalForResource = 15.0
        config.urlCache = nil
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        let session = URLSession(configuration: config)
        
        let (data, response) = try await session.data(for: request)
        
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
        let playStartTime = Date()
        
        // 임시 파일에 저장
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp3")
        
        do {
            // 파일 저장
            let writeStartTime = Date()
            try data.write(to: tempURL)
            let writeTime = Date().timeIntervalSince(writeStartTime)
            print("⏱️ 파일 저장: \(String(format: "%.2f", writeTime))초")
            
            currentTempURL = tempURL
            
            // AVPlayerItem 생성
            let createStartTime = Date()
            let playerItem = AVPlayerItem(url: tempURL)
            let player = AVPlayer(playerItem: playerItem)
            
            currentPlayer = player
            currentPlayerItem = playerItem
            
            // Observer 추가
            playerItem.addObserver(self, forKeyPath: "status", options: [.new], context: nil)
            
            let createTime = Date().timeIntervalSince(createStartTime)
            print("⏱️ Player 생성: \(String(format: "%.2f", createTime))초")
            
            // 재생 시작 알림을 즉시 호출
            onPlaybackStarted?()
            onPlaybackStarted = nil
            
            // 재생 시작 (준비를 기다리지 않고 즉시)
            player.play()
            
            let totalPlayTime = Date().timeIntervalSince(playStartTime)
            print("⏱️ 재생 시작까지: \(String(format: "%.2f", totalPlayTime))초")
            
        } catch {
            print("❌ 오디오 재생 오류: \(error.localizedDescription)")
            currentCompletion?()
            currentCompletion = nil
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
        
        // Apple TTS 중지
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        
        currentCompletion = nil
        onPlaybackStarted = nil
        currentPlayer = nil
    }
    
    var isSpeaking: Bool {
        switch provider {
        case .openAI:
            return currentPlayer?.rate ?? 0 > 0
        case .apple:
            return synthesizer.isSpeaking
        }
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

