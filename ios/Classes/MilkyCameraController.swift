import AVFoundation
import CoreImage
import Flutter
import Metal

class MilkyCameraController: NSObject {

    private let textureRegistry: FlutterTextureRegistry
    private var textureId: Int64 = -1

    // AVFoundation
    private let captureSession = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(
        label: "milky.camera.session",
        qos: .userInteractive,
        attributes: [],
        autoreleaseFrequency: .workItem  // prevents memory buildup per frame
    )

    // GPU
    private let ciContext: CIContext
    private let filterPipeline: MilkyFilterPipeline

    // Latest processed frame
    private var latestPixelBuffer: CVPixelBuffer?
    private let pixelBufferLock = NSLock()

    private var flutterTexture: MilkyFlutterTexture?

    init(textureRegistry: FlutterTextureRegistry) {
        self.textureRegistry = textureRegistry

        let metalDevice = MTLCreateSystemDefaultDevice()!

        // GPU-only CIContext with YUV-aware color space
        // workingFormat = RGBAh (16-bit half float) — more color depth internally
        self.ciContext = CIContext(mtlDevice: metalDevice, options: [
            .workingColorSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
            .outputColorSpace:  CGColorSpace(name: CGColorSpace.sRGB)!,
            .workingFormat:     CIFormat.RGBAh,   // 16-bit internal processing
            .useSoftwareRenderer: false,           // GPU only, never fall back to CPU
            .cacheIntermediates: false             // don't cache — saves VRAM per frame
        ])
        self.filterPipeline = MilkyFilterPipeline(context: ciContext)
    }

    func start(completion: @escaping (Int64?, Error?) -> Void) {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                guard let self else { return }
                if granted {
                    self.sessionQueue.async { self.setupAndStart(completion: completion) }
                } else {
                    completion(nil, Self.permissionError)
                }
            }
        case .authorized:
            sessionQueue.async { self.setupAndStart(completion: completion) }
        default:
            completion(nil, Self.permissionError)
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            self?.captureSession.stopRunning()
        }
        if textureId >= 0 {
            textureRegistry.unregisterTexture(textureId)
        }
    }

    func setFilterIntensity(_ intensity: Float) {
        filterPipeline.intensity = intensity
    }

    func copyLatestPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
        pixelBufferLock.lock()
        defer { pixelBufferLock.unlock() }
        guard let pb = latestPixelBuffer else { return nil }
        return Unmanaged.passRetained(pb)
    }

    // MARK: - Private

    private func setupAndStart(completion: @escaping (Int64?, Error?) -> Void) {
        do {
            try setupSession()
            let texture = MilkyFlutterTexture(controller: self)
            let id = textureRegistry.register(texture)
            textureId = id
            flutterTexture = texture
            captureSession.startRunning()
            DispatchQueue.main.async { completion(id, nil) }
        } catch {
            DispatchQueue.main.async { completion(nil, error) }
        }
    }

    private func setupSession() throws {
        captureSession.beginConfiguration()

        // 1080p — best quality without risking frame drops from filter overhead
        captureSession.sessionPreset = .hd1920x1080

        guard let device = AVCaptureDevice.default(
            .builtInWideAngleCamera, for: .video, position: .front),
        let input = try? AVCaptureDeviceInput(device: device),
        captureSession.canAddInput(input)
        else {
            throw NSError(domain: "MilkyCamera", code: -2,
                userInfo: [NSLocalizedDescriptionKey: "Cannot open front camera"])
        }
        captureSession.addInput(input)

        // Lock to 30fps — stable budget for filter chain
        try device.lockForConfiguration()
        device.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 30)
        device.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: 30)
        device.unlockForConfiguration()

        // YUV 420 full range — native camera sensor format, avoids BGRA conversion cost
        // kCVPixelFormatType_420YpCbCr8BiPlanarFullRange = '420f'
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String:
            kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
        ]
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: sessionQueue)

        guard captureSession.canAddOutput(videoOutput) else {
            throw NSError(domain: "MilkyCamera", code: -3,
                userInfo: [NSLocalizedDescriptionKey: "Cannot add video output"])
        }
        captureSession.addOutput(videoOutput)

        // Lens correction — fixes front camera barrel distortion
        if let connection = videoOutput.connection(with: .video) {
            connection.videoOrientation = .portrait
            connection.isVideoMirrored  = true

            // Enable lens distortion correction if available (iOS 13+)
            if connection.isCameraIntrinsicMatrixDeliverySupported {
                connection.isCameraIntrinsicMatrixDeliveryEnabled = true
            }
        }

        captureSession.commitConfiguration()
    }

    private static let permissionError = NSError(
        domain: "MilkyCamera", code: -1,
        userInfo: [NSLocalizedDescriptionKey: "Camera permission denied"]
    )
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension MilkyCameraController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput,
    didOutput sampleBuffer: CMSampleBuffer,
    from connection: AVCaptureConnection) {

        guard let rawPixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        guard let filtered = filterPipeline.process(pixelBuffer: rawPixelBuffer) else { return }

        pixelBufferLock.lock()
        latestPixelBuffer = filtered
        pixelBufferLock.unlock()

        textureRegistry.textureFrameAvailable(textureId)
    }
}

// MARK: - FlutterTexture

class MilkyFlutterTexture: NSObject, FlutterTexture {
    private weak var controller: MilkyCameraController?
    init(controller: MilkyCameraController) { self.controller = controller }

    func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
        return controller?.copyLatestPixelBuffer()
    }
}