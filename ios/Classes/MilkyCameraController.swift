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
    private let sessionQueue = DispatchQueue(label: "milky.camera.session", qos: .userInteractive)

    // GPU
    private let ciContext: CIContext
    private let filterPipeline: MilkyFilterPipeline

    // Latest processed frame — accessed from Flutter texture callback
    private var latestPixelBuffer: CVPixelBuffer?
    private let pixelBufferLock = NSLock()

    // Flutter texture handle
    private var flutterTexture: MilkyFlutterTexture?

    init(textureRegistry: FlutterTextureRegistry) {
        self.textureRegistry = textureRegistry

        // Force Metal GPU context — never use CPU renderer
        let metalDevice = MTLCreateSystemDefaultDevice()!
        self.ciContext = CIContext(mtlDevice: metalDevice, options: [
            .workingColorSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
            .outputColorSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
            .useSoftwareRenderer: false   // GPU only
        ])
        self.filterPipeline = MilkyFilterPipeline(context: ciContext)
    }

    func start(completion: @escaping (Int64?, Error?) -> Void) {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            guard let self = self, granted else {
                completion(nil, NSError(domain: "MilkyCamera", code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Camera permission denied"]))
                return
            }
            self.sessionQueue.async {
                do {
                    try self.setupSession()
                    let texture = MilkyFlutterTexture(controller: self)
                    let id = self.textureRegistry.register(texture)
                    self.textureId = id
                    self.flutterTexture = texture
                    self.captureSession.startRunning()
                    DispatchQueue.main.async { completion(id, nil) }
                } catch {
                    DispatchQueue.main.async { completion(nil, error) }
                }
            }
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

    // Called by MilkyFlutterTexture.copyPixelBuffer()
    func copyLatestPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
        pixelBufferLock.lock()
        defer { pixelBufferLock.unlock() }
        guard let pb = latestPixelBuffer else { return nil }
        return Unmanaged.passRetained(pb)
    }

    // MARK: - Private setup

    private func setupSession() throws {
        captureSession.beginConfiguration()
        captureSession.sessionPreset = .hd1280x720

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera,
            for: .video,
            position: .front),
        let input = try? AVCaptureDeviceInput(device: device),
        captureSession.canAddInput(input)
        else { throw NSError(domain: "MilkyCamera", code: -2,
            userInfo: [NSLocalizedDescriptionKey: "Cannot open front camera"]) }

        captureSession.addInput(input)

        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: sessionQueue)

        guard captureSession.canAddOutput(videoOutput) else {
            throw NSError(domain: "MilkyCamera", code: -3,
                userInfo: [NSLocalizedDescriptionKey: "Cannot add video output"])
        }
        captureSession.addOutput(videoOutput)

        // Correct orientation for front camera
        videoOutput.connection(with: .video)?.videoOrientation = .portrait
        videoOutput.connection(with: .video)?.isVideoMirrored = true

        captureSession.commitConfiguration()
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension MilkyCameraController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput,
    didOutput sampleBuffer: CMSampleBuffer,
    from connection: AVCaptureConnection) {

        guard let rawPixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        // Apply GPU filter pipeline — returns a new CVPixelBuffer still on GPU
        guard let filtered = filterPipeline.process(pixelBuffer: rawPixelBuffer) else { return }

        pixelBufferLock.lock()
        latestPixelBuffer = filtered
        pixelBufferLock.unlock()

        // Notify Flutter to pull a new frame
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