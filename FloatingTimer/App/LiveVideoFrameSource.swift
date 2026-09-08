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

/// Drives Floater's virtual camera by rendering the active timer and pushing
/// frames into the camera extension's sink stream. The extension forwards them
/// out through its source stream to consumers like Keynote.
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
        static let width: Int32 = 1280
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

    /// Render target size; must match the extension's format (1280x720).
    private let outputSize = CGSize(width: CGFloat(Constants.width), height: CGFloat(Constants.height))

    private init() {}

    // - MARK: Public API

    func start() {
        configureFormat()
        connectToSinkStream()
        startRenderTimer()
    }

    func stop() {
        renderTimer?.invalidate()
        renderTimer = nil
        sinkQueue = nil
        sinkStream = nil
        deviceID = nil
        viewModel = nil
    }

    private func isRunning() -> Bool {
        renderTimer != nil
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
        guard let cgImage = renderCurrentFrame() else { return }

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
            context.interpolationQuality = .low
            context.clear(CGRect(x: 0, y: 0, width: width, height: height))
            // Fill solid black so the timer bakes onto an opaque background.
            context.setFillColor(CGColor(gray: 0, alpha: 1))
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
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

    /// Rasterizes the active timer's view (or a placeholder) into a `CGImage`.
    private func renderCurrentFrame() -> CGImage? {
        let rootView: AnyView
        if let viewModel {
            rootView = AnyView(
                BroadcastTimerView(viewModel: viewModel)
                    .frame(width: outputSize.width, height: outputSize.height)
            )
        } else {
            rootView = AnyView(
                Text("Floater")
                    .font(.system(size: 120, weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(width: outputSize.width, height: outputSize.height)
                    .background(Color.black)
            )
        }

        let renderer = ImageRenderer(content: rootView)
        renderer.proposedSize = ProposedViewSize(outputSize)
        renderer.scale = 1.0
        return renderer.cgImage
    }
}
