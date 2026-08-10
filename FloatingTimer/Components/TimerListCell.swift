//
//  TimerListCell.swift
//  FloatingTimer
//
//  Created by Christopher Susandji on 03/08/26.
//

import SwiftUI

struct TimerListCell: View {
    var viewModel: TimerViewModel
    var onDelete: (() -> Void)?
    
    var body: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.title.isEmpty ? "UNTITLED" : viewModel.title )
                    
                        .font(.system(.caption, design: .default))
                        .fontWeight(.medium)
                        .fontWidth(.expanded)
                        .foregroundStyle(.secondary)
                
                Text(viewModel.timeText)
                    .font(.system(.title, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(viewModel.isRunning ? .primary : .secondary)
                
            }
            Spacer()
            ControlGroup {
                Button {
                    viewModel.startPause()
                } label: {
                    Image(systemName: viewModel.isRunning ? "pause.fill" : "play.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 16, height: 16)
                        .padding(8)
                }
                .tint(Color(.systemGreen))
                
                Button {
                    viewModel.reset()
                } label: {
                    Image(systemName: viewModel.isRunning ? "stop.fill" : "arrow.clockwise")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 16, height: 16)
                        .padding(8)
                }
                
                Button(role: .destructive) {
                    onDelete?()
                    FloatingTimerManager.shared.closeTimer(viewModel.id)
                } label: {
                    Image(systemName: "trash.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 16, height: 16)
                        .padding(8)
                }.tint(Color(.systemRed))
            }
            .controlGroupStyle(.automatic)
            .transition(.opacity.combined(with: .move(edge: .bottom)))
            
        }
        .padding(4)
    }
}
