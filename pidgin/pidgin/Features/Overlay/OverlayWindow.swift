//
//  OverlayWindow.swift
//  pidgin
//
//  Created by go on 11/1/25.
//

import Cocoa
import SwiftUI
import Combine

final class OverlayWindow: NSPanel {
    private var overlayController = OverlayController()
    
    // 외부에서 SelectionView 접근용 (디버깅 및 복원용)
    func getSelectionView() -> SelectionOverlayView? {
        return overlayController.getSelectionView()
    }

    init() {
        let screenRect = NSScreen.main?.frame ?? .zero
        super.init(
            contentRect: screenRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        level = .statusBar                    // 거의 최상위
        isOpaque = false
        hasShadow = false
        backgroundColor = .clear
        ignoresMouseEvents = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        // 초기에는 EmptyView로 시작 (appState가 연결된 후 다시 생성됨)
        contentView = NSHostingView(rootView: AnyView(EmptyView()))
    }

    // SwiftUI(NSViewRepresentable)와 상태 연결
    func bind(appState: AppState) {
        overlayController.window = self
        overlayController.bind(appState: appState)
        
        // bind 후 뷰를 다시 생성 (appState가 연결되었으므로)
        let root = overlayController.overlayView()
        let newHostingView = NSHostingView(rootView: root)
        contentView = newHostingView
        
        // 뷰가 업데이트되면 first responder 설정
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.makeFirstResponderToOverlay()
        }
    }

    func setLocked(_ locked: Bool) {
        overlayController.setLocked(locked)
        ignoresMouseEvents = locked
    }

    // 키 입력이 바로 들어오도록 포커스 이동
    func makeFirstResponderToOverlay() {
        // OverlayController에서 저장된 뷰 참조 사용 (가장 확실한 방법)
        if let selectionView = overlayController.getSelectionView() {
            if makeFirstResponder(selectionView) {
                // 성공
            } else {
                // 재시도
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    _ = self.makeFirstResponder(selectionView)
                }
            }
        } else {
            // 뷰가 아직 생성되지 않았을 수 있으니 나중에 다시 시도
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                if let selectionView = self.overlayController.getSelectionView() {
                    _ = self.makeFirstResponder(selectionView)
                }
            }
        }
    }

    // 멀티 모니터 환경에서 메인 스크린 중앙에 보정
    func centerOnMainScreenIfNeeded() {
        guard let screen = NSScreen.main else { return }
        setFrame(screen.frame, display: true)
    }

    // 키 입력을 받을 수 있도록 설정
    override var canBecomeKey: Bool { true }
    
    // ESC는 SelectionOverlayView에서 처리
    override func keyDown(with event: NSEvent) {
        super.keyDown(with: event)
    }
    
    // 오버레이 닫기 (자체 dismiss)
    func dismiss() {
        // TTS 재생 중지
        TextToSpeechService.shared.stop()
        
        // AppDelegate를 통해 dismiss 시도
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if let appDelegate = NSApp.delegate as? AppDelegate {
                appDelegate.dismissOverlay()
            } else {
                // fallback: 직접 닫기 (SwiftUI 앱에서는 NSApp.delegate가 다를 수 있음)
                self.resignKey()
                self.orderOut(nil)
                // appState도 리셋
                if let appState = self.overlayController.appState {
                    appState.overlayVisible = false
                    appState.isTTSPlaying = false
                    let savedRect = appState.lastLockedRect
                    appState.reset()
                    appState.lastLockedRect = savedRect
                }
            }
        }
    }
}

// MARK: - Coordinator + View

private final class OverlayController {
    weak var appState: AppState?
    weak var window: OverlayWindow?
    private var selectionView: SelectionOverlayView?

    func bind(appState: AppState) {
        self.appState = appState
        // idle 상태이고 lastLockedRect가 없을 때만 selecting으로 변경
        if appState.selectionState == .idle && appState.lastLockedRect == .zero {
            appState.selectionState = .selecting
        }
        
        // AppState 변경 감지하여 SelectionOverlayView 직접 업데이트
        appState.$selectionState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self, let view = self.selectionView, let appState = self.appState else { return }
                view.isLocked = appState.isLocked
                view.isRequesting = appState.isRequesting
                view.needsDisplay = true
            }
            .store(in: &cancellables)
        
        // selectedRect 변경 감지하여 뷰 업데이트
        appState.$selectedRect
            .receive(on: DispatchQueue.main)
            .sink { [weak self] rect in
                guard let self = self, let view = self.selectionView else { return }
                if view.selectionRect != rect {
                    view.selectionRect = rect
                    view.needsDisplay = true
                }
            }
            .store(in: &cancellables)
        
        // TTS 재생 상태 변경 감지
        appState.$isTTSPlaying
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self, let view = self.selectionView, let appState = self.appState else { return }
                view.isTTSPlaying = appState.isTTSPlaying
                view.needsDisplay = true
            }
            .store(in: &cancellables)
    }
    
    private var cancellables = Set<AnyCancellable>()

    func setLocked(_ locked: Bool) {
        // 사용하지 않음
    }
    
    func setSelectionView(_ view: SelectionOverlayView) {
        self.selectionView = view
    }
    
    func getSelectionView() -> SelectionOverlayView? {
        return selectionView
    }

    func overlayView() -> AnyView {
        // appState를 직접 캡처 (OverlayController의 weak 참조 문제 회피)
        guard let appState = self.appState else {
            return AnyView(EmptyView())
        }
        
        return AnyView(
            OverlayView(controller: self,
                        onRectChange: { rect in appState.selectedRect = rect },
                        onEnterPressed: { [weak self] in
                            guard let self = self else { return }
                            guard appState.selectionState == .selecting, appState.selectedRect != .zero else {
                                return
                            }
                            appState.selectionState = .locked
                            appState.lastLockedRect = appState.selectedRect  // 영역 저장
                            // 뷰를 직접 업데이트
                            if let view = self.selectionView {
                                view.isLocked = true
                            }
                        },
                        onSelectionComplete: { [weak self] in
                            guard let self = self else { return }
                            guard appState.selectionState == .selecting, appState.selectedRect != .zero else {
                                return
                            }
                            appState.selectionState = .locked
                            appState.lastLockedRect = appState.selectedRect  // 영역 저장
                            // 뷰를 직접 업데이트
                            if let view = self.selectionView {
                                view.isLocked = true
                            }
                        },
                        onEscapePressed: { [weak self] in
                            // ESC: 재생 중이면 재생만 중지, 분석 중이면 분석 취소, Locked 상태에서 누르면 다시 선택 모드로, 아니면 오버레이 닫기
                            guard let self = self else { return }
                            
                            // 재생 중일 때는 재생만 중지하고 오버레이는 유지
                            if appState.isTTSPlaying {
                                TextToSpeechService.shared.stop()
                                appState.isTTSPlaying = false
                                return
                            }
                            
                            // 분석 요청 중일 때는 분석 취소
                            if appState.selectionState == .requesting {
                                AnalysisService.shared.cancelCurrentAnalysis()
                                appState.selectionState = .locked
                                appState.errorMessage = "분석이 취소되었습니다."
                                return
                            }
                            
                            if appState.selectionState == .locked {
                                // 새로 그리기 모드로 전환 (lastLockedRect는 유지)
                                appState.selectionState = .selecting
                                appState.selectedRect = .zero
                                if let view = self.selectionView {
                                    view.isLocked = false
                                    view.selectionRect = .zero  // 선택 영역 초기화
                                    view.needsDisplay = true
                                }
                            } else {
                                // 오버레이 닫기
                                self.window?.dismiss()
                            }
                        },
                        onSpacePressedInLocked: { [weak self] in
                            // Space: 시적 해석 요청 (재생 중이면 재생 중지 후 다시 분석)
                            guard let self = self else { return }
                            // locked 상태이거나 재생 중일 때 동작
                            guard (appState.selectionState == .locked || appState.isTTSPlaying),
                                  appState.selectedRect != .zero else { return }
                            
                            // 재생 중이면 재생 중지
                            if appState.isTTSPlaying {
                                TextToSpeechService.shared.stop()
                                appState.isTTSPlaying = false
                            }
                            
                            Task { @MainActor in
                                await AnalysisService.shared.analyzeRegion(
                                    appState.selectedRect,
                                    mode: .poetic,
                                    appState: appState
                                )
                            }
                        },
                        onEnterPressedInLocked: { [weak self] in
                            // Enter: 전맹 시각장애인용 그림 해설 요청
                            guard let self = self else { return }
                            
                            // 재생 중이면 재생만 중지하고 종료 (새로운 분석 시작 안 함)
                            if appState.isTTSPlaying {
                                TextToSpeechService.shared.stop()
                                appState.isTTSPlaying = false
                                return
                            }
                            
                            // locked 상태에서만 새로운 해석 요청
                            guard appState.selectionState == .locked,
                                  appState.selectedRect != .zero else { return }
                            
                            // userText가 비어있으면 기본값 사용
                            let userText = appState.userText.isEmpty ? "그림" : appState.userText
                            
                            Task { @MainActor in
                                await AnalysisService.shared.analyzeRegionForBlindUser(
                                    appState.selectedRect,
                                    userText: userText,
                                    appState: appState
                                )
                            }
                        })
                .ignoresSafeArea()
        )
    }
}

private struct OverlayView: NSViewRepresentable {
    let controller: OverlayController
    let onRectChange: (CGRect) -> Void
    let onEnterPressed: () -> Void
    let onSelectionComplete: () -> Void
    let onEscapePressed: () -> Void
    let onSpacePressedInLocked: () -> Void
    let onEnterPressedInLocked: () -> Void

    func makeNSView(context: Context) -> SelectionOverlayView {
        let v = SelectionOverlayView()
        v.rectChanged = onRectChange
        v.onEnterPressed = onEnterPressed
        v.onSelectionComplete = onSelectionComplete
        v.onEscapePressed = onEscapePressed
        v.onSpacePressedInLocked = onSpacePressedInLocked
        v.onEnterPressedInLocked = onEnterPressedInLocked
        v.isLocked = controller.appState?.isLocked ?? false
        v.isRequesting = controller.appState?.isRequesting ?? false
        v.isTTSPlaying = controller.appState?.isTTSPlaying ?? false
        
        controller.setSelectionView(v)
        
        // 뷰가 등록된 후 초기 선택 영역 설정 (appState.selectedRect 사용)
        if let appState = controller.appState {
            v.selectionRect = appState.selectedRect
        }
        // 오버레이 표시 즉시 ESC가 먹히도록 포커스
        DispatchQueue.main.async {
            if v.window?.makeFirstResponder(v) == true {
                // 성공
            } else {
                // 재시도
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    _ = v.window?.makeFirstResponder(v)
                }
            }
        }
        return v
    }

    func updateNSView(_ nsView: SelectionOverlayView, context: Context) {
        nsView.onEnterPressed = onEnterPressed
        nsView.onSelectionComplete = onSelectionComplete
        nsView.onEscapePressed = onEscapePressed
        nsView.onSpacePressedInLocked = onSpacePressedInLocked
        nsView.onEnterPressedInLocked = onEnterPressedInLocked
        nsView.isLocked = controller.appState?.isLocked ?? false
        nsView.isRequesting = controller.appState?.isRequesting ?? false
        nsView.isTTSPlaying = controller.appState?.isTTSPlaying ?? false
        
        // selectedRect도 업데이트
        if let appState = controller.appState {
            if nsView.selectionRect != appState.selectedRect {
                nsView.selectionRect = appState.selectedRect
            }
        }
        
        nsView.needsDisplay = true
    }
}
