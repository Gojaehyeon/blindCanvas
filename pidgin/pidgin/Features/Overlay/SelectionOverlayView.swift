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
    var isLocked: Bool = false {
        didSet { needsDisplay = true }
    }

    // 내부 상태
    private var startPoint: CGPoint?
    private var selectionRect: CGRect = .zero {
        didSet { rectChanged?(selectionRect) }
    }

    // MARK: - Init

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - First Responder / Keyboard

    /// 키 이벤트를 받기 위해 true
    override var acceptsFirstResponder: Bool { 
        print("🔵 acceptsFirstResponder called: true")
        return true 
    }
    
    override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        print("🎯 becomeFirstResponder: \(result)")
        return result
    }

    /// ESC로 lock 해제 또는 오버레이 닫기, Enter로 영역 고정
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // ESC
            print("🔑 ESC pressed, isLocked=\(isLocked), onEscapePressed=\(onEscapePressed != nil ? "exists" : "nil")") // 디버깅
            if let callback = onEscapePressed {
                callback()
            } else {
                print("❌ onEscapePressed is nil!")
            }
            return
        }
        if event.keyCode == 36 { // Enter (Return)
            guard !isLocked, selectionRect != .zero else { return }
            onEnterPressed?()
            return
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
        
        // 영역이 제대로 지정되었으면 완료 처리 (조건을 더 느슨하게)
        if selectionRect != .zero && selectionRect.width > 5 && selectionRect.height > 5 {
            // 직접 isLocked를 업데이트하고 콜백도 호출
            isLocked = true
            print("🔒 Locked! isLocked=\(isLocked), selectionRect=\(selectionRect)") // 디버깅
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
        let hint = isLocked
        ? "Locked: Space=시적, Enter=구조, ESC=닫기"
        : "드래그로 영역 지정 → Enter로 고정, ESC로 닫기"
        
        // 디버깅: draw가 호출될 때마다 isLocked 값 확인
        if isLocked {
            print("🎨 Drawing with isLocked=true, hint=\(hint)")
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
