// Resample the checked-in artwork; see distribution/branding/README.md.
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let sourceURL = root.appendingPathComponent("distribution/branding/screenstride-amber-refined-v1.png")
guard let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil),
      let artwork = CGImageSourceCreateImageAtIndex(source, 0, nil),
      artwork.width == artwork.height else {
    fatalError("Expected square icon artwork at \(sourceURL.path)")
}

func exportIcon(size: Int, output: URL) throws {
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    // Opaque, full-square sRGB output for the asset catalog.
    let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8,
        bytesPerRow: size * 4, space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    context.interpolationQuality = .high
    context.draw(artwork, in: CGRect(x: 0, y: 0, width: size, height: size))
    let destination = CGImageDestinationCreateWithURL(output as CFURL,
        UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, context.makeImage()!, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw NSError(domain: "Icon", code: 1)
    }
}

for platform in ["MacHelper"] {
    let catalog = root.appendingPathComponent("\(platform)/Assets.xcassets")
    let set = catalog.appendingPathComponent("AppIcon.appiconset")
    try FileManager.default.createDirectory(at: set, withIntermediateDirectories: true)
    try Data("{\"info\":{\"author\":\"xcode\",\"version\":1}}\n".utf8)
        .write(to: catalog.appendingPathComponent("Contents.json"))
    var images: [[String: String]] = []
    if platform == "App" {
        try exportIcon(size: 1024, output: set.appendingPathComponent("AppIcon.png"))
        images = [["filename": "AppIcon.png", "idiom": "universal",
                   "platform": "ios", "size": "1024x1024"]]
    } else {
        for size in [16, 32, 128, 256, 512] {
            for scale in [1, 2] {
                let name = "icon_\(size)x\(size)@\(scale)x.png"
                try exportIcon(size: size * scale, output: set.appendingPathComponent(name))
                images.append(["filename": name, "idiom": "mac",
                               "size": "\(size)x\(size)", "scale": "\(scale)x"])
            }
        }
    }
    let json = try JSONSerialization.data(withJSONObject: [
        "images": images, "info": ["author": "xcode", "version": 1]
    ], options: [.prettyPrinted, .sortedKeys])
    try json.write(to: set.appendingPathComponent("Contents.json"))
}