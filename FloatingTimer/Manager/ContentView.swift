//
//  ContentView.swift
//  FloatingTimer
//
//  Created by Christopher Susandji on 27/07/26.
//

import SwiftUI

struct ContentView: View {
    @Environment(AppViewModel.self) private var appViewModel
    
    @State private var title: String = ""
    @State private var hours: Int = 0
    @State private var minutes: Int = 0
    @State private var seconds: Int = 0
    
    @FocusState private var focusedField: TimeField?
    @State private var isCreateButtonHovering = false
    @State private var selectedType: TimerType = .classicDefault
    
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
    
    private func createTimer() {
        if let timer = appViewModel.createTimer(
            title: title,
            seconds: totalSeconds,
            type: selectedType
        ) {
            FloatingTimerManager.shared.showTimer(timer, in: appViewModel)
        }
    }
    
    @ViewBuilder
    private var timerTitleField: some View {
        TextField("", text: $title)
            .overlay(alignment: .center) {
                if title.isEmpty {
                    Text(Constants.timerTitle)
                        .foregroundStyle(.tertiary)
                        .allowsHitTesting(false)
                }
            }
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
            .onKeyPress(.return) {
                focusedField = .minutes
                return .handled
            }
    }
    
    @ViewBuilder
    private var timerPicker: some View {
        HStack(alignment: .center, spacing: 0) {
            // HOURS FIELD
            TimeTextField(
                value: $hours,
                max: 23,
                onMoveRight: { focusedField = .minutes },
                onEnter: { createTimer() }
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
                onMoveRight: { focusedField = .seconds },
                onEnter: { createTimer() }
            ).focused($focusedField, equals: .minutes)
            
            // SEPARATOR
            Text(":")
                .font(.system(size: 48, weight: .light, design: .rounded))
                .foregroundStyle(.secondary)
            
            TimeTextField(
                value: $seconds, max: 59,
                onMoveLeft: { focusedField = .minutes },
                onEnter: { createTimer() }
            )
            .focused($focusedField, equals: .seconds)
        }
    }
    
    @ViewBuilder
    private var createTimerButton: some View {
        Button(Constants.createTimerButton) {
            createTimer()
        }
        .fontWidth(.expanded)
        .buttonStyle(.glass)
        .buttonBorderShape(.roundedRectangle)
        .buttonSizing(.fitted)
        .controlSize(.large)
        .tint(selectedAccent)
        .disabled(!(appViewModel.canCreateTimer && isNotEmpty))
        .scaleEffect(isCreateButtonHovering ? 1.08 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.45), value: isCreateButtonHovering)
        .onHover { hovering in
            if appViewModel.canCreateTimer && isNotEmpty {
                isCreateButtonHovering = hovering
            }
        }
    }

    @ViewBuilder
    private var themePicker: some View {
        HStack(spacing: Sizing.sm) {
            Menu {
                ForEach(TypeCatalog.all, id: \.self) { type in
                    Button(type.name) {
                        selectedType = type
                    }
                }
            } label: {
                HStack(spacing: Sizing.xs) {
                    Image(systemName: "paintbrush.pointed.fill")
                    Text(selectedType.name)
                }
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(selectedAccent)
            }
            .menuStyle(.borderedButton)
            .fixedSize()

            themeSwatches
        }
    }

    @ViewBuilder
    private var themeSwatches: some View {
        switch selectedType {
        case .classic:
            swatchPicker(for: selectedType)
        case .vintage:
            EmptyView()
        }
    }

    @ViewBuilder
    private func swatchPicker(for type: TimerType) -> some View {
        HStack(spacing: Sizing.xs) {
            ForEach(ThemeCatalog.classicPresets) { theme in
                Button {
                    selectedType = Self.withTheme(theme, for: type)
                } label: {
                    Circle()
                        .fill(theme.palette.accent.color)
                        .frame(width: 12, height: 12)
                        .overlay {
                            Circle()
                                .strokeBorder(
                                    isSelected(theme) ? Color.white : Color.white.opacity(0.25),
                                    lineWidth: isSelected(theme) ? 2 : 1
                                )
                        }
                }
                .buttonStyle(.plain)
                .help(theme.name)
            }
        }
    }

    private static func withTheme(_ theme: ClassicTheme, for type: TimerType) -> TimerType {
        switch type {
        case .classic: return .classic(theme: theme)
        case .vintage: return type
        }
    }

    private var selectedAccent: Color {
        switch selectedType {
        case .classic(let theme): return theme.palette.accent.color
        case .vintage(let theme): return theme.palette.accent.color
        }
    }

    private func isSelected(_ theme: ClassicTheme) -> Bool {
        switch selectedType {
        case .classic(let current): return current == theme
        case .vintage: return false
        }
    }
    
    var body: some View {
        VStack(alignment: .center, spacing: Sizing.xxl) {
            VStack(alignment: .center, spacing: Sizing.lg) {
                VStack(spacing: Sizing.sm) {
                    timerTitleField
                    timerPicker
                }
                
                createTimerButton
            }
            .font(.system(.title2, design: .rounded, weight: .semibold))
            .padding(.vertical, Sizing.sm)
            
            if !appViewModel.timerViewModels.isEmpty {
                VStack(spacing: Sizing.sm) {
                    ForEach(Array(appViewModel.timerViewModels.enumerated()), id: \.offset) { index, viewModel in
                        TimerListCell(viewModel: viewModel, onDelete: { appViewModel.removeTimer(id: viewModel.id) })
                        
                        if index < appViewModel.timerViewModels.count - 1 {
                            Divider()
                        }
                    }
                }
                .padding(Sizing.sm)
                .background(RoundedRectangle(cornerRadius: 12).fill(.thickMaterial))
            }
        }
        .padding(Sizing.xl)
        .contentShape(Rectangle())
        .onTapGesture {
            NSApp.keyWindow?.makeFirstResponder(nil)
        }
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
