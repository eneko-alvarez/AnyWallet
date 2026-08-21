import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

enum BarcodeRenderer {
    private static let context = CIContext(options: [.useSoftwareRenderer: false])

    static func image(for payload: Data, format: BarcodeFormat, scale: CGFloat = 8) -> UIImage? {
        switch format {
        case .qr:
            qrImage(for: payload, scale: scale)
        case .code128:
            code128Image(for: payload, scale: scale)
        case .pdf417:
            pdf417Image(for: payload, scale: scale)
        case .aztec:
            aztecImage(for: payload, scale: scale)
        }
    }

    private static func qrImage(for payload: Data, scale: CGFloat) -> UIImage? {
        for correctionLevel in ["M", "L"] {
            let filter = CIFilter.qrCodeGenerator()
            filter.message = payload
            filter.correctionLevel = correctionLevel
            guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: scale, y: scale)),
                  let cgImage = context.createCGImage(output, from: output.extent) else {
                continue
            }
            return UIImage(cgImage: cgImage)
        }
        return nil
    }

    private static func code128Image(for payload: Data, scale: CGFloat) -> UIImage? {
        let filter = CIFilter.code128BarcodeGenerator()
        filter.message = payload
        filter.quietSpace = 7
        return rendered(filter.outputImage, scaleX: scale, scaleY: scale)
    }

    private static func pdf417Image(for payload: Data, scale: CGFloat) -> UIImage? {
        let filter = CIFilter.pdf417BarcodeGenerator()
        filter.message = payload
        return rendered(filter.outputImage, scaleX: scale, scaleY: scale)
    }

    private static func aztecImage(for payload: Data, scale: CGFloat) -> UIImage? {
        let filter = CIFilter.aztecCodeGenerator()
        filter.message = payload
        return rendered(filter.outputImage, scaleX: scale, scaleY: scale)
    }

    private static func rendered(_ image: CIImage?, scaleX: CGFloat, scaleY: CGFloat) -> UIImage? {
        guard let output = image?.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY)),
              let cgImage = context.createCGImage(output, from: output.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

// Kept as a small compatibility wrapper for existing callers and tests.
enum QRCodeRenderer {
    static func image(for payload: Data, scale: CGFloat = 8) -> UIImage? {
        BarcodeRenderer.image(for: payload, format: .qr, scale: scale)
    }
}
