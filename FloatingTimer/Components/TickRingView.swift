//
//  TickRingView.swift
//  FloatingTimer
//
//  Created by Christopher Susandji on 20/08/26.
//

import SwiftUI

struct TickRingView: View {
    var remaining: TimeInterval
    var tickCount: Int = 60
    
    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let originX = (geo.size.width - size) / 2
            let originY = (geo.size.height - size) / 2
            let square = CGRect(x: originX, y: originY, width: size, height: size)
            let rect = square.insetBy(dx: 8, dy: 8)
            
            let outerRadius: CGFloat = 24.0
            let inset: CGFloat = 8.0
            let innerRadius = max(0, outerRadius - 0.214 * inset)
            let innerRect = rect.insetBy(dx: inset, dy: inset)
            
            ZStack(alignment: .center) {
                ForEach(0..<tickCount, id: \.self) { i in
                    let rawT = Double(i) / Double(tickCount)
                    let startOffset = topCenterStartOffset(in: rect, cornerRadius: outerRadius)
                    let t = (rawT + startOffset).truncatingRemainder(dividingBy: 1.0)
                    
                    let pOuter = roundedRectPoint(at: t, in: rect, cornerRadius: outerRadius)
                    let pInner = roundedRectPoint(at: t, in: innerRect, cornerRadius: innerRadius)
                    
                    let tickPhase = Double(i) / Double(max(1, tickCount))
                    let opacity = tickOpacity(for: tickPhase)
                    let tickColor = Color.primary.opacity(opacity)
                    Path { p in
                        p.move(to: pOuter)
                        p.addLine(to: pInner)
                    }
                    .stroke(
                        tickColor,
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                }
            }
            .frame(width: size, height: size)
            .animation(.linear(duration: 0.2), value: remaining)
        }
    }
}

private extension TickRingView {
    func roundedRectPoint(at t: Double, in rect: CGRect, cornerRadius: CGFloat) -> CGPoint {
        let w = rect.width
        let h = rect.height
        let r = max(0, min(cornerRadius, min(w, h) / 2))
        
        let top = w - 2 * r
        let right = h - 2 * r
        let bottom = top
        let left = right
        let arc = .pi * r / 2
        
        let segs: [CGFloat] = [top, arc, right, arc, bottom, arc, left, arc]
        let total = segs.reduce(0, +)
        
        var d = t * total
        
        let x0 = rect.minX
        let y0 = rect.minY
        let x1 = rect.maxX
        let y1 = rect.maxY
        
        func arcPoint(center: CGPoint, start: CGFloat, delta: CGFloat) -> CGPoint {
            CGPoint(
                x: center.x + r * cos(start + delta),
                y: center.y + r * sin(start + delta)
            )
        }
        
        // 1 top
        if d <= segs[0] { return CGPoint(x: x0 + r + d, y: y0) }
        d -= segs[0]
        
        // 2 top-right arc (-90 -> 0)
        if d <= segs[1] { return arcPoint(center: CGPoint(x: x1 - r, y: y0 + r), start: -.pi/2, delta: d / r) }
        d -= segs[1]
        
        // 3 right
        if d <= segs[2] { return CGPoint(x: x1, y: y0 + r + d) }
        d -= segs[2]
        
        // 4 bottom-right arc (0 -> 90)
        if d <= segs[3] { return arcPoint(center: CGPoint(x: x1 - r, y: y1 - r), start: 0, delta: d / r) }
        d -= segs[3]
        
        // 5 bottom
        if d <= segs[4] { return CGPoint(x: x1 - r - d, y: y1) }
        d -= segs[4]
        
        // 6 bottom-left arc (90 -> 180)
        if d <= segs[5] { return arcPoint(center: CGPoint(x: x0 + r, y: y1 - r), start: .pi/2, delta: d / r) }
        d -= segs[5]
        
        // 7 left
        if d <= segs[6] { return CGPoint(x: x0, y: y1 - r - d) }
        d -= segs[6]
        
        // 8 top-left arc (180 -> 270)
        return arcPoint(center: CGPoint(x: x0 + r, y: y0 + r), start: .pi, delta: min(d / r, .pi / 2))
    }
    
    func topCenterStartOffset(in rect: CGRect, cornerRadius: CGFloat) -> Double {
        let w = rect.width
        let h = rect.height
        let r = max(0, min(cornerRadius, min(w, h) / 2))
        
        let top = w - 2 * r
        let right = h - 2 * r
        let bottom = top
        let left = right
        let arc = CGFloat.pi * r / 2
        
        let segs: [CGFloat] = [top, arc, right, arc, bottom, arc, left, arc]
        let total = segs.reduce(0, +)
        
        // Path starts at top-left straight segment start.
        // Top-center is half-way along top segment.
        let dToTopCenter = top / 2
        return Double(dToTopCenter / total)
    }
    
    var headPhase: Double {
        let total = max(0, remaining)
        let secondsIntoCurrentMinute = total.truncatingRemainder(dividingBy: 60)
        let progress = secondsIntoCurrentMinute / 60.0
        return progress
    }
    
    var fractionalTickPhase: Double {
        // how far the head is between two ticks
        let x = headPhase * Double(tickCount)
        return x - floor(x)
    }
    
    func wrappedDistanceForward(from a: Double, to b: Double) -> Double {
        // clockwise/forward distance on [0,1)
        let d = b - a
        return d >= 0 ? d : d + 1
    }
    
    func tickOpacity(for tickPhase: Double) -> Double {
        // Base opacity for inactive background ticks
        let base = 0.10
        if remaining <= 0 { return 0.1 }
        
        // Trail behind head (comet tail)
        // "Behind" means from tick -> head in forward direction is small.
        let dToHead = wrappedDistanceForward(from: tickPhase, to: headPhase)
        let trailLength = 1.0 // portion of ring used for trail
        var trail = max(0, 1 - dToHead / trailLength)
        let isLastMinute = remaining < 60
        if isLastMinute && tickPhase > headPhase {
            trail = 0
        }
        let trailOpacity = pow(trail, 1.8) * 0.85
        
        // Pre-landing pulse on the NEXT tick (head will land there next)
        let nextTickIndex = (Int(floor(headPhase * Double(tickCount))) + 1) % tickCount
        let nextTickPhase = Double(nextTickIndex) / Double(tickCount)
        
        // Strong pulse from 0 -> 1 as head approaches next tick
        let approach = fractionalTickPhase // 0 at current tick, 1 before landing next
        let isNextTick = abs(tickPhase - nextTickPhase) < (0.5 / Double(tickCount))
        let landingPulse = isNextTick ? pow(approach, 1.2) : 0
        
        // Head glow on current head-neighborhood for continuity
        let dFromHead = min(
            wrappedDistanceForward(from: tickPhase, to: headPhase),
            wrappedDistanceForward(from: headPhase, to: tickPhase)
        )
        let headGlow = max(0, 1 - dFromHead / 0.03) * 0.6
        
        return min(1.0, base + trailOpacity + landingPulse + headGlow)
    }
}