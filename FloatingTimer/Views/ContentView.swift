//
//  ContentView.swift
//  FloatingTimer
//
//  Created by Christopher Susandji on 27/07/26.
//

import SwiftUI
import AudioToolbox

struct ContentView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @Environment(\.openWindow) private var openWindow
    
    @State private var title: String = ""
    @State private var hours: Int = 0
    @State private var minutes: Int = 0
    @State private var seconds: Int = 0
    @State private var presetMode: Bool = false
    
    @FocusState private var focusedField: TimeField?
    
    enum TimeField {
        case title, hours, minutes, seconds
    }
    
    private let characterLimit = 16
    
    private var totalSeconds: Int {
        hours * 3600 + minutes * 60 + seconds
    }
    
    private var isNotEmpty: Bool {
        hours != 0 || minutes != 0 || seconds != 0
    }
    
    var body: some View {
        VStack(alignment: .center, spacing: 32) {
            VStack(alignment: .center, spacing: 32) {
                VStack(spacing: 8) {
                    
                    TextField("TIMER TITLE", text: $title)
                        .textCase(.uppercase)
                        .font(.system(.headline, design: .default, weight: .heavy))
                        .fontWidth(.expanded)
                        .multilineTextAlignment(.center)
                        .textFieldStyle(.plain)
                        .focused($focusedField, equals: .title)
                        .onChange(of: title) { oldValue, newValue in
                            if newValue.count > characterLimit {
                                title = String(newValue.prefix(characterLimit))
                            } else {
                                title = newValue.uppercased()
                            }
                        }
                    
                    HStack(alignment: .center, spacing: 0) {
                        // HOURS FIELD
                        TimeTextField(
                            value: $hours,
                            max: 23,
                            onMoveRight: { focusedField = .minutes }
                        )
                        .focused($focusedField, equals: .hours)
                        
                        // SEPARATOR
                        Text(":")
                            .font(.system(size: 48, weight: .light, design: .rounded))
                            .foregroundStyle(.secondary)
                            .padding(0)
                        
                        TimeTextField(
                            value: $minutes, max: 59,
                            onMoveLeft: { focusedField = .hours },
                            onMoveRight: { focusedField = .seconds }
                        ).focused($focusedField, equals: .minutes)
                        
                        // SEPARATOR
                        Text(":")
                            .font(.system(size: 48, weight: .light, design: .rounded))
                            .foregroundStyle(.secondary)
                        
                        TimeTextField(
                            value: $seconds, max: 59,
                            onMoveLeft: { focusedField = .minutes }
                        )
                        .focused($focusedField, equals: .seconds)
                    }
                }
                
                Button("Create Timer") {
                    let timer = appViewModel.createTimer(
                        title: title,
                        seconds: totalSeconds
                    )
                    FloatingTimerManager.shared.showTimer(timer, in: appViewModel)
                }
                .fontWidth(.expanded)
                .buttonStyle(.glass)
                .buttonBorderShape(.roundedRectangle)
                .buttonSizing(.fitted)
                .controlSize(.large)
                .tint(.orange)
                .disabled(!(appViewModel.canCreateTimer && isNotEmpty))
            }
            .font(.system(.title2, design: .rounded, weight: .semibold))
            .padding(.vertical, 8)
            
            if !appViewModel.timerViewModels.isEmpty {
                VStack(spacing: 8) {
                    ForEach(Array(appViewModel.timerViewModels.enumerated()), id: \.offset) { index, viewModel in
                        TimerListCell(viewModel: viewModel, onDelete: { appViewModel.removeTimer(id: viewModel.id) })
                        
                        if index < appViewModel.timerViewModels.count - 1 {
                            Divider()
                        }
                    }
                }
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 12).fill(.thinMaterial))
            }
        }
        .padding(24)
        
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
        )
        .background(
            WindowAccessor { window in
                guard let window else { return }
                window.isOpaque = false
                window.backgroundColor = .clear
                window.titleVisibility = .hidden
                window.titlebarAppearsTransparent = true
                window.initialFirstResponder = nil
                
                RunLoop.main.perform {
                    focusedField = nil
                }
            }
        )
    }
}

#Preview {
    ContentView()
        .environment(AppViewModel())
        .frame(width: 300, height: 400)
}
