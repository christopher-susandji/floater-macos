//
//  FloaterFrameRenderer.swift
//  FloaterCamera
//
//  Created by Christopher Susandji on 07/09/26.
//

import CoreGraphics
import AppKit

/// Draws placeholder content into the outgoing frame. Phase 0 only: we render a
/// centered "FLOATER" wordmark plus a live timestamp so a streaming frame is
/// easy to distinguish from a frozen one. This is replaced by the host app's
/// rendered timer once frame transport lands.
enum FloaterFrameRenderer {

    static func drawPlaceholder(in context: CGContext, width: Int, height: Int) {
        let fontSize = CGFloat(min(width, height)) / 8
        let font = NSFont.systemFont(ofSize: fontSize, weight: .heavy)

        let wordmark = "FLOATER"
        let wordmarkAttrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white
        ]
        let wordmarkSize = wordmark.size(withAttributes: wordmarkAttrs)
        let wordmarkRect = CGRect(
            x: (CGFloat(width) - wordmarkSize.width) / 2,
            y: (CGFloat(height) + fontSize * 0.4) / 2,
            width: wordmarkSize.width,
            height: wordmarkSize.height
        )
        wordmark.draw(in: wordmarkRect, withAttributes: wordmarkAttrs)

        let clock = Self.clockText
        let clockFont = NSFont.monospacedDigitSystemFont(ofSize: fontSize / 2, weight: .regular)
        let clockAttrs: [NSAttributedString.Key: Any] = [
            .font: clockFont,
            .foregroundColor: NSColor(white: 0.7, alpha: 1)
        ]
        let clockSize = clock.size(withAttributes: clockAttrs)
        let clockRect = CGRect(
            x: (CGFloat(width) - clockSize.width) / 2,
            y: (CGFloat(height) - fontSize * 0.9) / 2,
            width: clockSize.width,
            height: clockSize.height
        )
        clock.draw(in: clockRect, withAttributes: clockAttrs)
    }

    private static var clockText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: Date())
    }
}
