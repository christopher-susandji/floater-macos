//
//  TimerControls.swift
//  FloatingTimer
//
//  Created by Christopher Susandji on 20/08/26.
//

import SwiftUI

/// The controls a floating timer panel shows while it is hovered: play/pause,
/// stop or replay, edit and delete. The list row has its own compact control
/// view, so the panel's theming is all this configuration carries.
struct TimerControls: View {
    struct Configuration {
        var transition: AnyTransition?
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
    var configuration: Configuration = .init()
    var onPlayPause: () -> Void
    var onReset: () -> Void
    var onEdit: () -> Void
    var onDelete: () -> Void
    var onResetHover: ((Bool) -> Void)?
    
    /// Unlike the list row, the panel only offers its edit screen once the
    /// timer is stopped: idle or finished, never while paused.
    private var showsEditButton: Bool {
        viewModel.timerState == .idle || viewModel.timerState == .finished
    }
    
    var body: some View {
        GlassEffectContainer(spacing: Sizing.sm) {
            HStack(spacing: Sizing.sm) {
                if viewModel.timerState != .finished {
                    Button {
                        onPlayPause()
                    } label: {
                        TimerControlGlyph(
                            systemName: viewModel.isRunning ? "pause.fill" : "play.fill",
                            frame: 20
                        )
                        .foregroundStyle(configuration.prominentButton.foregroundColor ?? .white)
                    }
                    .modifier(ProminentButtonStyle(configuration: configuration))
                    .glassEffectID("playpause", in: namespace)
                }
                
                if viewModel.timerState != .idle {
                    Button {
                        onReset()
                    } label: {
                        TimerControlGlyph(
                            systemName: viewModel.timerState != .finished ? "stop.fill" : "arrow.clockwise",
                            frame: 20
                        )
                    }
                    .modifier(SecondaryButtonStyle(configuration: configuration))
                    .buttonBorderShape(.circle)
                    .glassEffectID("stoprepeat", in: namespace)
                    .onHover { hovering in
                        onResetHover?(hovering)
                    }
                }
                
                if showsEditButton {
                    Button {
                        onEdit()
                    } label: {
                        TimerControlGlyph(systemName: "pencil", frame: 20)
                    }
                    .modifier(SecondaryButtonStyle(configuration: configuration))
                    .buttonBorderShape(.circle)
                    .glassEffectID("edit", in: namespace)
                }
                
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    TimerControlGlyph(systemName: "xmark", frame: 20)
                }
                .modifier(SecondaryButtonStyle(configuration: configuration))
                .glassEffectID("remove", in: namespace)
            }
            .modifier(OptionalTransition(transition: configuration.transition))
        }
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
                .tint(configuration.prominentButton.backgroundColor ?? configuration.accentColor)
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

#Preview {
    ClassicTimerView(viewModel: TimerViewModel(model: TimerModel(title: "Focus", duration: 5)))
        .frame(width: 220, height: 220)
}

#Preview {
    VintageTimerView(viewModel: TimerViewModel(model: TimerModel(title: "Focus", duration: 5, type: .vintageDefault)))
        .frame(width: 220, height: 220)
}
