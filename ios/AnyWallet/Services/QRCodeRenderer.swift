import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

enum QRCodeRenderer {
    private static let context = CIContext(options: [.useSoftwareRenderer: false])

    static func image(for payload: Data, scale: CGFloat = 8) -> UIImage? {
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
}
