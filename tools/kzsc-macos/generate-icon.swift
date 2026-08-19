import AppKit
import Foundation

let size = CGFloat(Int(CommandLine.arguments[1]) ?? 1024)
let output = URL(fileURLWithPath: CommandLine.arguments[2])
let sourceImage: NSImage? = {
    guard CommandLine.arguments.count > 3 else { return nil }
    return NSImage(contentsOf: URL(fileURLWithPath: CommandLine.arguments[3]))
}()
let pixels = Int(size)
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                           isPlanar: false, colorSpaceName: .deviceRGB,
                           bitmapFormat: .alphaFirst, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
NSColor.clear.setFill()
NSRect(x: 0, y: 0, width: size, height: size).fill()

let background = NSColor(calibratedRed: 0.03, green: 0.20, blue: 0.34, alpha: 1)
background.setFill()
NSBezierPath(roundedRect: NSRect(x: 24, y: 24, width: size - 48, height: size - 48),
             xRadius: size * 0.22, yRadius: size * 0.22).fill()

if let sourceImage {
    // Use the shared Keenetic Manager artwork for the desktop icon. Crop it
    // to a square without distortion and let the platform scale each size.
    let sourceSize = sourceImage.size
    let scale = max(size / max(sourceSize.width, 1), size / max(sourceSize.height, 1))
    let drawSize = NSSize(width: sourceSize.width * scale, height: sourceSize.height * scale)
    let drawRect = NSRect(x: (size - drawSize.width) / 2,
                          y: (size - drawSize.height) / 2,
                          width: drawSize.width,
                          height: drawSize.height)
    sourceImage.draw(in: drawRect, from: .zero, operation: .sourceOver, fraction: 1)
} else {
// A compact Keenetic-inspired network mark fallback keeps local builds useful
// when the shared artwork cannot be decoded by an older macOS image stack.
NSColor.white.setStroke()
let k = NSBezierPath()
k.move(to: NSPoint(x: size * 0.30, y: size * 0.25))
k.line(to: NSPoint(x: size * 0.30, y: size * 0.75))
k.move(to: NSPoint(x: size * 0.30, y: size * 0.50))
k.line(to: NSPoint(x: size * 0.68, y: size * 0.75))
k.move(to: NSPoint(x: size * 0.30, y: size * 0.50))
k.line(to: NSPoint(x: size * 0.68, y: size * 0.25))
k.lineWidth = size * 0.095
k.lineCapStyle = .round
k.lineJoinStyle = .round
k.stroke()

NSColor(calibratedRed: 1.0, green: 0.55, blue: 0.14, alpha: 1).setFill()
for point in [NSPoint(x: size * 0.76, y: size * 0.25), NSPoint(x: size * 0.76, y: size * 0.50), NSPoint(x: size * 0.76, y: size * 0.75)] {
    NSBezierPath(ovalIn: NSRect(x: point.x - size * 0.045, y: point.y - size * 0.045,
                                width: size * 0.09, height: size * 0.09)).fill()
}
}
NSGraphicsContext.restoreGraphicsState()
try rep.representation(using: NSBitmapImageRep.FileType.png, properties: [:])!.write(to: output)
