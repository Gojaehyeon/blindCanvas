//
//  AppState.swift
//  pidgin
//
//  Created by go on 11/1/25.
//

import Foundation
import CoreGraphics
import AppKit
import Combine

@MainActor
final class AppState: ObservableObject {
    enum SelectionState { 
        case idle
        case selecting
        case locked
        case requesting  // AI 분석 요청 중
    }
    
    enum AnalysisMode {
        case poetic      // 시적 해석
        case structural  // 구조적 해석
    }
    
    @Published var selectionState: SelectionState = .idle
    @Published var selectedRect: CGRect = .zero
    @Published var overlayVisible: Bool = false
    @Published var analysisMode: AnalysisMode? = nil
    @Published var analysisResponse: String? = nil
    @Published var isTTSPlaying: Bool = false
    @Published var errorMessage: String? = nil
    
    // 마지막으로 Lock된 영역 저장
    @Published var lastLockedRect: CGRect = .zero
    
    var isLocked: Bool { selectionState == .locked }
    var isRequesting: Bool { selectionState == .requesting }
    
    func reset() {
        print("🔄 AppState.reset() called, preserving lastLockedRect: \(lastLockedRect)")
        let preservedRect = lastLockedRect
        selectionState = .idle
        selectedRect = .zero
        analysisMode = nil
        analysisResponse = nil
        errorMessage = nil
        // lastLockedRect는 유지 (다음에 재사용)
        lastLockedRect = preservedRect
        print("✅ AppState.reset() completed, lastLockedRect preserved: \(lastLockedRect)")
    }
    
    func resetToNewSelection() {
        // 새로 그리기 모드: 모든 것을 리셋
        reset()
        lastLockedRect = .zero
    }
}
