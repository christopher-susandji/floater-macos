//
//  TimerView.swift
//  FloatingTimer
//
//  Created by Christopher Susandji on 27/07/26.
//
import SwiftUI

struct TimerView: View {
    @State private var viewModel: TimerViewModel
    @State private var isHovered = false
    @State private var editMode = false
    @State private var isResetButtonHovered = false
    @Namespace private var namespace
    
    let minutes: [TimeInterval] = [60, 120, 180, 300, 600, 900, 1800, 3600]
    let columnLayout = Array(repeating: GridItem(), count: 2)
    var onDelete: (() -> Void)?
    
    private let tickCount: Int = 60
    private let majorTickEvery: Int = 5
    
    init(viewModel: TimerViewModel, onDelete: (() -> Void)? = nil) {
        self._viewModel = State(initialValue: viewModel)
        self.onDelete = onDelete
    }
    
    private var progress: Double {
        guard viewModel.duration > 0 else { return 0 }
        return max(0, min(1, viewModel.remaining / viewModel.duration))
    }
    
    private var activeTickCount: Int {
        Int((progress * Double(tickCount)).rounded(.toNearestOrAwayFromZero))
    }
    
    var body: some View {
        Group {
            ZStack(alignment: .center) {
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
                    .animation(.linear(duration: 0.2), value: viewModel.remaining)
                }
                if !editMode {
                    VStack(spacing: 4) {
                        if viewModel.title.count > 0 {
                            Text(viewModel.title)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .fontWidth(.expanded)
                                .textCase(.uppercase)
                                .foregroundStyle(.secondary)
                        }
                        
                        VStack {
                            if isResetButtonHovered {
                                // Shown on reset hover: plain opacity/fade without digit-rolling
                                Text(viewModel.durationTimeText)
                                    .font(.system(size: 42, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.5)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .frame(maxWidth: 140)
                                    .transition(.opacity)
                            } else {
                                // Shown during normal countdown: isolated numeric transition
                                Text(viewModel.timeText)
                                    .contentTransition(.numericText(countsDown: true))
                                    .font(.system(size: 42, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.primary)
                                    .monospacedDigit()
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.5)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .frame(maxWidth: 140)
                                    .geometryGroup()
                                    .animation(viewModel.isRunning ? .linear(duration: 0.2) : nil, value: viewModel.timeText)
                                    .transition(.opacity)
                            }
                        }
                        .geometryGroup()
                        .animation(.easeInOut(duration: 0.15), value: isResetButtonHovered)
                        
                        
                        if isHovered {
                            GlassEffectContainer(spacing: 4) {
                                HStack(alignment: .center, spacing: 4) {
                                    if viewModel.timerState != .finished {
                                        Button {
                                            viewModel.startPause()
                                        } label: {
                                            Image(systemName: viewModel.isRunning ? "pause.fill" : "play.fill")
                                                .fontWeight(.black)
                                                .font(.system(size: 16))
                                                .contentTransition(.symbolEffect(.replace.byLayer))
                                                .frame(width: 24, height: 24)
                                                .fixedSize()
                                                .padding(8)
                                        }
                                        .controlSize(.regular)
                                        .buttonStyle(.borderedProminent)
                                        .buttonBorderShape(.circle)
                                        .glassEffectID("playpause", in: namespace)
                                    }
                                    
                                    if viewModel.timerState != .idle {
                                        Button {
                                            viewModel.reset()
                                        } label: {
                                            Image(systemName: viewModel.timerState != .finished ? "stop.fill" : "arrow.clockwise")
                                                .fontWeight(.black)
                                                .font(.system(size: 16))
                                                .contentTransition(.symbolEffect(.replace.byLayer))
                                                .frame(width: 24, height: 24)
                                                .fixedSize()
                                                .padding(8)
                                        }
                                        .controlSize(.regular)
                                        .buttonStyle(.bordered)
                                        .buttonBorderShape(.circle)
                                        .glassEffectID("stoprepeat", in: namespace)
                                        .onHover { hovering in
                                            if !viewModel.isRunning {
                                                isResetButtonHovered = hovering
                                            }
                                        }
                                    }
                                    
                                    if viewModel.timerState == .finished || viewModel.timerState == .idle {
                                        Button {
                                            withAnimation(.easeInOut(duration: 0.15)) {
                                                editMode.toggle()
                                            }
                                        } label: {
                                            Image(systemName: "square.and.pencil")
                                                .fontWeight(.black)
                                                .font(.system(size: 16))
                                                .contentTransition(.symbolEffect(.replace.byLayer))
                                                .frame(width: 24, height: 24)
                                                .fixedSize()
                                                .padding(8)
                                                .offset(x: 0.5, y: -1)
                                        }
                                        .controlSize(.regular)
                                        .buttonStyle(.bordered)
                                        .buttonBorderShape(.circle)
                                        .glassEffectID("edit", in: namespace)
                                    }
                                    
                                    Button(role: .destructive) {
                                        onDelete?()
                                    } label: {
                                        Image(systemName: "xmark")
                                            .fontWeight(.black)
                                            .font(.system(size: 16))
                                            .frame(width: 24, height: 24)
                                            .fixedSize()
                                            .padding(8)
                                    }
                                    .controlSize(.regular)
                                    .buttonStyle(.borderedProminent)
                                    .buttonBorderShape(.circle)
                                    .tint(Color(.systemRed))
                                    .glassEffectID("remove", in: namespace)
                                }
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                                .padding(.top, 8)
                                
                            }
                        }
                    }
                    .padding()
                } else {
                    VStack {
                        HStack(alignment: .center) {
                            Text("Change Timer")
                                .textCase(.uppercase)
                                .font(.caption)
                                .fontWeight(.medium)
                                .fontWidth(.expanded)
                            Spacer()
                            Button {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    editMode.toggle()
                                }
                            } label: {
                                Image(systemName: "xmark")
                                    .fontWeight(.bold)
                            }
                            .buttonStyle(.bordered)
                            .buttonBorderShape(.roundedRectangle)
                            .padding(.bottom, 8)
                        }
                        
                        ScrollView(.vertical) {
                            LazyVGrid(columns: columnLayout, pinnedViews: [.sectionHeaders]) {
                                ForEach(minutes, id: \.description) { preset in
                                    TimerPresetCell(preset) { time in
                                        withAnimation(.easeInOut(duration: 0.15)) {
                                            editMode.toggle()
                                        }
                                        viewModel.updateTimer(time: time)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .cornerRadius(4)
                        }
                        .scrollBounceBehavior(.basedOnSize, axes: .vertical)
                    }
                    .frame(width: 160, height: 160)
                }
            }
            .frame(minWidth: 220, minHeight: 220)
            .glassEffect(.regular, in: .rect(cornerRadius: 32.0))
            .onHover { hovering in
                isHovered = hovering
                
            }
            .animation(.easeInOut(duration: 0.15), value: isHovered)
            .onChange(of: viewModel.editRequestToken) { _, _ in
                withAnimation(.easeInOut(duration: 0.15)) {
                    editMode = true
                }
            }
        }
    }
    
    // MARK: - Rounded-square tick placement
    
    private struct PathSample {
        let point: CGPoint
        let tangentAngle: Angle
    }
    
    
}

struct RoundedRectRing: Shape {
    var cornerRadius: CGFloat
    var innerInset: CGFloat
    var innerCornerRadius: CGFloat
    
    func path(in rect: CGRect) -> Path {
        let outer = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .path(in: rect)
        
        let innerRect = rect.insetBy(dx: innerInset, dy: innerInset)
        let inner = RoundedRectangle(cornerRadius: innerCornerRadius, style: .continuous)
            .path(in: innerRect)
        
        var p = Path()
        p.addPath(outer)
        p.addPath(inner)
        return p
    }
}

extension TimerView {
    private func roundedRectPoint(at t: Double, in rect: CGRect, cornerRadius: CGFloat) -> CGPoint {
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
    
    private func topCenterStartOffset(in rect: CGRect, cornerRadius: CGFloat) -> Double {
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
    
    private var secondsProgress: Double {
        guard viewModel.duration > 0 else { return 0 }
        return max(0, min(1, viewModel.remaining / viewModel.duration))
    }
    
    private func activeColor(for normalizedTick: Double) -> Color {
        // 0...1 along the active ring after shifting
        let t = max(0, min(1, normalizedTick))
        
        // Smoothstep (S-curve): very smooth at both ends
        let s = t * t * (3 - 2 * t)
        
        // Optional extra softening
        let eased = pow(s, 0.9)
        
        // Tail -> head opacity range
        let minOpacity = 0.28
        let maxOpacity = 1.0
        let opacity = minOpacity + (maxOpacity - minOpacity) * eased
        
        return Color.white.opacity(opacity)
    }
    
    private var headPhase: Double {
        let remaining = max(0, viewModel.remaining)
        let secondsIntoCurrentMinute = remaining.truncatingRemainder(dividingBy: 60)
        let progress = secondsIntoCurrentMinute / 60.0
        return progress
    }
    
    private var fractionalTickPhase: Double {
        // how far the head is between two ticks
        let x = headPhase * Double(tickCount)
        return x - floor(x)
    }
    
    private func wrappedDistanceForward(from a: Double, to b: Double) -> Double {
        // clockwise/forward distance on [0,1)
        let d = b - a
        return d >= 0 ? d : d + 1
    }
    
    private func tickOpacity(for tickPhase: Double) -> Double {
        // Base opacity for inactive background ticks
        let base = 0.10
        if viewModel.remaining <= 0 { return 0.1 }
        
        // Trail behind head (comet tail)
        // "Behind" means from tick -> head in forward direction is small.
        let dToHead = wrappedDistanceForward(from: tickPhase, to: headPhase)
        let trailLength = 1.0 // portion of ring used for trail
        var trail = max(0, 1 - dToHead / trailLength)
        let isLastMinute = viewModel.remaining < 60
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

#Preview {
    TimerView(viewModel: TimerViewModel(model: TimerModel(title: "Focus", duration: 5)))
        .frame(width: 220, height: 220)
}
