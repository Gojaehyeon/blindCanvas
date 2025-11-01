//
//  GPTClient.swift
//  pidgin
//
//  Created by go on 11/1/25.
//

import Foundation
import AppKit

final class GPTClient {
    static let shared = GPTClient()
    
    private let apiKey: String
    private let baseURL = URL(string: "https://api.openai.com/v1/chat/completions")!
    
    private init() {
        self.apiKey = Secrets.openAIKey
    }
    
    /// 이미지와 텍스트를 GPT-4o에 전송하여 분석 결과를 받아옴
    /// - Parameters:
    ///   - image: 분석할 이미지
    ///   - prompt: 텍스트 프롬프트
    /// - Returns: GPT 응답 텍스트
    func analyzeImage(_ image: NSImage, withPrompt prompt: String) async throws -> String {
        // 이미지를 Base64로 인코딩
        guard let imageData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: imageData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            throw GPTError.imageEncodingFailed
        }
        
        let base64Image = pngData.base64EncodedString()
        
        // 요청 본문 구성
        let requestBody: [String: Any] = [
            "model": "gpt-4o",
            "messages": [
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "text",
                            "text": prompt
                        ],
                        [
                            "type": "image_url",
                            "image_url": [
                                "url": "data:image/png;base64,\(base64Image)"
                            ]
                        ]
                    ]
                ]
            ],
            "max_tokens": 1000
        ]
        
        // HTTP 요청 생성
        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        // 네트워크 요청 실행
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // 응답 확인
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GPTError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = errorData["error"] as? [String: Any],
               let message = error["message"] as? String {
                throw GPTError.apiError(message)
            }
            throw GPTError.httpError(httpResponse.statusCode)
        }
        
        // JSON 파싱
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw GPTError.invalidResponse
        }
        
        return content
    }
}

// MARK: - Errors

enum GPTError: Error, LocalizedError {
    case imageEncodingFailed
    case invalidResponse
    case httpError(Int)
    case apiError(String)
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .imageEncodingFailed:
            return "이미지 인코딩에 실패했습니다."
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

