//
//  FloaterFrameRenderer.swift
//  FloaterCamera
//
//  Created by Christopher Susandji on 07/09/26.
//

import CoreGraphics
import CoreImage
import AppKit

/// Draws the idle placeholder frame that the virtual camera outputs when no
/// timer is being broadcast. It mirrors the host app's `BroadcastPlaceholderView`
/// so the feed looks identical whether the frame comes from the app or from the
/// extension.
enum FloaterFrameRenderer {

    static func drawPlaceholder(in context: CGContext, width: Int, height: Int) {
        let w = CGFloat(width)
        let h = CGFloat(height)

        // Black backdrop (matches BroadcastPlaceholderView).
        context.setFillColor(CGColor(gray: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: w, height: h))

        // Dashed rounded rectangle (matches BroadcastPlaceholderView).
        let margin: CGFloat = 34
        let boxRect = CGRect(x: margin, y: margin, width: w - 2 * margin, height: h - 2 * margin)
        let boxPath = CGPath(roundedRect: boxRect, cornerWidth: 44, cornerHeight: 44, transform: nil)
        context.saveGState()
        context.setStrokeColor(CGColor(gray: 0.5, alpha: 1))
        context.setLineWidth(2)
        context.setLineDash(phase: 0, lengths: [10, 8])
        context.addPath(boxPath)
        context.strokePath()
        context.restoreGState()

        // Message (matches BroadcastPlaceholderView).
        let message = "No active timer selected as source:\nOpen Floater and select a timer."
        let messageFont = NSFont.systemFont(ofSize: 24)
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineSpacing = 6
        let messageAttrs: [NSAttributedString.Key: Any] = [
            .font: messageFont,
            .foregroundColor: NSColor(white: 0.8, alpha: 1),
            .paragraphStyle: paragraph
        ]
        let messageSize = message.size(withAttributes: messageAttrs)

        // Icon + message stack, vertically centered (matches BroadcastPlaceholderView).
        let iconSide: CGFloat = 180
        let spacing: CGFloat = 8
        let stackHeight = iconSide + spacing + messageSize.height
        let stackTop = (h - stackHeight) / 2

        // Icon (grayscale, matches `.saturation(0)` in BroadcastPlaceholderView).
        let iconRect = CGRect(x: (w - iconSide) / 2, y: stackTop, width: iconSide, height: iconSide)
        if let grayscaleIcon = grayscaleAppIcon {
            context.saveGState()
            context.interpolationQuality = .high
            context.draw(grayscaleIcon, in: iconRect)
            context.restoreGState()
        } else {
            drawIcon(in: context, center: CGPoint(x: w / 2, y: stackTop + iconSide / 2), radius: iconSide / 2)
        }

        // Description.
        message.draw(
            in: CGRect(x: (w - messageSize.width) / 2, y: stackTop + iconSide + spacing, width: messageSize.width, height: messageSize.height),
            withAttributes: messageAttrs
        )
    }

    /// The real Floater app icon, desaturated to grayscale to match the host
    /// placeholder. Cached: it's computed once and reused every frame.
    private static let grayscaleAppIcon: CGImage? = {
        guard let url = Bundle.main.url(forResource: "AppIcon", withExtension: "png"),
              let image = NSImage(contentsOf: url),
              let tiff = image.tiffRepresentation,
              let ciImage = CIImage(data: tiff),
              let filter = CIFilter(name: "CIColorControls") else { return nil }
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(0.0, forKey: kCIInputSaturationKey)
        guard let output = filter.outputImage else { return nil }
        let context = CIContext(options: nil)
        return context.createCGImage(output, from: output.extent)
    }()

    /// Draws the Floater app icon as a timer glyph (a tick ring + hand), using
    /// the app's amber accent. Fallback only, if the bundled icon is missing.
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
