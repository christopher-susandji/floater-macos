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

    /// Origin of the most recently active timer panel (the last one created,
    /// focused or dragged). New timers spawn here so they reuse the spot the
    /// user last placed a timer in. Kept in memory for the session only, and
    /// survives the active panel being closed so the next timer still lands
    /// where the previous one was.
    private var lastActiveOrigin: NSPoint?
    
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

    /// Keeps a remembered origin on-screen, e.g. after a display change, so a
    /// new timer can't spawn somewhere the user can't reach it. The point is
    /// clamped to the display it was placed on, not the main window's screen,
    /// so a timer dragged to a secondary display stays there.
    private func sanitizedOrigin(_ origin: NSPoint) -> NSPoint {
        let screen = NSScreen.screens.first { $0.frame.contains(origin) } ?? targetScreen
        let screenFrame = screen.visibleFrame
        let maxX = screenFrame.maxX - panelSize.width
        let maxY = screenFrame.maxY - panelSize.height
        return NSPoint(
            x: min(max(origin.x, screenFrame.minX), maxX),
            y: min(max(origin.y, screenFrame.minY), maxY)
        )
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

        // Reuse the spot the last active timer occupied; fall back to the grid
        // when no timer has been placed yet this session.
        let origin = lastActiveOrigin.map(sanitizedOrigin) ?? frameOrigin(forSlot: slot)
        panel.setFrameOrigin(origin)
        lastActiveOrigin = origin

        let panelDelegate = PanelDelegate(
            onClose: { [weak self] in
                self?.panels.removeValue(forKey: viewModel.id)
                self?.panelDelegates.removeValue(forKey: viewModel.id)
                self?.slots.removeValue(forKey: viewModel.id)
            },
            onMove: { [weak self] origin in
                self?.lastActiveOrigin = origin
            }
        )
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
        guard let panel = panels[id] else { return }
        // Focusing a timer makes it the active one, so its spot becomes the one
        // the next timer will reuse.
        lastActiveOrigin = panel.frame.origin
        panel.makeKeyAndOrderFront(nil)
    }
}

class PanelDelegate: NSObject, NSWindowDelegate {
    private let onClose: () -> Void
    private let onMove: (NSPoint) -> Void
    
    init(onClose: @escaping () -> Void, onMove: @escaping (NSPoint) -> Void) {
        self.onClose = onClose
        self.onMove = onMove
    }
    
    func windowWillClose(_ notification: Notification) {
        onClose()
    }
    
    func windowDidMove(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        onMove(window.frame.origin)
    }
}
