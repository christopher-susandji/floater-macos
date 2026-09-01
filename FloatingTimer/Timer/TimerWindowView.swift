//
//  TimerWindowView.swift
//  FloatingTimer
//
//  Created by Christopher Susandji on 27/07/26.
//

import SwiftUI

struct TimerWindowView: View {
    @Environment(AppViewModel.self) private var appViewModel
    let timerID: UUID?

    var body: some View {
        Group {
            if let timerID, let timer = appViewModel.timerViewModel(id: timerID) {
                TimerView(viewModel: timer)
            } else {
                Text("Timer not found")
                    .padding(Sizing.lg)
            }
        }
    }
}
