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
    private var currentTask: URLSessionDataTask?
    
    // 타임아웃 설정 (60초)
    private let timeoutInterval: TimeInterval = 60.0
    
    private init() {
        self.apiKey = Secrets.openAIKey
    }
    
    /// 현재 진행 중인 요청 취소
    func cancelCurrentRequest() {
        currentTask?.cancel()
        currentTask = nil
    }
    
    /// 이미지와 텍스트를 GPT-4o에 전송하여 분석 결과를 받아옴
    /// - Parameters:
    ///   - image: 분석할 이미지
    ///   - prompt: 텍스트 프롬프트
    ///   - model: 사용할 모델 (기본값: gpt-4o-mini, 더 빠르고 저렴함)
    /// - Returns: GPT 응답 텍스트
    func analyzeImage(_ image: NSImage, withPrompt prompt: String, model: String = "gpt-4.1-mini") async throws -> String {
        // 이미지 최적화: 최대 크기 제한 (긴 변 기준 512px) 및 압축
        let optimizedImage = optimizeImage(image, maxDimension: 512)
        
        // 이미지를 Base64로 인코딩 (JPEG로 압축하여 더 작게)
        guard let imageData = optimizedImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: imageData),
              let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.7]) else {
            throw GPTError.imageEncodingFailed
        }
        
        let base64Image = jpegData.base64EncodedString()
        
        // 요청 본문 구성
        let requestBody: [String: Any] = [
            "model": model,
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
                                "url": "data:image/jpeg;base64,\(base64Image)",
                                "detail": "low"  // 이미지 해상도 낮춰서 더 빠르게 처리
                            ]
                        ]
                    ]
                ]
            ],
            "max_tokens": 200  // 프롬프트에서 120토큰 이내 요청하므로 200으로 충분
        ]
        
        // HTTP 요청 생성 (타임아웃 설정)
        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = timeoutInterval
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        // 네트워크 요청 실행 (취소 가능하도록)
        let (data, response): (Data, URLResponse) = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<(Data, URLResponse), Error>) in
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    if (error as NSError).code == NSURLErrorCancelled {
                        continuation.resume(throwing: GPTError.requestCancelled)
                    } else {
                        continuation.resume(throwing: GPTError.networkError(error))
                    }
                    return
                }
                
                guard let data = data, let response = response else {
                    continuation.resume(throwing: GPTError.invalidResponse)
                    return
                }
                
                continuation.resume(returning: (data, response))
            }
            
            currentTask = task
            task.resume()
        }
        
        currentTask = nil
        
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
    
    /// 이미지 최적화: 크기 제한 및 리사이즈
    private func optimizeImage(_ image: NSImage, maxDimension: CGFloat) -> NSImage {
        let size = image.size
        let maxSize = max(size.width, size.height)
        
        // 이미지가 최대 크기보다 작으면 그대로 반환
        if maxSize <= maxDimension {
            return image
        }
        
        // 비율 유지하며 리사이즈
        let scale = maxDimension / maxSize
        let newSize = NSSize(width: size.width * scale, height: size.height * scale)
        
        let resizedImage = NSImage(size: newSize)
        resizedImage.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: newSize),
                   from: NSRect(origin: .zero, size: size),
                   operation: .copy,
                   fraction: 1.0)
        resizedImage.unlockFocus()
        
        return resizedImage
    }
}

// MARK: - Errors

enum GPTError: Error, LocalizedError {
    case imageEncodingFailed
    case invalidResponse
    case httpError(Int)
    case apiError(String)
    case networkError(Error)
    case requestCancelled
    
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
        case .requestCancelled:
            return "요청이 취소되었습니다."
        }
    }
}

