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
import ScreenCaptureKit
import os.log

/// Drives Floater's virtual camera by capturing the timer's floating panel
/// window and pushing those frames into the camera extension's sink stream.
/// The extension forwards them out through its source stream to consumers
/// like Keynote.
///
/// Transport is the "sink stream" pattern (see `ldenoue/cameraextension`): the
/// host app opens the extension's sink `CMIOStream` and enqueues frames; no XPC
/// shared-memory plumbing is required.
@MainActor
final class LiveVideoFrameSource: NSObject, SCStreamOutput, SCStreamDelegate {

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

    private var scStream: SCStream?
    private let captureQueue = DispatchQueue(label: "floater.capture", qos: .userInteractive)

    private override init() { super.init() }

    // - MARK: Public API

    /// Begins capturing `windowID` and streaming it into the virtual camera.
    func start(windowID: CGWindowID) {
        configureFormat()
        Task { @MainActor in
            _ = await AVCaptureDevice.requestAccess(for: .video)
            connectToSinkStream()
            await startWindowCapture(windowID: windowID)
        }
    }

    func stop() {
        scStream?.stopCapture { _ in }
        scStream = nil
        if let deviceID, let sinkStream {
            CMIODeviceStopStream(deviceID, sinkStream)
        }
        sinkQueue = nil
        sinkStream = nil
        deviceID = nil
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
        let status = CMIOStreamCopyBufferQueue(sinkStream, nil, nil, pointer)
        if status == noErr, let queue = pointer.pointee {
            self.sinkQueue = queue.takeUnretainedValue()
            _ = CMIODeviceStartStream(deviceID, sinkStream)
        }
        pointer.deallocate()
    }

    // - MARK: Window capture (ScreenCaptureKit)

    private func startWindowCapture(windowID: CGWindowID) async {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
            guard let scWindow = content.windows.first(where: { $0.windowID == windowID }) else {
                os_log(.error, "Floater camera: could not find window %d in shareable content", windowID)
                return
            }

            let filter = SCContentFilter(desktopIndependentWindow: scWindow)
            let config = SCStreamConfiguration()
            config.width = Int(Constants.width)
            config.height = Int(Constants.height)
            config.pixelFormat = kCVPixelFormatType_32BGRA
            config.minimumFrameInterval = CMTime(value: 1, timescale: Int32(Constants.frameRate))
            config.showsCursor = false
            config.capturesAudio = false

            let stream = SCStream(filter: filter, configuration: config, delegate: self)
            try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: captureQueue)
            try await stream.startCapture()
            scStream = stream
            os_log(.info, "Floater camera: capturing window %d", windowID)
        } catch {
            os_log(.error, "Floater camera: failed to start window capture: %@", error.localizedDescription)
        }
    }

    // - MARK: SCStreamOutput

    nonisolated func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of outputType: SCStreamOutputType) {
        guard outputType == .screen,
              let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        Task { @MainActor in
            self.enqueue(imageBuffer)
        }
    }

    @MainActor
    private func enqueue(_ imageBuffer: CVPixelBuffer) {
        guard let sinkQueue else { return }
        guard CMSimpleQueueGetCount(sinkQueue) < CMSimpleQueueGetCapacity(sinkQueue) else { return }
        guard let videoDescription else { return }

        var sampleBuffer: CMSampleBuffer?
        var timingInfo = CMSampleTimingInfo()
        timingInfo.presentationTimeStamp = CMClockGetTime(CMClockGetHostTimeClock())
        let createStatus = CMSampleBufferCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: imageBuffer,
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
}