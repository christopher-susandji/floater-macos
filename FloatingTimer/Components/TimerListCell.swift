//
//  TimerListCell.swift
//  FloatingTimer
//
//  Created by Christopher Susandji on 03/08/26.
//

import SwiftUI

struct TimerListCell: View {
    @Bindable var viewModel: TimerViewModel
    var onDelete: (() -> Void)?
    @Namespace private var namespace
    
    @FocusState private var isTitleFocused: Bool
    
    private let characterLimit = 16
    
    var body: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                TextField("UNTITLED", text: $viewModel.title)
                    .textFieldStyle(.plain)
                    .font(.system(.caption, design: .default))
                    .fontWeight(.medium)
                    .fontWidth(.expanded)
                    .foregroundStyle(isTitleFocused ? .primary : .secondary)
                    .focused($isTitleFocused)
                    .onChange(of: viewModel.title) { oldValue, newValue in
                        if newValue.count > characterLimit {
                            viewModel.title = String(newValue.prefix(characterLimit))
                        } else {
                            viewModel.title = newValue.uppercased()
                        }
                    }
                
                Text(viewModel.timeText)
                    .contentTransition(.numericText(countsDown: true))
                    .font(.system(.title, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(viewModel.isRunning ? .primary : .secondary)
                    .animation(viewModel.isRunning ? .linear(duration: 0.2) : nil, value: viewModel.timeText)
                    .transition(.opacity)
            }
            
            Spacer()
            
            GlassEffectContainer(spacing: 4) {
                HStack(spacing: 4) {
                    Button {
                        viewModel.startPause()
                    } label: {
                        Image(systemName: viewModel.isRunning ? "pause.fill" : "play.fill")
                            .fontWeight(.black)
                            .font(.system(size: 12))
                            .frame(width: 16, height: 16)
                            .fixedSize()
                            .padding(4)
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.circle)
                    .tint(Color.accentColor)
                    .glassEffectID("playpause", in: namespace)
                    
                    if viewModel.timerState != .idle {
                        Button {
                            viewModel.reset()
                        } label: {
                            Image(systemName: viewModel.timerState != .finished ? "stop.fill" : "arrow.clockwise")
                                .fontWeight(.black)
                                .font(.system(size: 12))
                                .frame(width: 16, height: 16)
                                .fixedSize()
                                .padding(4)
                        }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.circle)
                        .glassEffectID("stoprepeat", in: namespace)
                    }
                    
                    if viewModel.timerState == .finished || viewModel.timerState == .idle {
                        Button {
                            FloatingTimerManager.shared.focusTimer(viewModel.id)
                            viewModel.requestEditMode()
                        } label: {
                            Image(systemName: "square.and.pencil")
                                .fontWeight(.black)
                                .font(.system(size: 12))
                                .frame(width: 16, height: 16)
                                .fixedSize()
                                .padding(4)
                        }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.circle)
                        .glassEffectID("edit", in: namespace)
                    }
                    
                    Button(role: .destructive) {
                        onDelete?()
                        FloatingTimerManager.shared.closeTimer(viewModel.id)
                    } label: {
                        Image(systemName: "trash.fill")
                            .fontWeight(.black)
                            .font(.system(size: 12))
                            .frame(width: 16, height: 16)
                            .fixedSize()
                            .padding(4)
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.circle)
                    .tint(Color(.systemRed))
                    .glassEffectID("remove", in: namespace)
                }
                
            }
        }
        .padding(4)
        .contentShape(Rectangle())
        .onTapGesture {
            isTitleFocused = false
        }
    }
}
