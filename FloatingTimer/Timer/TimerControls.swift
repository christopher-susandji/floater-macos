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
        /// When `true`, buttons use the themed `prominentButton`/`secondaryButton`
        /// styling. When `false`, buttons use the plain system button styles.
        var themed: Bool = false
        var accentColor: Color = Color.accentColor
        var prominentButton: ButtonConfiguration = .init()
        var secondaryButton: ButtonConfiguration = .init()
        var buttonShadow: Bool = false
    }
    
    struct ButtonConfiguration {
        var backgroundColor: Color?
        var foregroundColor: Color?
        var borderColor: Color?
        var borderWidth: CGFloat = 0
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
                            .foregroundStyle(configuration.prominentButton.foregroundColor ?? .white)
                    }
                    .if(configuration.style == .regular) {
                        $0.modifier(ProminentButtonStyle(configuration: configuration))
                    }
                    .if(configuration.style == .compact) { $0.buttonStyle(.plain).foregroundStyle(configuration.accentColor) }
                    
                    .glassEffectID("playpause", in: namespace)
                    
                    if configuration.style == .compact { Divider().frame(height: 12) }
                }
                
                if viewModel.timerState != .idle {
                    Button {
                        onReset()
                    } label: {
                        icon(systemName: viewModel.timerState != .finished ? "stop.fill" : "arrow.clockwise")
                    }
                    .if(configuration.style == .regular) {
                        $0.modifier(SecondaryButtonStyle(configuration: configuration))
                    }
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
                        icon(systemName: "pencil")
                    }
                    .if(configuration.style == .regular) {
                        $0.modifier(SecondaryButtonStyle(configuration: configuration))
                    }
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
                    $0.modifier(SecondaryButtonStyle(configuration: configuration))
                }
                .if(configuration.style == .compact) {
                    $0.buttonStyle(.plain)
                }
                .glassEffectID("remove", in: namespace)
            }
            .modifier(OptionalTransition(transition: configuration.transition))
            .if(configuration.style == .compact, transform: {
                $0.padding(2)
                    .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 8))
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

/// Styling for the prominent (play/pause) button. Uses the themed
/// configuration when enabled, otherwise the plain system style.
private struct ProminentButtonStyle: ViewModifier {
    var configuration: TimerControls.Configuration

    func body(content: Content) -> some View {
        if configuration.themed {
            content
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.circle)
                .tint(configuration.prominentButton.backgroundColor ?? configuration.accentColor)
                .overlay {
                    Group {
                        if let border = configuration.prominentButton.borderColor {
                            Circle()
                                .strokeBorder(border, lineWidth: configuration.prominentButton.borderWidth)
                        }
                    }
                    .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                    .allowsHitTesting(false)
                }
                .modifier(ButtonShadowModifier(isEnabled: configuration.buttonShadow))
        } else {
            content
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.circle)
                .modifier(ButtonShadowModifier(isEnabled: configuration.buttonShadow))
        }
    }
}

/// Styling for the secondary (reset/edit/delete) buttons. Uses the themed
/// configuration when enabled, otherwise the plain system style.
private struct SecondaryButtonStyle: ViewModifier {
    var configuration: TimerControls.Configuration

    func body(content: Content) -> some View {
        if configuration.themed {
            content
                .buttonStyle(.bordered)
                .buttonBorderShape(.circle)
                .tint(configuration.secondaryButton.foregroundColor ?? configuration.accentColor)
                .background {
                    Circle()
                        .fill(configuration.secondaryButton.backgroundColor ?? Color.clear)
                }
                .overlay {
                    Group {
                        if let border = configuration.secondaryButton.borderColor {
                            Circle()
                                .strokeBorder(border, lineWidth: configuration.secondaryButton.borderWidth)
                        }
                    }
                    .allowsHitTesting(false)
                }
                .modifier(ButtonShadowModifier(isEnabled: configuration.buttonShadow))
        } else {
            content
                .buttonStyle(.bordered)
                .buttonBorderShape(.circle)
                .modifier(ButtonShadowModifier(isEnabled: configuration.buttonShadow))
        }
    }
}

/// Applies a drop shadow to a control button when enabled.
private struct ButtonShadowModifier: ViewModifier {
    var isEnabled: Bool

    func body(content: Content) -> some View {
        if isEnabled {
            content
                .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
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

#Preview {
    VintageTimerView(viewModel: TimerViewModel(model: TimerModel(title: "Focus", duration: 5, type: .vintageDefault)))
        .frame(width: 220, height: 220)
}
