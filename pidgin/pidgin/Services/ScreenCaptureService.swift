//
//  ScreenCaptureService.swift
//  pidgin
//
//  Created by go on 11/1/25.
//

import AppKit
import CoreGraphics

final class ScreenCaptureService {
    static let shared = ScreenCaptureService()
    
    private init() {}
    
    /// 지정한 영역을 이미지로 캡처
    /// - Parameter rect: 캡처할 영역 (화면 좌표계, origin은 왼쪽 위)
    /// - Returns: 캡처된 이미지 또는 nil (실패 시)
    func captureRegion(_ rect: CGRect) async throws -> NSImage? {
        // 화면 좌표계를 CG 좌표계로 변환 (macOS는 Y축이 반대)
        guard let mainScreen = NSScreen.main else {
            throw CaptureError.noScreen
        }
        
        let screenHeight = mainScreen.frame.height
        let cgRect = CGRect(
            x: rect.origin.x,
            y: screenHeight - rect.origin.y - rect.height,
            width: rect.width,
            height: rect.height
        )
        
        // CGDisplayCreateImage 사용 (간단하고 빠름)
        // 주의: 이 방법은 앱이 foreground에 있어야 작동할 수 있음
        if let imageRef = CGDisplayCreateImage(CGMainDisplayID(), rect: cgRect) {
            return NSImage(cgImage: imageRef, size: rect.size)
        }
        
        throw CaptureError.captureFailed
    }
}

// MARK: - Errors

enum CaptureError: Error {
    case noScreen
    case captureFailed
}
