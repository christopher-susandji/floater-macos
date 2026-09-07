//
//  FloaterProviderSource.swift
//  FloaterCamera
//
//  Created by Christopher Susandji on 07/09/26.
//

import Foundation
import CoreMediaIO
import IOKit.audio
import CoreGraphics
import AppKit
import os.log

/// Renders the placeholder frame for the virtual camera. In Phase 0 this is a
/// simple "Floater" banner over a black background so we can verify the camera
/// appears and streams in Keynote / QuickTime. Later this is replaced (or fed)
/// by the host app's rendered timer frame.
final class FloaterProviderSource: NSObject, CMIOExtensionProviderSource {

    private(set) var provider: CMIOExtensionProvider!
    private let deviceSource: FloaterDeviceSource

    init(clientQueue: DispatchQueue?) {
        self.deviceSource = FloaterDeviceSource()
        super.init()
        provider = CMIOExtensionProvider(source: self, clientQueue: clientQueue)
        do {
            try provider.addDevice(deviceSource.device)
        } catch {
            fatalError("Failed to add device: \(error.localizedDescription)")
        }
    }

    func connect(to client: CMIOExtensionClient) throws {}
    func disconnect(from client: CMIOExtensionClient) {}

    var availableProperties: Set<CMIOExtensionProperty> {
        [.providerManufacturer]
    }

    func providerProperties(forProperties properties: Set<CMIOExtensionProperty>) throws -> CMIOExtensionProviderProperties {
        let providerProperties = CMIOExtensionProviderProperties(dictionary: [:])
        if properties.contains(.providerManufacturer) {
            providerProperties.manufacturer = "Christopher Susandji"
        }
        return providerProperties
    }

    func setProviderProperties(_ providerProperties: CMIOExtensionProviderProperties) throws {}
}

final class FloaterDeviceSource: NSObject, CMIOExtensionDeviceSource {

    private(set) var device: CMIOExtensionDevice!
    private let streamSource: FloaterStreamSource
    private let streamSink: FloaterStreamSink

    private var timer: DispatchSourceTimer?
    private let timerQueue = DispatchQueue(label: "floater.camera.timer", qos: .userInteractive)

    private var videoDescription: CMFormatDescription!
    private var bufferPool: CVPixelBufferPool!
    private var bufferAuxAttributes: NSDictionary!
    private var streamingCounter: UInt32 = 0
    private var sinkStreamingCounter: UInt32 = 0

    /// When the host app is connected via the sink stream and pushing frames,
    /// we forward those instead of rendering the placeholder.
    private(set) var sinkActive: Bool = false

    override init() {
        streamSource = FloaterStreamSource()
        streamSink = FloaterStreamSink()
        super.init()

        let deviceID = UUID()
        device = CMIOExtensionDevice(localizedName: CameraConfig.deviceName, deviceID: deviceID, legacyDeviceID: deviceID.uuidString, source: self)

        let dims = CMVideoDimensions(width: CameraConfig.width, height: CameraConfig.height)
        CMVideoFormatDescriptionCreate(
            allocator: kCFAllocatorDefault,
            codecType: kCVPixelFormatType_32BGRA,
            width: dims.width,
            height: dims.height,
            extensions: nil,
            formatDescriptionOut: &videoDescription
        )

        let pixelBufferAttributes: NSDictionary = [
            kCVPixelBufferWidthKey: dims.width,
            kCVPixelBufferHeightKey: dims.height,
            kCVPixelBufferPixelFormatTypeKey: videoDescription.mediaSubType,
            kCVPixelBufferIOSurfacePropertiesKey: [:]
        ]
        CVPixelBufferPoolCreate(kCFAllocatorDefault, nil, pixelBufferAttributes, &bufferPool)
        bufferAuxAttributes = [kCVPixelBufferPoolAllocationThresholdKey: 5]

        streamSource.device = device
        streamSink.device = device
        let videoStreamFormat = CMIOExtensionStreamFormat(
            formatDescription: videoDescription,
            maxFrameDuration: CMTime(value: 1, timescale: Int32(CameraConfig.frameRate)),
            minFrameDuration: CMTime(value: 1, timescale: Int32(CameraConfig.frameRate)),
            validFrameDurations: nil
        )
        streamSource.streamFormat = videoStreamFormat
        streamSink.streamFormat = videoStreamFormat

        do {
            try device.addStream(streamSource.stream)
            try device.addStream(streamSink.stream)
        } catch {
            fatalError("Failed to add stream: \(error.localizedDescription)")
        }
    }

    var availableProperties: Set<CMIOExtensionProperty> {
        [.deviceTransportType, .deviceModel]
    }

    func deviceProperties(forProperties properties: Set<CMIOExtensionProperty>) throws -> CMIOExtensionDeviceProperties {
        let deviceProperties = CMIOExtensionDeviceProperties(dictionary: [:])
        if properties.contains(.deviceTransportType) {
            deviceProperties.transportType = kIOAudioDeviceTransportTypeVirtual
        }
        if properties.contains(.deviceModel) {
            deviceProperties.model = "Floater Live Timer"
        }
        return deviceProperties
    }

    func setDeviceProperties(_ deviceProperties: CMIOExtensionDeviceProperties) throws {}

    func startStreaming() {
        guard bufferPool != nil else { return }
        streamingCounter += 1

        timer = DispatchSource.makeTimerSource(flags: .strict, queue: timerQueue)
        timer?.schedule(deadline: .now(), repeating: 1.0 / Double(CameraConfig.frameRate), leeway: .seconds(0))
        timer?.setEventHandler { [weak self] in
            guard let self, !self.sinkActive else { return }
            self.renderAndSendFrame()
        }
        timer?.resume()
    }

    func stopStreaming() {
        if streamingCounter > 1 {
            streamingCounter -= 1
        } else {
            streamingCounter = 0
            timer?.cancel()
            timer = nil
        }
    }

    // - MARK: Sink input (host app → extension)

    func startStreamingSink(client: CMIOExtensionClient) {
        sinkStreamingCounter += 1
        sinkActive = true
        consumeBuffer(client)
    }

    func stopStreamingSink() {
        sinkActive = false
        if sinkStreamingCounter > 1 {
            sinkStreamingCounter -= 1
        } else {
            sinkStreamingCounter = 0
        }
    }

    /// Forwards a buffer received on the sink stream out through the source
    /// stream (to camera consumers such as Keynote).
    private func consumeBuffer(_ client: CMIOExtensionClient) {
        guard sinkActive else { return }
        streamSink.stream.consumeSampleBuffer(from: client) { [weak self] sampleBuffer, sequenceNumber, _, _, _ in
            guard let self else { return }
            if let sampleBuffer {
                if self.streamingCounter > 0 {
                    self.streamSource.stream.send(
                        sampleBuffer,
                        discontinuity: [],
                        hostTimeInNanoseconds: UInt64(sampleBuffer.presentationTimeStamp.seconds * Double(NSEC_PER_SEC))
                    )
                }
                let output = CMIOExtensionScheduledOutput(
                    sequenceNumber: sequenceNumber,
                    hostTimeInNanoseconds: UInt64(sampleBuffer.presentationTimeStamp.seconds * Double(NSEC_PER_SEC))
                )
                self.streamSink.stream.notifyScheduledOutputChanged(output)
            }
            self.consumeBuffer(client)
        }
    }

    private func renderAndSendFrame() {
        var pixelBuffer: CVPixelBuffer?
        guard CVPixelBufferPoolCreatePixelBufferWithAuxAttributes(kCFAllocatorDefault, bufferPool, bufferAuxAttributes, &pixelBuffer) == kCVReturnSuccess,
              let pixelBuffer else {
            os_log(.error, "out of pixel buffers")
            return
        }

        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let colorSpace = CGColorSpaceCreateDeviceRGB()

        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(pixelBuffer),
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
            space: colorSpace,
            bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue
        ) else { return }

        let graphicsContext = NSGraphicsContext(cgContext: context, flipped: false)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = graphicsContext

        let dstRect = CGRect(x: 0, y: 0, width: width, height: height)
        context.clear(dstRect)
        context.setFillColor(CGColor(gray: 0.05, alpha: 1))
        context.fill(dstRect)

        FloaterFrameRenderer.drawPlaceholder(in: context, width: width, height: height)

        NSGraphicsContext.restoreGraphicsState()

        var sampleBuffer: CMSampleBuffer?
        var timingInfo = CMSampleTimingInfo()
        timingInfo.presentationTimeStamp = CMClockGetTime(CMClockGetHostTimeClock())
        let err = CMSampleBufferCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            dataReady: true,
            makeDataReadyCallback: nil,
            refcon: nil,
            formatDescription: videoDescription,
            sampleTiming: &timingInfo,
            sampleBufferOut: &sampleBuffer
        )
        if err == noErr, let sampleBuffer {
            streamSource.stream.send(sampleBuffer, discontinuity: [], hostTimeInNanoseconds: UInt64(timingInfo.presentationTimeStamp.seconds * Double(NSEC_PER_SEC)))
        }
    }
}

final class FloaterStreamSource: NSObject, CMIOExtensionStreamSource {

    private(set) var stream: CMIOExtensionStream!
    var device: CMIOExtensionDevice!
    var streamFormat: CMIOExtensionStreamFormat!

    override init() {
        super.init()
        let streamID = UUID()
        stream = CMIOExtensionStream(localizedName: "Floater.Video", streamID: streamID, direction: .source, clockType: .hostTime, source: self)
    }

    var formats: [CMIOExtensionStreamFormat] {
        [streamFormat]
    }

    var activeFormatIndex: Int = 0

    var availableProperties: Set<CMIOExtensionProperty> {
        [.streamActiveFormatIndex, .streamFrameDuration]
    }

    func streamProperties(forProperties properties: Set<CMIOExtensionProperty>) throws -> CMIOExtensionStreamProperties {
        let streamProperties = CMIOExtensionStreamProperties(dictionary: [:])
        if properties.contains(.streamActiveFormatIndex) {
            streamProperties.activeFormatIndex = 0
        }
        if properties.contains(.streamFrameDuration) {
            streamProperties.frameDuration = CMTime(value: 1, timescale: Int32(CameraConfig.frameRate))
        }
        return streamProperties
    }

    func setStreamProperties(_ streamProperties: CMIOExtensionStreamProperties) throws {
        if let activeFormatIndex = streamProperties.activeFormatIndex {
            self.activeFormatIndex = activeFormatIndex
        }
    }

    func authorizedToStartStream(for client: CMIOExtensionClient) -> Bool { true }

    func startStream() throws {
        guard let deviceSource = device.source as? FloaterDeviceSource else {
            fatalError("Unexpected source type")
        }
        deviceSource.startStreaming()
    }

    func stopStream() throws {
        guard let deviceSource = device.source as? FloaterDeviceSource else {
            fatalError("Unexpected source type")
        }
        deviceSource.stopStreaming()
    }
}

/// The sink stream the host app writes into; frames received here are forwarded
/// out through the source stream to camera consumers.
final class FloaterStreamSink: NSObject, CMIOExtensionStreamSource {

    private(set) var stream: CMIOExtensionStream!
    var device: CMIOExtensionDevice!
    var streamFormat: CMIOExtensionStreamFormat!

    private var client: CMIOExtensionClient?

    override init() {
        super.init()
        let streamID = UUID()
        stream = CMIOExtensionStream(localizedName: "Floater.Video.Sink", streamID: streamID, direction: .sink, clockType: .hostTime, source: self)
    }

    var formats: [CMIOExtensionStreamFormat] {
        [streamFormat]
    }

    var activeFormatIndex: Int = 0

    var availableProperties: Set<CMIOExtensionProperty> {
        [.streamActiveFormatIndex, .streamFrameDuration, .streamSinkBufferQueueSize, .streamSinkBuffersRequiredForStartup]
    }

    func streamProperties(forProperties properties: Set<CMIOExtensionProperty>) throws -> CMIOExtensionStreamProperties {
        let streamProperties = CMIOExtensionStreamProperties(dictionary: [:])
        if properties.contains(.streamActiveFormatIndex) {
            streamProperties.activeFormatIndex = 0
        }
        if properties.contains(.streamFrameDuration) {
            streamProperties.frameDuration = CMTime(value: 1, timescale: Int32(CameraConfig.frameRate))
        }
        if properties.contains(.streamSinkBufferQueueSize) {
            streamProperties.sinkBufferQueueSize = 1
        }
        if properties.contains(.streamSinkBuffersRequiredForStartup) {
            streamProperties.sinkBuffersRequiredForStartup = 1
        }
        return streamProperties
    }

    func setStreamProperties(_ streamProperties: CMIOExtensionStreamProperties) throws {
        if let activeFormatIndex = streamProperties.activeFormatIndex {
            self.activeFormatIndex = activeFormatIndex
        }
    }

    func authorizedToStartStream(for client: CMIOExtensionClient) -> Bool {
        self.client = client
        return true
    }

    func startStream() throws {
        guard let deviceSource = device.source as? FloaterDeviceSource else {
            fatalError("Unexpected source type")
        }
        if let client {
            deviceSource.startStreamingSink(client: client)
        }
    }

    func stopStream() throws {
        guard let deviceSource = device.source as? FloaterDeviceSource else {
            fatalError("Unexpected source type")
        }
        deviceSource.stopStreamingSink()
    }
}
