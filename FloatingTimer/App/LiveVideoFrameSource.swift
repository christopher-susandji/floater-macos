//
//  LiveVideoFrameSource.swift
//  Floater
//
//  Created by Christopher Susandji on 07/09/26.
//

import SwiftUI
import AVFoundation
import CoreMediaIO
import CoreGraphics
import os.log

/// Drives Floater's virtual camera by rendering the active timer offscreen and
/// pushing those frames into the camera extension's sink stream. The extension
/// forwards them out through its source stream to consumers like Keynote.
///
/// This deliberately avoids `ScreenCaptureKit`: capturing the real panel window
/// requires `com.apple.security.device.screen-recording`, which App Store /
/// TestFlight builds cannot use. Instead we rasterize the same `TimerView` the
/// panel hosts, so the feed looks identical to the panel — App Store-compatible.
///
/// Transport is the "sink stream" pattern (see `ldenoue/cameraextension`): the
/// host app opens the extension's sink `CMIOStream` and enqueues frames; no XPC
/// shared-memory plumbing is required.
@MainActor
final class LiveVideoFrameSource {

    /// Must match `FloaterCamera/Config.swift` in the extension target.
    enum Constants {
        static let deviceName = "Floater"
        static let frameRate = 30
        static let width: Int32 = 720
        static let height: Int32 = 720
    }

    static let shared = LiveVideoFrameSource()

    private var sinkQueue: CMSimpleQueue?
    private var sinkStream: CMIOStreamID?
    private var deviceID: CMIODeviceID?

    private var videoDescription: CMFormatDescription!
    private var bufferPool: CVPixelBufferPool!
    private var bufferAuxAttributes: NSDictionary!

    private var renderTimer: Timer?
    private var readyToEnqueue = true

    /// The timer whose rendered view is broadcast. Set before calling `start()`.
    var viewModel: TimerViewModel?

    /// The solid color painted behind the timer in the outgoing frame. The
    /// camera can't carry transparency, so this is the slide-facing backdrop.
    /// Defaults to black.
    var backgroundColor: Color = .black

    /// Interpolation state for the broadcast ring: the last whole-second value
    /// observed and the wall-clock time it was seen, so we can synthesize a
    /// smooth, continuously-decreasing `remaining` between engine ticks.
    private var lastRemaining: TimeInterval?
    private var lastRemainingTimestamp: TimeInterval = 0

    private init() {}

    // - MARK: Public API

    func start() {
        configureFormat()
        Task { @MainActor in
            connectToSinkStream()
            startRenderTimer()
        }
    }

    func stop() {
        renderTimer?.invalidate()
        renderTimer = nil
        sinkQueue = nil
        sinkStream = nil
        deviceID = nil
        viewModel = nil
        lastRemaining = nil
    }

    /// Disconnects the active timer but keeps the camera streaming, rendering the
    /// contextual placeholder instead of freezing on the last timer frame.
    func showPlaceholder() {
        viewModel = nil
        lastRemaining = nil
        if sinkQueue == nil {
            start()
        }
    }

    // - MARK: Format setup

    private func configureFormat() {
        let dims = CMVideoDimensions(width: Constants.width, height: Constants.height)
        var description: CMFormatDescription?
        CMVideoFormatDescriptionCreate(
            allocator: kCFAllocatorDefault,
            codecType: kCVPixelFormatType_32BGRA,
            width: dims.width,
            height: dims.height,
            extensions: nil,
            formatDescriptionOut: &description
        )
        videoDescription = description

        var pool: CVPixelBufferPool?
        let attrs: NSDictionary = [
            kCVPixelBufferWidthKey: dims.width,
            kCVPixelBufferHeightKey: dims.height,
            kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA,
            kCVPixelBufferIOSurfacePropertiesKey: [:]
        ]
        CVPixelBufferPoolCreate(kCFAllocatorDefault, nil, attrs, &pool)
        bufferPool = pool
        bufferAuxAttributes = [kCVPixelBufferPoolAllocationThresholdKey: 5]
    }

    // - MARK: Discovery

    /// Finds the Floater CMIO device directly (no AVCaptureDevice dependency),
    /// so discovery works even before camera permission is granted.
    private func findFloaterCMIODeviceID() -> CMIODeviceID? {
        var dataSize: UInt32 = 0
        var dataUsed: UInt32 = 0
        var opa = CMIOObjectPropertyAddress(
            mSelector: CMIOObjectPropertySelector(kCMIOHardwarePropertyDevices),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain)
        )
        CMIOObjectGetPropertyDataSize(CMIOObjectID(kCMIOObjectSystemObject), &opa, 0, nil, &dataSize)
        let count = Int(dataSize) / MemoryLayout<CMIOObjectID>.size
        guard count > 0 else { return nil }
        var devices = [CMIOObjectID](repeating: 0, count: count)
        CMIOObjectGetPropertyData(CMIOObjectID(kCMIOObjectSystemObject), &opa, 0, nil, dataSize, &dataUsed, &devices)

        for deviceObjectID in devices {
            opa.mSelector = CMIOObjectPropertySelector(0x6C6E616D) // 'lnam' = kCMIODevicePropertyLocalizedName
            CMIOObjectGetPropertyDataSize(deviceObjectID, &opa, 0, nil, &dataSize)
            let namePtr = UnsafeMutablePointer<Unmanaged<CFString>?>.allocate(capacity: 1)
            defer { namePtr.deallocate() }
            CMIOObjectGetPropertyData(deviceObjectID, &opa, 0, nil, dataSize, &dataUsed, namePtr)
            let name = namePtr.pointee?.takeUnretainedValue() as String? ?? ""
            if name == Constants.deviceName {
                return deviceObjectID
            }
        }
        return nil
    }

    private func findFloaterDevice() -> AVCaptureDevice? {
        let session = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.external],
            mediaType: .video,
            position: .unspecified
        )
        return session.devices.first { $0.localizedName == Constants.deviceName }
    }

    private func cmioDeviceID(uid: String) -> CMIODeviceID? {
        var dataSize: UInt32 = 0
        var dataUsed: UInt32 = 0
        var opa = CMIOObjectPropertyAddress(
            mSelector: CMIOObjectPropertySelector(kCMIOHardwarePropertyDevices),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain)
        )
        CMIOObjectGetPropertyDataSize(CMIOObjectID(kCMIOObjectSystemObject), &opa, 0, nil, &dataSize)
        let count = Int(dataSize) / MemoryLayout<CMIOObjectID>.size
        guard count > 0 else { return nil }
        var devices = [CMIOObjectID](repeating: 0, count: count)
        CMIOObjectGetPropertyData(CMIOObjectID(kCMIOObjectSystemObject), &opa, 0, nil, dataSize, &dataUsed, &devices)

        for deviceObjectID in devices {
            opa.mSelector = CMIOObjectPropertySelector(kCMIODevicePropertyDeviceUID)
            CMIOObjectGetPropertyDataSize(deviceObjectID, &opa, 0, nil, &dataSize)
            let namePtr = UnsafeMutablePointer<Unmanaged<CFString>?>.allocate(capacity: 1)
            defer { namePtr.deallocate() }
            CMIOObjectGetPropertyData(deviceObjectID, &opa, 0, nil, dataSize, &dataUsed, namePtr)
            let name = namePtr.pointee?.takeUnretainedValue() as String? ?? ""
            if name == uid {
                return deviceObjectID
            }
        }
        return nil
    }

    private func streams(for deviceID: CMIODeviceID) -> [CMIOStreamID] {
        var dataSize: UInt32 = 0
        var dataUsed: UInt32 = 0
        var opa = CMIOObjectPropertyAddress(
            mSelector: CMIOObjectPropertySelector(kCMIODevicePropertyStreams),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain)
        )
        CMIOObjectGetPropertyDataSize(deviceID, &opa, 0, nil, &dataSize)
        let count = Int(dataSize) / MemoryLayout<CMIOStreamID>.size
        guard count > 0 else { return [] }
        var streamIDs = [CMIOStreamID](repeating: 0, count: count)
        CMIOObjectGetPropertyData(deviceID, &opa, 0, nil, dataSize, &dataUsed, &streamIDs)
        return streamIDs
    }

    private func connectToSinkStream() {
        let deviceID: CMIODeviceID? = {
            if let direct = findFloaterCMIODeviceID() {
                return direct
            }
            guard let device = findFloaterDevice() else { return nil }
            return cmioDeviceID(uid: device.uniqueID)
        }()
        guard let deviceID else { return }
        self.deviceID = deviceID

        let streamIDs = streams(for: deviceID)
        // Extension exposes [source, sink]; the sink is the second stream.
        guard streamIDs.count >= 2 else { return }
        let sinkStream = streamIDs[1]
        self.sinkStream = sinkStream

        let pointer = UnsafeMutablePointer<Unmanaged<CMSimpleQueue>?>.allocate(capacity: 1)
        let refcon = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        let status = CMIOStreamCopyBufferQueue(sinkStream, { _, _, refcon in
            guard let refcon else { return }
            let source = Unmanaged<LiveVideoFrameSource>.fromOpaque(refcon).takeUnretainedValue()
            Task { @MainActor in
                source.readyToEnqueue = true
            }
        }, refcon, pointer)

        if status == noErr, let queue = pointer.pointee {
            self.sinkQueue = queue.takeUnretainedValue()
            _ = CMIODeviceStartStream(deviceID, sinkStream)
        }
        pointer.deallocate()
    }

    // - MARK: Rendering

    private func startRenderTimer() {
        renderTimer?.invalidate()
        renderTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / Double(Constants.frameRate), repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.renderTick()
            }
        }
    }

    private func renderTick() {
        guard readyToEnqueue, let sinkQueue else { return }
        guard CMSimpleQueueGetCount(sinkQueue) < CMSimpleQueueGetCapacity(sinkQueue) else {
            readyToEnqueue = false
            return
        }
        let cgImage: CGImage
        if viewModel != nil {
            guard let rendered = renderCurrentFrame() else { return }
            cgImage = rendered
        } else {
            guard let placeholder = renderPlaceholder() else { return }
            cgImage = placeholder
        }

        readyToEnqueue = false

        var pixelBuffer: CVPixelBuffer?
        let err = CVPixelBufferPoolCreatePixelBufferWithAuxAttributes(kCFAllocatorDefault, bufferPool, bufferAuxAttributes, &pixelBuffer)
        guard err == kCVReturnSuccess, let pixelBuffer else { return }

        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let colorSpace = CGColorSpaceCreateDeviceRGB()

        if let context = CGContext(
            data: CVPixelBufferGetBaseAddress(pixelBuffer),
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
            space: colorSpace,
            bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue
        ) {
            context.interpolationQuality = .high
            context.clear(CGRect(x: 0, y: 0, width: width, height: height))
            // Fill the configured solid background so the timer bakes onto an
            // opaque backdrop (the camera feed carries no transparency).
            context.setFillColor(backgroundColor.cgColor)
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))

            // The rendered timer image is already the full frame size (square).
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        }

        var sampleBuffer: CMSampleBuffer?
        var timingInfo = CMSampleTimingInfo()
        timingInfo.presentationTimeStamp = CMClockGetTime(CMClockGetHostTimeClock())
        let createStatus = CMSampleBufferCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            dataReady: true,
            makeDataReadyCallback: nil,
            refcon: nil,
            formatDescription: videoDescription,
            sampleTiming: &timingInfo,
            sampleBufferOut: &sampleBuffer
        )
        if createStatus == noErr, let sampleBuffer {
            let retainedPointer = UnsafeMutableRawPointer(Unmanaged.passRetained(sampleBuffer).toOpaque())
            CMSimpleQueueEnqueue(sinkQueue, element: retainedPointer)
        }
    }

    /// Rasterizes the **same view the floating panel hosts** (`TimerView`) into a
    /// `CGImage`, so the broadcast feed is identical in appearance to the panel.
    /// The panel is 220×220; we render it square and scale up to 720×720, which
    /// fills the (now square) camera frame.
    private func renderCurrentFrame() -> CGImage? {
        let panelSize: CGFloat = 220
        let scaledSize: CGFloat = CGFloat(Constants.height) // 720, square

        guard let viewModel else { return nil }

        let rootView = TimerView(viewModel: viewModel)
            .environment(\.controlActiveState, .key)
            .environment(\.broadcastSmoothRemaining, smoothRemaining(for: viewModel))
            .frame(width: panelSize, height: panelSize)

        let renderer = ImageRenderer(content: rootView)
        renderer.proposedSize = ProposedViewSize(width: panelSize, height: panelSize)
        renderer.scale = scaledSize / panelSize
        return renderer.cgImage
    }

    /// Rasterizes the contextual placeholder shown when no timer is being
    /// broadcast (matches the extension's idle frame design).
    private func renderPlaceholder() -> CGImage? {
        let size: CGFloat = CGFloat(Constants.height) // 720, square
        let rootView = BroadcastPlaceholderView()
            .frame(width: size, height: size)
        let renderer = ImageRenderer(content: rootView)
        renderer.proposedSize = ProposedViewSize(width: size, height: size)
        renderer.scale = 1
        return renderer.cgImage
    }

    /// A continuously-decreasing `remaining` value (with sub-second precision)
    /// so the broadcast ring sweeps smoothly instead of jumping once per second.
    private func smoothRemaining(for viewModel: TimerViewModel) -> TimeInterval {
        let wholeSecond = viewModel.remaining
        let now = ProcessInfo.processInfo.systemUptime
        if lastRemaining != wholeSecond {
            lastRemaining = wholeSecond
            lastRemainingTimestamp = now
            return wholeSecond
        }
        guard let lastRemaining else { return wholeSecond }
        let elapsed = now - lastRemainingTimestamp
        guard elapsed < 1 else { return wholeSecond }
        return max(0, lastRemaining - elapsed)
    }
}

private extension Color {
    /// The `CGColor` used to paint the broadcast backdrop (opaque RGB).
    var cgColor: CGColor {
        NSColor(self).usingColorSpace(.deviceRGB)?.cgColor ?? NSColor.black.cgColor
    }
}

/// The idle "no timer selected" frame shown in the broadcast when the user
/// disconnects the camera or no timer is active.
struct BroadcastPlaceholderView: View {
    private let accent = Color(red: 1.0, green: 0.55, blue: 0.16)

    var body: some View {
        ZStack {
            Color(white: 0.06)
                .ignoresSafeArea()

            RoundedRectangle(cornerRadius: 44)
                .strokeBorder(Color(white: 0.35), style: StrokeStyle(lineWidth: 2, dash: [10, 8]))
                .padding(34)

            VStack(spacing: 24) {
                FloaterGlyph(accent: accent)
                    .frame(width: 120, height: 120)

                Text("FLOATER")
                    .font(.system(size: 56, weight: .heavy))
                    .foregroundStyle(.white)

                Text("No active timer selected as source.\nOpen Floater and select a timer.")
                    .font(.system(size: 22))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color(white: 0.6))
                    .lineSpacing(6)
            }
        }
    }
}

/// The Floater app glyph: an amber tick-ring timer face with a clock hand.
private struct FloaterGlyph: View {
    let accent: Color

    var body: some View {
        GeometryReader { geo in
            let r = min(geo.size.width, geo.size.height) / 2
            ZStack {
                Circle()
                    .stroke(accent, lineWidth: r * 0.12)
                Circle()
                    .trim(from: 0, to: 0.25)
                    .stroke(.white, lineWidth: r * 0.10)
                    .rotationEffect(.degrees(-90))
                ForEach(0..<12, id: \.self) { i in
                    Rectangle()
                        .fill(.white)
                        .frame(width: r * 0.04, height: r * (i % 3 == 0 ? 0.20 : 0.12))
                        .offset(y: -r * 0.80)
                        .rotationEffect(.degrees(Double(i) * 30))
                }
            }
            .frame(width: r * 2, height: r * 2)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
    }
}