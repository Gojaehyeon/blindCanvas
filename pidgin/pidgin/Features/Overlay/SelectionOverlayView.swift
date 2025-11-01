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

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - First Responder / Keyboard

    /// 키 이벤트를 받기 위해 반드시 true
    override var acceptsFirstResponder: Bool { true }

    /// ESC로 오버레이 닫기
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // ESC
            (NSApp.delegate as? AppDelegate)?.dismissOverlay()
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

        // 키 포커스를 이 뷰로 강제 (ESC가 바로 동작하도록)
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
        needsDisplay = true
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // 배경을 어둡게, 선택영역은 투명하게
        NSColor.black.withAlphaComponent(isLocked ? 0.15 : 0.30).setFill()
        dirtyRect.fill()

        if selectionRect != .zero {
            // 선택 영역을 클리어(보이게)
            NSGraphicsContext.saveGraphicsState()
            let clip = NSBezierPath(rect: selectionRect)
            clip.addClip()
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
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .medium),
            .foregroundColor: NSColor.white.withAlphaComponent(0.92)
        ]
        let size = hint.size(withAttributes: attrs)
        let rect = NSRect(x: 16, y: 16, width: size.width, height: size.height)
        hint.draw(in: rect, withAttributes: attrs)
    }
}
