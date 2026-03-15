import CoreImage
import CoreVideo
import Metal

class MilkyFilterPipeline {

    var intensity: Float = 0.7

    private let ciContext: CIContext

    // Output pool — BGRA for Flutter Texture compatibility
    private var outputBufferPool: CVPixelBufferPool?
    private var outputBufferWidth:  Int = 0
    private var outputBufferHeight: Int = 0

    init(context: CIContext) {
        self.ciContext = context
    }

    func process(pixelBuffer: CVPixelBuffer) -> CVPixelBuffer? {
        let width  = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)

        if outputBufferPool == nil
        || outputBufferWidth  != width
        || outputBufferHeight != height {
            outputBufferPool   = makePool(width: width, height: height)
            outputBufferWidth  = width
            outputBufferHeight = height
        }

        guard let pool = outputBufferPool else { return nil }

        // CIImage natively understands YUV 420 — no manual conversion needed.
        // Passing the color space tells CoreImage exactly how to interpret
        // the YCbCr planes, preserving accurate colors through the filter chain.
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
        let source = CIImage(
            cvPixelBuffer: pixelBuffer,
            options: [.colorSpace: colorSpace]
        )

        let filtered = applyMilkyFilter(to: source)

        var outputBuffer: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &outputBuffer)
        guard let output = outputBuffer else { return nil }

        // Render onto Metal GPU — output is BGRA (Flutter Texture compatible)
        ciContext.render(
            filtered,
            to: output,
            bounds: filtered.extent,
            colorSpace: colorSpace
        )
        return output
    }

    // MARK: - Filter graph

    private func applyMilkyFilter(to image: CIImage) -> CIImage {
        let t = Double(intensity)   // shorthand

        // ── Step 1: Gaussian blur (light softening) ──────────────────────────
        // sigma 0→3.5 — subtle at low intensity, soft at high
        let blurred = image
        .applyingGaussianBlur(sigma: t * 3.5)
        .cropped(to: image.extent)

        // ── Step 2: Bloom — screen-blend the blur back over the original ─────
        // Screen blend formula: 1-(1-a)(1-b) — brightens highlights softly
        // We composite a semi-transparent blurred layer over the original.
        let bloomAlpha  = t * 0.40   // 0→0.40 contribution
        let bloomLayer  = blurred.applyingFilter("CIColorMatrix", parameters: [
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: CGFloat(bloomAlpha))
        ])
        guard let screenBlend = CIFilter(name: "CIScreenBlendMode",
            parameters: [
                kCIInputImageKey:           bloomLayer,
                kCIInputBackgroundImageKey: image
            ]
        )?.outputImage else { return image }

        // ── Step 3: Color grade ───────────────────────────────────────────────
        // Raise brightness, reduce contrast, slight desaturate
        let graded = screenBlend.applyingFilter("CIColorControls", parameters: [
            kCIInputBrightnessKey: t * 0.07,          //  0 → +0.07
            kCIInputContrastKey:   1.0 - t * 0.14,   //  1.0 → 0.86
            kCIInputSaturationKey: 1.0 - t * 0.10    //  1.0 → 0.90
        ])

        // ── Step 4: Lift blacks + cool milky tone ────────────────────────────
        // CIColorPolynomial: output = a + b·x  (x = input channel value)
        // Raising the constant (a) lifts shadows — gives the milky faded look.
        // A slightly higher blue lift (0.055 vs 0.035) adds a cool white tone.
        let lifted = graded.applyingFilter("CIColorPolynomial", parameters: [
            "inputRedCoefficients":   CIVector(x: t * 0.035, y: 1.0 - t * 0.035, z: 0, w: 0),
            "inputGreenCoefficients": CIVector(x: t * 0.035, y: 1.0 - t * 0.035, z: 0, w: 0),
            "inputBlueCoefficients":  CIVector(x: t * 0.055, y: 1.0 - t * 0.055, z: 0, w: 0)
        ])

        return lifted
    }

    // MARK: - Buffer pool

    private func makePool(width: Int, height: Int) -> CVPixelBufferPool? {
        // Output must be BGRA — Flutter's Texture widget requires it
        let attrs: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey           as String: width,
            kCVPixelBufferHeightKey          as String: height,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:], // GPU shared memory
            kCVPixelBufferMetalCompatibilityKey  as String: true
        ]
        var pool: CVPixelBufferPool?
        CVPixelBufferPoolCreate(kCFAllocatorDefault, nil, attrs as CFDictionary, &pool)
        return pool
    }
}