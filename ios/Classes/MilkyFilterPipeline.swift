import CoreImage
import CoreVideo
import Metal

class MilkyFilterPipeline {

    // Public: tweak at runtime from Flutter slider
    var intensity: Float = 0.7   // 0.0 = no filter, 1.0 = full milky

    private let ciContext: CIContext

    // Reusable output pixel buffer pool — avoids per-frame allocation
    private var outputBufferPool: CVPixelBufferPool?
    private var outputBufferWidth: Int = 0
    private var outputBufferHeight: Int = 0

    init(context: CIContext) {
        self.ciContext = context
    }

    func process(pixelBuffer: CVPixelBuffer) -> CVPixelBuffer? {
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)

        // Lazy-init pool if size changed
        if outputBufferPool == nil || outputBufferWidth != width || outputBufferHeight != height {
            outputBufferPool = makePool(width: width, height: height)
            outputBufferWidth = width
            outputBufferHeight = height
        }

        guard let pool = outputBufferPool else { return nil }

        let source = CIImage(cvPixelBuffer: pixelBuffer)
        let filtered = applyMilkyFilter(to: source, width: width, height: height)

        var outputBuffer: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &outputBuffer)
        guard let output = outputBuffer else { return nil }

        // Render the CIFilter graph onto the Metal GPU — nothing touches CPU here
        ciContext.render(filtered, to: output)
        return output
    }

    // MARK: - The milky filter graph

    private func applyMilkyFilter(to image: CIImage, width: Int, height: Int) -> CIImage {

        // --- Step 1: Gaussian blur (light softening) ---
        // radius scales with intensity: 0.0→0px, 1.0→4px
        let blurRadius = Double(intensity) * 4.0
        let blurred = image.applyingGaussianBlur(sigma: blurRadius)
        .cropped(to: image.extent)  // blur expands edges, crop back

        // --- Step 2: Bloom — blend blurred copy back over original ---
        // Screen blend: result = 1 - (1-a)(1-b)  — lightens highlights softly
        // We use CIBlendWithMask approach for intensity control
        let bloomStrength = Double(intensity) * 0.45   // 0..0.45 bloom contribution
        guard let bloomFilter = CIFilter(name: "CIScreenBlendMode") else { return image }
        bloomFilter.setValue(blurred, forKey: kCIInputImageKey)
        bloomFilter.setValue(
            image.applyingFilter("CIColorControls", parameters: [
                kCIInputBrightnessKey: 0.0,
                kCIInputContrastKey:   1.0,
                kCIInputSaturationKey: 1.0
            ]),
            forKey: kCIInputBackgroundImageKey
        )
        let bloomed = (bloomFilter.outputImage ?? image)

        // Blend between original and bloomed by intensity
        let bloomBlended = blendImages(from: image, to: bloomed, amount: bloomStrength)

        // --- Step 3: Color grade (the "milky" look) ---
        // Lower contrast + raise brightness + very slight warmth + slight desaturate
        let brightnessBoost = Double(intensity) * 0.08   //  0..+0.08
        let contrastReduction = 1.0 - Double(intensity) * 0.15  //  1.0..0.85
        let saturationReduction = 1.0 - Double(intensity) * 0.12 // 1.0..0.88

        let colorGraded = bloomBlended.applyingFilter("CIColorControls", parameters: [
            kCIInputBrightnessKey: brightnessBoost,
            kCIInputContrastKey:   contrastReduction,
            kCIInputSaturationKey: saturationReduction
        ])

        // Slightly raise black point (milky whites + lifted shadows)
        let whitePointLifted = colorGraded.applyingFilter("CIColorPolynomial", parameters: [
            "inputRedCoefficients":   CIVector(x: Double(intensity) * 0.04, y: 0.96, z: 0, w: 0),
            "inputGreenCoefficients": CIVector(x: Double(intensity) * 0.04, y: 0.96, z: 0, w: 0),
            "inputBlueCoefficients":  CIVector(x: Double(intensity) * 0.06, y: 0.94, z: 0, w: 0)
            // Slightly more blue lift = cooler milky tone (adjust to taste)
        ])

        return whitePointLifted
    }

    // MARK: - Helpers

    /// Linear blend between two CIImages using CIBlendWithAlphaMask
    private func blendImages(from a: CIImage, to b: CIImage, amount: Double) -> CIImage {
        let clamped = min(max(amount, 0), 1)
        guard let blend = CIFilter(name: "CISourceOverCompositing") else { return a }
        // Use opacity on b to control blend amount
        let bWithAlpha = b.applyingFilter("CIColorMatrix", parameters: [
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: CGFloat(clamped))
        ])
        blend.setValue(bWithAlpha, forKey: kCIInputImageKey)
        blend.setValue(a, forKey: kCIInputBackgroundImageKey)
        return blend.outputImage ?? a
    }

    private func makePool(width: Int, height: Int) -> CVPixelBufferPool? {
        let attrs: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:],  // enables GPU-shared memory
            kCVPixelBufferMetalCompatibilityKey as String: true
        ]
        var pool: CVPixelBufferPool?
        CVPixelBufferPoolCreate(kCFAllocatorDefault, nil, attrs as CFDictionary, &pool)
        return pool
    }
}