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
    private var slots: [UUID: Int] = [:]
    
    private let panelSize = NSSize(width: 220, height: 220)
    private let gridSpacing: CGFloat = 16
    private let columns = 3
    
    /// Finds the main "Floater" content window (as opposed to the floating timer panels we manage).
    private var mainWindow: NSWindow? {
        NSApp.windows.first { window in
            !(window is NSPanel) && window.isVisible
        }
    }
    
    private var targetScreen: NSScreen {
        mainWindow?.screen ?? NSScreen.main ?? NSScreen.screens[0]
    }
    
    private func nextAvailableSlot() -> Int {
        let used = Set(slots.values)
        var candidate = 0
        while used.contains(candidate) {
            candidate += 1
        }
        return candidate
    }
    
    private func frameOrigin(forSlot slot: Int) -> NSPoint {
        let screenFrame = targetScreen.visibleFrame
        
        // Top-right anchor point of the desktop.
        let anchorTopRight = NSPoint(x: screenFrame.maxX - gridSpacing, y: screenFrame.maxY - gridSpacing)
        
        let col = slot % columns
        let row = slot / columns
        
        let cellTopRightX = anchorTopRight.x - CGFloat(col) * (panelSize.width + gridSpacing)
        let x = cellTopRightX - panelSize.width
        
        let cellTopY = anchorTopRight.y - CGFloat(row) * (panelSize.height + gridSpacing)
        let originY = cellTopY - panelSize.height
        
        return NSPoint(x: x, y: originY)
    }
    
    func showTimer(_ viewModel: TimerViewModel, in appViewModel: AppViewModel) {
        let timerView = TimerView(viewModel: viewModel) { [weak self] in
            appViewModel.removeTimer(id: viewModel.id)
            self?.closeTimer(viewModel.id)
        }
            .environment(\.controlActiveState, .key)
        let hostingController = NSHostingController(rootView: timerView)
        
        let panelSize = NSSize(width: 220, height: 220)
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: panelSize),
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
        panel.isMovable = true
        panel.isMovableByWindowBackground = true
        panel.isOpaque = false
        panel.hasShadow = true
        panel.backgroundColor = .clear
        
        let slot = nextAvailableSlot()
        slots[viewModel.id] = slot
        panel.setFrameOrigin(frameOrigin(forSlot: slot))
        
        let panelDelegate = PanelDelegate { [weak self] in
            self?.panels.removeValue(forKey: viewModel.id)
            self?.panelDelegates.removeValue(forKey: viewModel.id)
            self?.slots.removeValue(forKey: viewModel.id)
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
        slots.removeValue(forKey: id)
    }
    
    /// Brings the given timer's floating panel to the front, without stealing key focus
    /// away from the main app window any more than necessary.
    func focusTimer(_ id: UUID) {
        panels[id]?.makeKeyAndOrderFront(nil)
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
