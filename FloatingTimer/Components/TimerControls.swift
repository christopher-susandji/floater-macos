//
//  TimerControls.swift
//  FloatingTimer
//
//  Created by Christopher Susandji on 20/08/26.
//

import SwiftUI

struct TimerControls: View {
    enum Style { case compact, regular }
    
    struct Configuration {
        var style: Style = .regular
        var transition: AnyTransition?
        var topPadding: CGFloat = .zero
    }
    
    var viewModel: TimerViewModel
    var namespace: Namespace.ID
    var configuration: Configuration
    var onPlayPause: () -> Void
    var onReset: () -> Void
    var onEdit: () -> Void
    var onDelete: () -> Void
    var onResetHover: ((Bool) -> Void)?
    
    init(
        viewModel: TimerViewModel,
        namespace: Namespace.ID,
        configuration: Configuration = .init(),
        onPlayPause: @escaping () -> Void,
        onReset: @escaping () -> Void,
        onEdit: @escaping () -> Void,
        onDelete: @escaping () -> Void,
        onResetHover: ((Bool) -> Void)? = nil
    ) {
        self.viewModel = viewModel
        self.namespace = namespace
        self.configuration = configuration
        self.onPlayPause = onPlayPause
        self.onReset = onReset
        self.onEdit = onEdit
        self.onDelete = onDelete
        self.onResetHover = onResetHover
    }
    
    private var iconSize: CGFloat {
        switch configuration.style {
        case .compact: return 12
        case .regular: return 12
        }
    }
    
    private var iconFrame: CGFloat {
        switch configuration.style {
        case .compact: return 16
        case .regular: return 20
        }
    }
    
    private var iconPadding: CGFloat {
        switch configuration.style {
        case .compact: return 4
        case .regular: return 4
        }
    }
    
    var body: some View {
        GlassEffectContainer(spacing: configuration.style == .compact ? Sizing.xxs : Sizing.sm) {
            HStack(spacing: configuration.style == .compact ? Sizing.xxs : Sizing.sm) {
                if viewModel.timerState != .finished {
                    Button {
                        onPlayPause()
                    } label: {
                        icon(systemName: viewModel.isRunning ? "pause.fill" : "play.fill")
                    }
                    .if(configuration.style == .regular) { $0.buttonStyle(.borderedProminent).buttonBorderShape(.circle)
                        .tint(.accentColor) }
                    .if(configuration.style == .compact) { $0.buttonStyle(.plain).foregroundStyle(Color.accentColor) }
                    
                    .glassEffectID("playpause", in: namespace)
                    
                    if configuration.style == .compact { Divider().frame(height: 12) }
                }
                
                if viewModel.timerState != .idle {
                    Button {
                        onReset()
                    } label: {
                        icon(systemName: viewModel.timerState != .finished ? "stop.fill" : "arrow.clockwise")
                    }
                    .if(configuration.style == .regular) { $0.buttonStyle(.bordered).buttonBorderShape(.circle) }
                    .if(configuration.style == .compact) { $0.buttonStyle(.plain) }
                    .buttonBorderShape(.circle)
                    .glassEffectID("stoprepeat", in: namespace)
                    .onHover { hovering in
                        onResetHover?(hovering)
                    }
                    
                    if configuration.style == .compact { Divider().frame(height: 12) }
                }
                
                if viewModel.timerState == .finished || viewModel.timerState == .idle {
                    Button {
                        onEdit()
                    } label: {
                        icon(systemName: "square.and.pencil")
                            .offset(x: configuration.style == .regular ? 0.5 : 0.2, y: configuration.style == .regular ? -1 : -0.5)
                    }
                    .if(configuration.style == .regular) { $0.buttonStyle(.bordered).buttonBorderShape(.circle) }
                    .if(configuration.style == .compact) { $0.buttonStyle(.plain) }
                    .buttonBorderShape(.circle)
                    .glassEffectID("edit", in: namespace)
                    
                    if configuration.style == .compact { Divider().frame(height: 12) }
                }
                
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    icon(systemName: "xmark")
                }
                .if(configuration.style == .regular) {
                    $0.buttonStyle(.borderedProminent)
                        .buttonBorderShape(.circle)
                        .tint(Color(.systemRed))
                }
                .if(configuration.style == .compact) {
                    $0.buttonStyle(.plain)
                        .foregroundStyle(Color(.systemRed))
                }
                .glassEffectID("remove", in: namespace)
            }
            .modifier(OptionalTransition(transition: configuration.transition))
            .if(configuration.style == .compact, transform: {
                $0.padding(4)
                    .background(Capsule(style: .circular).fill(.background))
            })
        }
    }
    
    @ViewBuilder
    private func icon(systemName: String) -> some View {
        Image(systemName: systemName)
            .fontWeight(.black)
            .font(.system(size: iconSize))
            .contentTransition(.symbolEffect(.replace.byLayer))
            .frame(width: iconFrame, height: iconFrame)
            .fixedSize()
            .padding(iconPadding)
    }
}

private struct OptionalTransition: ViewModifier {
    var transition: AnyTransition?
    
    func body(content: Content) -> some View {
        if let transition {
            content.transition(transition)
        } else {
            content
        }
    }
}

extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
