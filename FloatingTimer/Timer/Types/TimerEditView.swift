//
//  TimerEditView.swift
//  FloatingTimer
//
//  Created by Christopher Susandji on 02/09/26.
//

import SwiftUI

/// A theme choice surfaced in the timer's edit mode. Each timer type maps its
/// own theme list onto this value type, so the swatch UI stays shared.
struct ThemeOption: Identifiable {
    let id: UUID
    var name: String
    var color: Color
    var isSelected: Bool
    var onSelect: () -> Void
}

/// A timer family (classic/vintage) choice surfaced in the edit mode.
struct TypeOption: Identifiable {
    var id: String { name }
    var name: String
    var isSelected: Bool
    var onSelect: () -> Void
}

/// Shared "edit" screen for every timer type: header with close button, a type
/// selector, a row of theme swatches and the preset duration grid.
struct TimerEditView: View {
    var headerColor: Color
    var typeOptions: [TypeOption]
    var themeOptions: [ThemeOption]
    var minutes: [TimeInterval]
    var presetAction: (TimeInterval) -> Void
    var closeAction: () -> Void

    private let columnLayout = Array(repeating: GridItem(), count: 2)

    private var selectedTypeName: String {
        typeOptions.first(where: \.isSelected)?.name ?? ""
    }

    var body: some View {
        VStack {
            header
            presetGrid
        }
        .padding(Sizing.sm)
        .frame(width: 180, height: 180)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
        )
    }

    private var header: some View {
        HStack(alignment: .center) {
            Text(Constants.changeTimerButton)
                .textCase(.uppercase)
                .font(.caption)
                .fontWeight(.medium)
                .fontWidth(.expanded)
                .foregroundStyle(headerColor)
            Spacer()
            Button {
                closeAction()
            } label: {
                Image(systemName: "xmark")
                    .fontWeight(.bold)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.roundedRectangle)
            .padding(.bottom, Sizing.sm)
        }
    }
    
    private var themeRow: some View {
        HStack(spacing: Sizing.xs) {
            themeTypeSelector
            themeSwatchSelector
        }
    }

    private var themeTypeSelector: some View {
        Menu {
            ForEach(typeOptions) { option in
                Button(option.name) {
                    option.onSelect()
                }
            }
        } label: {
            HStack(spacing: Sizing.xs) {
                Image(systemName: "paintbrush.pointed.fill")
                Text(selectedTypeName)
            }
            .font(.caption)
            .fontWeight(.medium)
        }
        .menuStyle(.borderedButton)
        .fixedSize()
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, Sizing.xs)
    }

    private var themeSwatchSelector: some View {
        HStack(spacing: Sizing.xs) {
            ForEach(themeOptions) { option in
                Button {
                    option.onSelect()
                } label: {
                    Circle()
                        .fill(option.color)
                        .frame(width: 12, height: 12)
                        .overlay {
                            Circle()
                                .strokeBorder(
                                    option.isSelected ? Color.white : Color.white.opacity(0.25),
                                    lineWidth: option.isSelected ? 2 : 1
                                )
                        }
                }
                .buttonStyle(.plain)
                .help(option.name)
            }
        }
    }

    private var presetGrid: some View {
        ScrollView(.vertical) {
            themeRow
            LazyVGrid(columns: columnLayout, pinnedViews: [.sectionHeaders]) {
                ForEach(minutes, id: \.description) { preset in
                    TimerPresetCell(preset) { time in
                        presetAction(time)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .cornerRadius(4)
        }
        .scrollBounceBehavior(.basedOnSize, axes: .vertical)
    }
}
