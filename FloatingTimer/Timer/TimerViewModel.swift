//
//  TimerViewModel.swift
//  FloatingTimer
//
//  Created by Christopher Susandji on 27/07/26.
//

import Foundation
import Observation
import SwiftUI

/// View-facing wrapper around `TimerEngine`. Owns presentation concerns
/// (animation, edit-mode requests) and exposes the timer's type/theme.
@MainActor
@Observable
final class TimerViewModel {
    var model: TimerModel

    /// Bumped whenever something external (e.g. the timer list) requests that this
    /// timer's floating panel open its preset-editing screen. `TimerView` observes
    /// this via `.onChange` and toggles its own local `editMode` state.
    var editRequestToken: Int = 0

    @ObservationIgnored
    private let engine: TimerEngine

    init(model: TimerModel) {
        self.model = model
        self.engine = TimerEngine(duration: model.duration, chimeResourceName: model.type.chimeResourceName)
    }

    var id: UUID { model.id }

    var title: String {
        get { model.title }
        set { model.title = newValue }
    }

    var duration: TimeInterval { model.duration }

    var type: TimerType { model.type }

    var accentColor: Color { type.accentColor }
    var textPrimary: Color { type.textPrimaryColor }
    var textSecondary: Color { type.textSecondaryColor }

    // - MARK: Edit-mode options

    /// The timer families (classic/vintage) shown in the edit-mode type picker.
    var typeOptions: [TypeOption] {
        TypeCatalog.all.map { type in
            TypeOption(
                name: type.name,
                isSelected: type.isSameKind(as: self.type),
                onSelect: {
                    switch type {
                    case .classic: self.updateType(.classicDefault)
                    case .vintage: self.updateType(.vintageDefault)
                    }
                }
            )
        }
    }

    /// The theme swatches shown in the edit-mode picker, driven by the current type.
    var themeOptions: [ThemeOption] {
        switch type {
        case .classic(let current):
            return ThemeCatalog.classicPresets.map { preset in
                ThemeOption(
                    id: preset.id,
                    name: preset.name,
                    color: preset.palette.accent.color,
                    isSelected: preset == current,
                    onSelect: { self.updateType(.classic(theme: preset)) }
                )
            }
        case .vintage(let current):
            return ThemeCatalog.vintagePresets.map { preset in
                ThemeOption(
                    id: preset.id,
                    name: preset.name,
                    color: preset.palette.accent.color,
                    isSelected: preset == current,
                    onSelect: { self.updateType(.vintage(theme: preset)) }
                )
            }
        }
    }

    // - MARK: Engine state (forwarded for Observation tracking)

    var remaining: TimeInterval { engine.remaining }
    var isRunning: Bool { engine.isRunning }
    var timerState: TimerEngine.State { engine.timerState }

    var timeText: String { engine.timeText }
    var durationTimeText: String { engine.durationTimeText }
    var initialTimeText: String { engine.initialTimeText }

    func updateTimer(time: TimeInterval) {
        model = .init(id: model.id, title: model.title, duration: time, type: model.type)
        engine.update(duration: time)
    }

    /// Swaps the timer's theme/type without touching its title or duration.
    func updateType(_ type: TimerType) {
        model = .init(id: model.id, title: model.title, duration: model.duration, type: type)
        engine.setChime(type.chimeResourceName)
    }

    /// Requests that this timer's floating panel open its preset-editing screen.
    func requestEditMode() {
        editRequestToken += 1
    }

    func startPause() {
        withAnimation(.easeInOut) {
            engine.startPause()
        }
        editRequestToken = 0
    }

    func reset() {
        withAnimation(.easeInOut) {
            engine.reset()
        }
    }
}