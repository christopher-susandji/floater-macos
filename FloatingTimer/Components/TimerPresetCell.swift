//
//  TimerPresetCell.swift
//  FloatingTimer
//
//  Created by Christopher Susandji on 07/08/26.
//

import SwiftUI

struct TimerPresetCell: View {
    var interval: TimeInterval
    var action: (TimeInterval) -> Void
    
    init(_ interval: TimeInterval, action: @escaping (TimeInterval) -> Void) {
        self.interval = interval
        self.action = action
    }
    
    private var value: String {
        if interval >= 3600 {
            return String(Int(interval/3600))
        } else if interval >= 60 {
            return String(Int(interval/60))
        } else {
            return String(interval)
        }
    }
    
    private var timeLabel: String {
        if interval >= 3600 {
            return "HR"
        } else if interval >= 60 {
            return "MIN"
        } else {
            return "SEC"
        }
    }
    
    var body: some View {
        Button {
            action(interval)
        } label: {
            VStack {
                Text(value)
                    .font(.title)
                    .fontDesign(.monospaced)
                    .fontWeight(.bold)
                    .fontWidth(.expanded)
                Text(timeLabel)
                    .textCase(.uppercase)
                    .font(.caption)
                    .fontWeight(.medium)
                    .fontWidth(.expanded)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonSizing(.flexible)
        .buttonBorderShape(.roundedRectangle)
        .buttonStyle(.glass)
    }
}
