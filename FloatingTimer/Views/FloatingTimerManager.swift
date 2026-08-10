//
//  FloatingTimerManager.swift
//  FloatingTimer
//
//  Created by Christopher Susandji on 27/07/26.
//

import AppKit
import SwiftUI

class FloatingTimerManager: NSObject {
    static let shared = FloatingTimerManager()
    
    private var panels: [UUID: NSPanel] = [:]
    private var panelDelegates: [UUID: PanelDelegate] = [:]

    func showTimer(_ viewModel: TimerViewModel, in appViewModel: AppViewModel) {
        let timerView = TimerView(viewModel: viewModel) { [weak self] in
            appViewModel.removeTimer(id: viewModel.id)
            self?.closeTimer(viewModel.id)
        }
            .environment(\.controlActiveState, .key)
        let hostingController = NSHostingController(rootView: timerView)

        let panel = NSPanel(
            contentRect: NSRect(x: 100, y: 100, width: 220, height: 220),
            styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        panel.contentViewController = hostingController
        
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.title = viewModel.title
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        panel.isOpaque = false
        panel.hasShadow = true
        panel.backgroundColor = .clear

        let panelDelegate = PanelDelegate { [weak self] in
            self?.panels.removeValue(forKey: viewModel.id)
            self?.panelDelegates.removeValue(forKey: viewModel.id)
        }
        panel.delegate = panelDelegate

        panels[viewModel.id] = panel
        panelDelegates[viewModel.id] = panelDelegate
        panel.makeKeyAndOrderFront(nil)
    }

    func closeTimer(_ id: UUID) {
        panels[id]?.close()
        panels.removeValue(forKey: id)
        panelDelegates.removeValue(forKey: id)
    }
}

class PanelDelegate: NSObject, NSWindowDelegate {
    private let onClose: () -> Void

    init(onClose: @escaping () -> Void) {
        self.onClose = onClose
    }

    func windowWillClose(_ notification: Notification) {
        onClose()
    }
}
