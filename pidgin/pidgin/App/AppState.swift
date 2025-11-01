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
    enum SelectionState { case idle, selecting, locked }

    @Published var selectionState: SelectionState = .idle
    @Published var selectedRect: CGRect = .zero
    @Published var overlayVisible: Bool = false   // ← 추가

    var isLocked: Bool { selectionState == .locked }

    func reset() {
        selectionState = .idle
        selectedRect = .zero
    }
}
