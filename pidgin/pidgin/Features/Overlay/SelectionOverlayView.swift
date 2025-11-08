//
//  SelectionOverlayView.swift
//  pidgin
//
//  Created by go on 11/1/25.
//

import Cocoa

final class SelectionOverlayView: NSView {
    // 외부 바인딩
    var rectChanged: ((CGRect) -> Void)?
    var onEnterPressed: (() -> Void)?
    var onSelectionComplete: (() -> Void)?
    var onEscapePressed: (() -> Void)?
    var onSpacePressedInLocked: (() -> Void)?  // Locked 상태에서 Space 키
    var onEnterPressedInLocked: (() -> Void)?  // Locked 상태에서 Enter 키
    var isLocked: Bool = false {
        didSet { needsDisplay = true }
    }
    var isRequesting: Bool = false {
        didSet {
            needsDisplay = true
            updateLoadingIndicator()
        }
    }
    var isTTSPlaying: Bool = false {
        didSet { needsDisplay = true }
    }

    // 내부 상태
    private var startPoint: CGPoint?
    var selectionRect: CGRect = .zero {
        didSet { rectChanged?(selectionRect) }
    }
    private var loadingIndicator: NSProgressIndicator?

    // MARK: - Init

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        setupLoadingIndicator()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    private func setupLoadingIndicator() {
        let indicator = NSProgressIndicator()
        indicator.style = .spinning
        indicator.controlSize = .regular
        indicator.isIndeterminate = true
        indicator.isDisplayedWhenStopped = false
        indicator.isHidden = true
        addSubview(indicator)
        
        loadingIndicator = indicator
    }
    
    private func updateLoadingIndicator() {
        guard let indicator = loadingIndicator else { return }
        
        // 중앙에 위치하도록 frame 설정
        let size: CGFloat = 32
        indicator.frame = NSRect(
            x: (bounds.width - size) / 2,
            y: (bounds.height - size) / 2,
            width: size,
            height: size
        )
        
        if isRequesting {
            indicator.startAnimation(nil)
            indicator.isHidden = false
        } else {
            indicator.stopAnimation(nil)
            indicator.isHidden = true
        }
    }
    
    override func layout() {
        super.layout()
        // 레이아웃 변경 시 로딩 인디케이터 위치 업데이트
        if let indicator = loadingIndicator, !indicator.isHidden {
            let size: CGFloat = 32
            indicator.frame = NSRect(
                x: (bounds.width - size) / 2,
                y: (bounds.height - size) / 2,
                width: size,
                height: size
            )
        }
    }

    // MARK: - First Responder / Keyboard

    /// 키 이벤트를 받기 위해 true
    override var acceptsFirstResponder: Bool { true }
    
    override func becomeFirstResponder() -> Bool {
        return super.becomeFirstResponder()
    }

    /// 키 입력 처리
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // ESC
            onEscapePressed?()
            return
        }
        
        // 재생 중일 때도 스페이스/엔터로 다시 분석 요청 가능
        if isLocked || isTTSPlaying {
            // Locked 상태 또는 재생 중: Space(시적), Enter(구조적) 분석 요청
            if event.keyCode == 49 { // Space
                onSpacePressedInLocked?()
                return
            }
            if event.keyCode == 36 { // Enter (Return)
                onEnterPressedInLocked?()
                return
            }
        } else {
            // Selecting 상태: Enter로 영역 고정
            if event.keyCode == 36 { // Enter (Return)
                guard selectionRect != .zero else { return }
                onEnterPressed?()
                return
            }
        }
        
        super.keyDown(with: event)
    }

    // MARK: - Mouse (drag to select when not locked)

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        guard !isLocked else { return }
        startPoint = convert(event.locationInWindow, from: nil)
        selectionRect = .zero
        needsDisplay = true

        // ESC가 바로 동작하도록 포커스 이 뷰로 강제
        window?.makeFirstResponder(self)
    }

    override func mouseDragged(with event: NSEvent) {
        guard !isLocked, let start = startPoint else { return }
        let current = convert(event.locationInWindow, from: nil)
        selectionRect = NSRect(
            x: min(start.x, current.x),
            y: min(start.y, current.y),
            width: abs(current.x - start.x),
            height: abs(current.y - start.y)
        )
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard !isLocked else { return }
        startPoint = nil
        
        // 영역이 제대로 지정되었으면 완료 처리
        if selectionRect != .zero && selectionRect.width > 5 && selectionRect.height > 5 {
            // 직접 isLocked를 업데이트하고 콜백도 호출
            isLocked = true
            onSelectionComplete?()
            
            // 강제로 전체 뷰를 다시 그림
            needsDisplay = true
            display(bounds)
        } else {
            needsDisplay = true
        }
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // 배경 어둡게
        NSColor.black.withAlphaComponent(isLocked ? 0.15 : 0.30).setFill()
        dirtyRect.fill()

        if selectionRect != .zero {
            // 선택 영역 투명하게
            NSGraphicsContext.saveGraphicsState()
            NSBezierPath(rect: selectionRect).addClip()
            NSColor.clear.setFill()
            selectionRect.fill(using: .clear)
            NSGraphicsContext.restoreGraphicsState()

            // 테두리
            let border = NSBezierPath(rect: selectionRect)
            (isLocked ? NSColor.systemBlue : NSColor.systemTeal).setStroke()
            border.lineWidth = isLocked ? 4 : 2
            border.stroke()
        }

        // 안내 텍스트
        if isRequesting {
            // 분석 중일 때: 로딩 인디케이터와 함께 표시
            let hint = "분석 중..."
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .medium),
                .foregroundColor: NSColor.white.withAlphaComponent(0.92)
            ]
            let size = hint.size(withAttributes: attrs)
            // 중앙 하단에 텍스트 배치 (로딩 인디케이터 아래)
            let rect = NSRect(
                x: (bounds.width - size.width) / 2,
                y: bounds.height / 2 - 40, // 로딩 인디케이터 아래
                width: size.width,
                height: size.height
            )
            hint.draw(in: rect, withAttributes: attrs)
        } else if isTTSPlaying {
            // TTS 재생 중일 때: 로딩 인디케이터 없이 텍스트만 표시
            let hint = "설명중..."
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .medium),
                .foregroundColor: NSColor.white.withAlphaComponent(0.92)
            ]
            let size = hint.size(withAttributes: attrs)
            let rect = NSRect(x: 16, y: 16, width: size.width, height: size.height)
            hint.draw(in: rect, withAttributes: attrs)
        } else {
            // 일반 상태
            let hint: String
            if isLocked {
                hint = "Locked: Space=시적, Enter=구조, ESC=닫기"
            } else {
                hint = "드래그로 영역 지정 → Enter로 고정, ESC로 닫기"
            }
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .medium),
                .foregroundColor: NSColor.white.withAlphaComponent(0.92)
            ]
            let size = hint.size(withAttributes: attrs)
            let rect = NSRect(x: 16, y: 16, width: size.width, height: size.height)
            hint.draw(in: rect, withAttributes: attrs)
        }
    }
}
