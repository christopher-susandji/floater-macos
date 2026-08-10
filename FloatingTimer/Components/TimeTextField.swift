//
//  TimeTextField.swift
//  FloatingTimer
//
//  Created by Christopher Susandji on 29/07/26.
//

import SwiftUI
import AppKit

struct TimeTextField: View {
    @Binding var value: Int
    let max: Int
    var onMoveLeft: (() -> Void)? = nil
    var onMoveRight: (() -> Void)? = nil
    
    @State private var text: String = ""
    @State private var shouldClearOnNextInput = false
    @State private var isProgrammaticChange = false
    @FocusState private var isFocused: Bool
    @State private var repeatTimer: Timer?
    
    
    var body: some View {
        TextField("00", text: $text)
            .font(.system(size: 48, weight: .bold, design: .monospaced))
            .monospacedDigit()
            .multilineTextAlignment(.leading)
            .textFieldStyle(.plain)
            .fixedSize()
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(focusBackgroundColor)
            )
            .focused($isFocused)
            .onChange(of: text) { oldValue, newValue in
                if isProgrammaticChange {
                    isProgrammaticChange = false
                    return
                }
                isProgrammaticChange = true
                
                if shouldClearOnNextInput && !newValue.isEmpty {
                    shouldClearOnNextInput = false
                    text = "0" + String(newValue.last ?? Character(""))
                    value = Int(text) ?? 0
                    return
                }
                
                // Only allow numbers
                let filtered: String = newValue.filter { $0.isNumber }
                
                let realValue: Int = {
                    let v = Int(filtered) ?? 0
                    if String(v).count > 2 {
                        NSSound.beep()
                        shouldClearOnNextInput = true
                    }
                    return v
                }()
                
                let limited = String(format: "%02d", realValue).prefix(2)
                
                if let number = Int(limited) {
                    if number > max {
                        NSSound.beep()
                        text = oldValue
                        shouldClearOnNextInput = true
                        return
                    }
                    value = number
                    text = String(limited)
                } else if limited.isEmpty {
                    value = 0
                    text = ""
                }
            }
            .onChange(of: isFocused) { _, focused in
                guard focused else { return }
                DispatchQueue.main.async {
                    if let fieldEditor = NSApp.keyWindow?.firstResponder as? NSTextView {
                        fieldEditor.selectedTextAttributes = [
                            .backgroundColor: NSColor.clear
                        ]
                        fieldEditor.insertionPointColor = .clear
                    }
                }
            }
            .onAppear {
                text = value == 0 ? "" : String(format: "%02d", value)
            }
            .onKeyPress(.leftArrow) {
                guard let onMoveLeft else { return .ignored }
                onMoveLeft()
                return .handled
            }
            .onKeyPress(.rightArrow) {
                guard let onMoveRight else { return .ignored }
                onMoveRight()
                return .handled
            }
            .onKeyPress(.upArrow, phases: [.down, .up]) { keyPress in
                switch keyPress.phase {
                case .down:
                    incrementValue()
                    startRepeating(increment: true)
                case .up:
                    stopRepeating()
                default:
                    break
                }
                return .handled
            }
            .onKeyPress(.downArrow, phases: [.down, .up]) { keyPress in
                switch keyPress.phase {
                case .down:
                    decrementValue()
                    startRepeating(increment: false)
                case .up:
                    stopRepeating()
                default:
                    break
                }
                return .handled
            }
    }
    
    private func setValue(_ newValue: Int) {
        let clamped = Swift.max(0, Swift.min(newValue, max))
        value = clamped
        isProgrammaticChange = true
        text = clamped == 0 ? "" : String(format: "%02d", clamped)
    }
}

extension TimeTextField {
    
    private var focusBackgroundColor: Color {
        isFocused ? .orange : .clear
    }
    
    private func incrementValue() {
        let next = value + 1
        setValue(next > max ? 0 : next)
    }
    
    private func decrementValue() {
        let next = value - 1
        setValue(next < 0 ? max : next)
    }
    
    private func startRepeating(increment: Bool) {
        stopRepeating()
        repeatTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: false) { _ in
            repeatTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { _ in
                if increment {
                    incrementValue()
                } else {
                    decrementValue()
                }
            }
            RunLoop.main.add(repeatTimer!, forMode: .common)
        }
        RunLoop.main.add(repeatTimer!, forMode: .common)
    }
    
    private func stopRepeating() {
        repeatTimer?.invalidate()
        repeatTimer = nil
    }
}
