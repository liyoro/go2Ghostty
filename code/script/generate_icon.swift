import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let outputURL = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "Resources/AppIcon.iconset")
let icnsURL = URL(fileURLWithPath: CommandLine.arguments.dropFirst().dropFirst().first ?? "Resources/AppIcon.icns")
try? FileManager.default.removeItem(at: outputURL)
try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)

let sizes: [(name: String, pixels: Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for size in sizes {
    try drawIconData(pixels: size.pixels).write(to: outputURL.appendingPathComponent(size.name))
}

try writeICNS(to: icnsURL)

func drawIconData(pixels: Int) throws -> Data {
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
    guard let context = CGContext(
        data: nil,
        width: pixels,
        height: pixels,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        throw iconError("Unable to create bitmap context")
    }

    let s = CGFloat(pixels) / 1024.0
    context.setAllowsAntialiasing(true)
    context.setShouldAntialias(true)
    context.clear(CGRect(x: 0, y: 0, width: pixels, height: pixels))

    let outerRect = CGRect(x: 52 * s, y: 52 * s, width: 920 * s, height: 920 * s)
    let outerPath = CGPath(roundedRect: outerRect, cornerWidth: 210 * s, cornerHeight: 210 * s, transform: nil)
    context.addPath(outerPath)
    context.clip()

    let gradient = CGGradient(
        colorsSpace: colorSpace,
        colors: [
            cgColor(0.045, 0.055, 0.065, 1),
            cgColor(0.14, 0.34, 0.36, 1),
            cgColor(0.60, 0.94, 0.70, 1)
        ] as CFArray,
        locations: [0, 0.58, 1]
    )
    if let gradient {
        context.drawLinearGradient(
            gradient,
            start: CGPoint(x: 120 * s, y: 920 * s),
            end: CGPoint(x: 920 * s, y: 80 * s),
            options: []
        )
    }

    context.resetClip()
    context.addPath(outerPath)
    context.setStrokeColor(cgColor(0.82, 1.0, 0.88, 0.28))
    context.setLineWidth(10 * s)
    context.strokePath()

    let terminalRect = CGRect(x: 145 * s, y: 198 * s, width: 734 * s, height: 628 * s)
    let terminalPath = CGPath(roundedRect: terminalRect, cornerWidth: 86 * s, cornerHeight: 86 * s, transform: nil)
    context.addPath(terminalPath)
    context.setFillColor(cgColor(0.055, 0.064, 0.072, 0.96))
    context.fillPath()
    context.addPath(terminalPath)
    context.setStrokeColor(cgColor(0.86, 1.0, 0.92, 0.34))
    context.setLineWidth(8 * s)
    context.strokePath()

    let barRect = CGRect(x: terminalRect.minX, y: terminalRect.maxY - 128 * s, width: terminalRect.width, height: 128 * s)
    let barPath = CGPath(roundedRect: barRect, cornerWidth: 86 * s, cornerHeight: 86 * s, transform: nil)
    context.addPath(barPath)
    context.setFillColor(cgColor(0.105, 0.135, 0.145, 1))
    context.fillPath()

    drawDot(context, x: 220, y: 740, s: s, color: cgColor(0.98, 0.34, 0.34, 1))
    drawDot(context, x: 286, y: 740, s: s, color: cgColor(1.0, 0.77, 0.28, 1))
    drawDot(context, x: 352, y: 740, s: s, color: cgColor(0.38, 0.87, 0.48, 1))
    drawPrompt(context, s: s)
    drawGhost(context, s: s)

    guard let image = context.makeImage() else {
        throw iconError("Unable to create image")
    }

    let data = NSMutableData()
    guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else {
        throw iconError("Unable to create PNG destination")
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw iconError("Unable to encode PNG")
    }
    return data as Data
}

func drawDot(_ context: CGContext, x: CGFloat, y: CGFloat, s: CGFloat, color: CGColor) {
    context.setFillColor(color)
    context.fillEllipse(in: CGRect(x: (x - 18) * s, y: (y - 18) * s, width: 36 * s, height: 36 * s))
}

func drawPrompt(_ context: CGContext, s: CGFloat) {
    context.setStrokeColor(cgColor(0.58, 1.0, 0.72, 1))
    context.setLineWidth(30 * s)
    context.setLineCap(.round)
    context.setLineJoin(.round)
    context.beginPath()
    context.move(to: CGPoint(x: 244 * s, y: 548 * s))
    context.addLine(to: CGPoint(x: 330 * s, y: 610 * s))
    context.addLine(to: CGPoint(x: 244 * s, y: 672 * s))
    context.strokePath()

    context.beginPath()
    context.move(to: CGPoint(x: 395 * s, y: 548 * s))
    context.addLine(to: CGPoint(x: 552 * s, y: 548 * s))
    context.strokePath()
}

func drawGhost(_ context: CGContext, s: CGFloat) {
    context.beginPath()
    context.move(to: CGPoint(x: 635 * s, y: 390 * s))
    context.addCurve(to: CGPoint(x: 785 * s, y: 390 * s), control1: CGPoint(x: 670 * s, y: 300 * s), control2: CGPoint(x: 750 * s, y: 300 * s))
    context.addLine(to: CGPoint(x: 785 * s, y: 548 * s))
    context.addCurve(to: CGPoint(x: 710 * s, y: 630 * s), control1: CGPoint(x: 785 * s, y: 598 * s), control2: CGPoint(x: 755 * s, y: 630 * s))
    context.addCurve(to: CGPoint(x: 635 * s, y: 548 * s), control1: CGPoint(x: 665 * s, y: 630 * s), control2: CGPoint(x: 635 * s, y: 598 * s))
    context.closePath()
    context.setFillColor(cgColor(0.86, 1.0, 0.91, 1))
    context.fillPath()

    context.setFillColor(cgColor(0.07, 0.09, 0.095, 1))
    context.fillEllipse(in: CGRect(x: 674 * s, y: 526 * s, width: 24 * s, height: 34 * s))
    context.fillEllipse(in: CGRect(x: 726 * s, y: 526 * s, width: 24 * s, height: 34 * s))

    context.setStrokeColor(cgColor(0.07, 0.09, 0.095, 1))
    context.setLineWidth(8 * s)
    context.setLineCap(.round)
    context.beginPath()
    context.move(to: CGPoint(x: 694 * s, y: 490 * s))
    context.addCurve(to: CGPoint(x: 732 * s, y: 490 * s), control1: CGPoint(x: 704 * s, y: 476 * s), control2: CGPoint(x: 722 * s, y: 476 * s))
    context.strokePath()
}

func writeICNS(to url: URL) throws {
    let chunks: [(type: String, pixels: Int)] = [
        ("icp4", 16),
        ("icp5", 32),
        ("icp6", 64),
        ("ic07", 128),
        ("ic08", 256),
        ("ic09", 512),
        ("ic10", 1024)
    ]

    var body = Data()
    for chunk in chunks {
        let png = try drawIconData(pixels: chunk.pixels)
        appendFourCC(chunk.type, to: &body)
        appendUInt32BE(UInt32(png.count + 8), to: &body)
        body.append(png)
    }

    var file = Data()
    appendFourCC("icns", to: &file)
    appendUInt32BE(UInt32(body.count + 8), to: &file)
    file.append(body)
    try file.write(to: url)
}

func cgColor(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat) -> CGColor {
    CGColor(red: r, green: g, blue: b, alpha: a)
}

func appendFourCC(_ string: String, to data: inout Data) {
    data.append(contentsOf: string.utf8)
}

func appendUInt32BE(_ value: UInt32, to data: inout Data) {
    var bigEndian = value.bigEndian
    withUnsafeBytes(of: &bigEndian) { bytes in
        data.append(contentsOf: bytes)
    }
}

func iconError(_ message: String) -> NSError {
    NSError(domain: "go2Ghostty.icon", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
}
