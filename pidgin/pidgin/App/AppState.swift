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
    
    var isLocked: Bool { selectionState == .locked }
    var isRequesting: Bool { selectionState == .requesting }
    
    func reset() {
        selectionState = .idle
        selectedRect = .zero
        analysisMode = nil
        analysisResponse = nil
        errorMessage = nil
    }
}
