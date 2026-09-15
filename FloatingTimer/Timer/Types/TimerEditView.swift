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

/// A completion chime choice surfaced in the edit mode.
struct ChimeOption: Identifiable {
    let id: String
    var name: String
    var isSelected: Bool
    var onSelect: () -> Void
}

/// The bundled completion chimes offered in the chime picker. `id` is the full
/// file name (with extension) used by `TimerModel.chime`.
enum ChimeCatalog {
    static let all: [ChimeOption] = [
        ChimeOption(id: "minimal-cinematic.mp3", name: "Minimal", isSelected: false, onSelect: {}),
        ChimeOption(id: "gentle-ding.mp3", name: "Gentle Ding", isSelected: false, onSelect: {}),
        ChimeOption(id: "guitar-strum.mp3", name: "Guitar", isSelected: false, onSelect: {}),
        ChimeOption(id: "train-horn.mp3", name: "Train Horn", isSelected: false, onSelect: {}),
    ]
}

/// Shared "edit" screen for every timer type: header with close button, a type
/// selector, a row of theme swatches and the preset duration grid.
struct TimerEditView: View {
    var headerColor: Color
    var typeOptions: [TypeOption]
    var themeOptions: [ThemeOption]
    var chimeOptions: [ChimeOption]
    var minutes: [TimeInterval]
    var presetAction: (TimeInterval) -> Void
    var closeAction: () -> Void

    @State private var isCustomizePresented = false

    private let columnLayout = Array(repeating: GridItem(), count: 2)

    private var selectedTypeID: String {
        typeOptions.first(where: \.isSelected)?.id ?? ""
    }

    private var selectedTypeName: String {
        typeOptions.first(where: \.isSelected)?.name ?? ""
    }

    private var selectedChimeName: String {
        chimeOptions.first(where: \.isSelected)?.name ?? ""
    }

    private var typeSelection: Binding<String> {
        Binding(
            get: { selectedTypeID },
            set: { id in
                typeOptions.first(where: { $0.id == id })?.onSelect()
            }
        )
    }

    private var chimeSelection: Binding<String> {
        Binding(
            get: { chimeOptions.first(where: \.isSelected)?.id ?? "" },
            set: { id in
                chimeOptions.first(where: { $0.id == id })?.onSelect()
            }
        )
    }

    var body: some View {
        VStack(spacing: Sizing.md) {
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
                isCustomizePresented.toggle()
            } label: {
                Image(systemName: "paintbrush.pointed.fill")
                    .frame(width: Sizing.lg, height: Sizing.lg)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.roundedRectangle)
            .popover(isPresented: $isCustomizePresented, arrowEdge: .bottom) {
                customizePanel
            }
            Button {
                closeAction()
            } label: {
                Image(systemName: "xmark")
                    .fontWeight(.bold)
                    .frame(width: Sizing.lg, height: Sizing.lg)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.roundedRectangle)
        }
    }

    /// The mini "customize" panel: type family, theme swatches and completion
    /// chime. Grows here as more per-timer preferences are added.
    private var customizePanel: some View {
        VStack(alignment: .leading, spacing: Sizing.sm) {
            themeTypeSelector
            /// Temporarily remove the swatch
//            if themeOptions.count > 1 {
//                themeSwatchSelector
//            }
            chimeSelector
        }
        .padding(Sizing.md)
    }

    private var chimeSelector: some View {
        Picker(selection: chimeSelection) {
            ForEach(chimeOptions) { option in
                Text(option.name).tag(option.id)
            }
        } label: {
                Image(systemName: "speaker.wave.2.fill")
            .font(.caption)
            .fontWeight(.medium)
        }
        .pickerStyle(.menu)
    }
    
    private var themeTypeSelector: some View {
        Picker(selection: typeSelection) {
            ForEach(typeOptions) { option in
                Text(option.name).tag(option.id)
            }
        } label: {
            Image(systemName: "paintbrush.pointed.fill")
            .font(.caption)
            .fontWeight(.medium)
        }
        .pickerStyle(.menu)
        .frame(maxWidth: .infinity, alignment: .leading)
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

#Preview {
    TimerView(viewModel: TimerViewModel(model: TimerModel(title: "Focus", duration: 5)))
        .frame(width: 220, height: 220)
}
