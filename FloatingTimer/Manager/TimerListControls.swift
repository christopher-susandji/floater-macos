//
//  TimerListControls.swift
//  FloatingTimer
//
//  Created by Christopher Susandji on 18/11/26.
//

import SwiftUI

/// The compact control row in a timer list cell: play/pause, stop, the pencil
/// and delete, minus whichever the cell's state can't use. Kept apart from the
/// floating panel's `TimerControls` so the panel's theming and the list's
/// state rules don't share one growing configuration.
struct TimerListControls: View {
    var viewModel: TimerViewModel
    var namespace: Namespace.ID
    var accentColor: Color
    /// While the duration fields are open the row offers a revert in place of
    /// the pencil, and a paused timer drops its stop button.
    var isEditingDuration: Bool
    var onPlayPause: () -> Void
    var onStop: () -> Void
    var onToggleEdit: () -> Void
    var onDelete: () -> Void
    
    private var showsStop: Bool {
        guard viewModel.timerState != .idle else { return false }
        // Stopping mid-edit would throw the typed duration away, so the revert
        // button does that job instead.
        return !(viewModel.timerState == .paused && isEditingDuration)
    }
    
    private var showsEdit: Bool {
        switch viewModel.timerState {
        case .running:
            return false
        case .paused:
            // A paused cell keeps three buttons, except while its fields are
            // open and the revert button has to be reachable.
            return isEditingDuration
        case .idle, .finished:
            return true
        }
    }
    
    var body: some View {
        GlassEffectContainer(spacing: Sizing.xxs) {
            HStack(spacing: Sizing.xxs) {
                if viewModel.timerState != .finished {
                    Button {
                        onPlayPause()
                    } label: {
                        TimerControlGlyph(
                            systemName: viewModel.isRunning ? "pause.fill" : "play.fill",
                            frame: 16
                        )
                        .foregroundStyle(accentColor)
                    }
                    .buttonStyle(.plain)
                    .glassEffectID("playpause", in: namespace)
                    
                    divider
                }
                
                if showsStop {
                    Button {
                        onStop()
                    } label: {
                        TimerControlGlyph(
                            systemName: viewModel.timerState != .finished ? "stop.fill" : "arrow.clockwise",
                            frame: 16
                        )
                    }
                    .buttonStyle(.plain)
                    .buttonBorderShape(.circle)
                    .glassEffectID("stoprepeat", in: namespace)
                    
                    divider
                }
                
                if showsEdit {
                    Button {
                        onToggleEdit()
                    } label: {
                        TimerControlGlyph(
                            systemName: isEditingDuration ? "arrow.uturn.backward" : "pencil",
                            frame: 16
                        )
                    }
                    .buttonStyle(.plain)
                    .buttonBorderShape(.circle)
                    .glassEffectID("edit", in: namespace)
                    
                    divider
                }
                
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    TimerControlGlyph(systemName: "xmark", frame: 16)
                }
                .buttonStyle(.plain)
                .glassEffectID("remove", in: namespace)
            }
            .padding(2)
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 8))
        }
    }
    
    private var divider: some View {
        Divider().frame(height: 12)
    }
}

#Preview("Idle") {
    @Previewable @Namespace var namespace

    TimerListControls(
        viewModel: TimerViewModel(model: TimerModel(title: "Focus", duration: 300)),
        namespace: namespace,
        accentColor: .accentColor,
        isEditingDuration: false,
        onPlayPause: {},
        onStop: {},
        onToggleEdit: {},
        onDelete: {}
    )
    .padding()
}

#Preview("Editing") {
    @Previewable @Namespace var namespace

    TimerListControls(
        viewModel: TimerViewModel(model: TimerModel(title: "Focus", duration: 300)),
        namespace: namespace,
        accentColor: .accentColor,
        isEditingDuration: true,
        onPlayPause: {},
        onStop: {},
        onToggleEdit: {},
        onDelete: {}
    )
    .padding()
}
