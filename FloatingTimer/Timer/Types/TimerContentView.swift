//
//  TimerContentView.swift
//  FloatingTimer
//
//  Created by Christopher Susandji on 27/08/26.
//

import SwiftUI

/// Common contract for every timer type variant. Each variant is built from
/// the same `TimerViewModel` and exposes the same delete hook, so the
/// dispatcher and the manager can treat all timer types uniformly.
protocol TimerContentView: View {
    init(viewModel: TimerViewModel, onDelete: (() -> Void)?, onEdit: (() -> Void)?)
}