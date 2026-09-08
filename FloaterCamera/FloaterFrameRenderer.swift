//
//  FloaterFrameRenderer.swift
//  FloaterCamera
//
//  Created by Christopher Susandji on 07/09/26.
//

import CoreGraphics
import AppKit

/// Draws the idle placeholder frame that the virtual camera outputs when no
/// timer is being broadcast. It communicates "Floater is running, but pick a
/// timer to show" rather than rendering a timer.
enum FloaterFrameRenderer {

    static func drawPlaceholder(in context: CGContext, width: Int, height: Int) {
        let w = CGFloat(width)
        let h = CGFloat(height)

        // Dark backdrop.
        context.setFillColor(CGColor(gray: 0.06, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: w, height: h))

        // Placeholder affordance: a dashed rounded rectangle around the message,
        // signalling this is an "empty" frame, not a live timer.
        let margin = min(w, h) * 0.15
        let boxRect = CGRect(x: margin, y: margin, width: w - 2 * margin, height: h - 2 * margin)
        let boxPath = CGPath(roundedRect: boxRect, cornerWidth: min(w, h) * 0.06, cornerHeight: min(w, h) * 0.06, transform: nil)
        context.saveGState()
        context.setStrokeColor(CGColor(gray: 0.35, alpha: 1))
        context.setLineWidth(2)
        context.setLineDash(phase: 0, lengths: [10, 8])
        context.addPath(boxPath)
        context.strokePath()
        context.restoreGState()

        let iconCenter = CGPoint(x: w / 2, y: h * 0.62)
        let iconRadius = min(w, h) * 0.13
        if let iconImage = bundledAppIcon {
            let side = iconRadius * 2
            let iconRect = CGRect(x: iconCenter.x - iconRadius, y: iconCenter.y - iconRadius, width: side, height: side)
            context.saveGState()
            context.interpolationQuality = .high
            if let cgImage = iconImage.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                context.draw(cgImage, in: iconRect)
            }
            context.restoreGState()
        } else {
            drawIcon(in: context, center: iconCenter, radius: iconRadius)
        }

        // Title.
        let title = "Floater"
        let titleFont = NSFont.systemFont(ofSize: min(w, h) * 0.10, weight: .heavy)
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: NSColor.white
        ]
        let titleSize = title.size(withAttributes: titleAttrs)
        title.draw(
            at: CGPoint(x: (w - titleSize.width) / 2, y: h * 0.36),
            withAttributes: titleAttrs
        )

        // Description.
        let message = "No active timer selected as source.\nOpen Floater and select a timer."
        let messageFont = NSFont.systemFont(ofSize: min(w, h) * 0.04, weight: .regular)
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineSpacing = 4
        let messageAttrs: [NSAttributedString.Key: Any] = [
            .font: messageFont,
            .foregroundColor: NSColor(white: 0.6, alpha: 1),
            .paragraphStyle: paragraph
        ]
        let messageSize = message.size(withAttributes: messageAttrs)
        message.draw(
            in: CGRect(x: w * 0.12, y: h * 0.22, width: w * 0.76, height: messageSize.height),
            withAttributes: messageAttrs
        )
    }

    /// The real Floater app icon (a flattened copy bundled with the extension),
    /// or `nil` if the asset is missing — in which case we fall back to the
    /// hand-drawn glyph.
    private static var bundledAppIcon: NSImage? {
        guard let url = Bundle.main.url(forResource: "AppIcon", withExtension: "png") else { return nil }
        return NSImage(contentsOf: url)
    }

    /// Draws the Floater app icon as a timer glyph (a tick ring + hand), using
    /// the app's amber accent.
    private static func drawIcon(in context: CGContext, center: CGPoint, radius: CGFloat) {
        let accent = CGColor(red: 1.0, green: 0.55, blue: 0.16, alpha: 1)

        // Outer ring.
        context.saveGState()
        context.setStrokeColor(accent)
        context.setLineWidth(radius * 0.12)
        let ringRect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        context.strokeEllipse(in: ringRect)

        // Tick marks around the upper half (like a timer face).
        context.setLineWidth(radius * 0.08)
        for i in 0..<12 {
            let angle = CGFloat(i) / 12 * 2 * .pi
            let cosA = cos(angle), sinA = sin(angle)
            let outer = radius * 0.92
            let inner = radius * (i % 3 == 0 ? 0.72 : 0.80)
            context.move(to: CGPoint(x: center.x + cosA * outer, y: center.y + sinA * outer))
            context.addLine(to: CGPoint(x: center.x + cosA * inner, y: center.y + sinA * inner))
        }
        context.strokePath()

        // Clock hand pointing up-right (classic timer hand).
        context.setStrokeColor(CGColor(gray: 1, alpha: 1))
        context.setLineWidth(radius * 0.10)
        context.setLineCap(.round)
        context.move(to: CGPoint(x: center.x, y: center.y))
        context.addLine(to: CGPoint(x: center.x + radius * 0.45, y: center.y + radius * 0.45))
        context.strokePath()
        context.restoreGState()
    }
}
