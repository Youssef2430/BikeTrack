import AppKit
let outputs: [(String, Int)] = [("AppIcon", 1024), ("Notification38", 48), ("Notification42", 55), ("Launcher38", 80), ("Launcher40", 88), ("Launcher41", 92), ("Launcher44", 100), ("Launcher45", 102), ("Launcher49", 108), ("Quick38", 172), ("Quick42", 196), ("Quick44", 216), ("Quick45", 234), ("Quick49", 258)]
for (name, pixels) in outputs {
let context = CGContext(data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: pixels * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
NSGraphicsContext.current!.cgContext.scaleBy(x: Double(pixels) / 1024, y: Double(pixels) / 1024)
let size = NSSize(width: 1024, height: 1024)
NSColor(calibratedRed: 0.045, green: 0.06, blue: 0.045, alpha: 1).setFill()
NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()
let lime = NSColor(calibratedRed: 0.77, green: 0.98, blue: 0.32, alpha: 1)
lime.setStroke()
for x in [180.0, 594.0] {
    let wheel = NSBezierPath(ovalIn: NSRect(x: x, y: 280, width: 250, height: 250))
    wheel.lineWidth = 29
    wheel.stroke()
}
let frame = NSBezierPath()
frame.lineWidth = 33
frame.lineCapStyle = .round
frame.lineJoinStyle = .round
frame.move(to: NSPoint(x: 305, y: 405))
frame.line(to: NSPoint(x: 447, y: 631))
frame.line(to: NSPoint(x: 555, y: 405))
frame.close()
frame.move(to: NSPoint(x: 447, y: 631))
frame.line(to: NSPoint(x: 640, y: 631))
frame.line(to: NSPoint(x: 555, y: 405))
frame.move(to: NSPoint(x: 719, y: 405))
frame.line(to: NSPoint(x: 613, y: 705))
frame.line(to: NSPoint(x: 696, y: 705))
frame.move(to: NSPoint(x: 399, y: 680))
frame.line(to: NSPoint(x: 479, y: 680))
frame.move(to: NSPoint(x: 447, y: 631))
frame.line(to: NSPoint(x: 430, y: 680))
frame.stroke()
NSGraphicsContext.restoreGraphicsState()
let bitmap = NSBitmapImageRep(cgImage: context.makeImage()!)
let url = URL(fileURLWithPath: "WatchApp/Assets.xcassets/AppIcon.appiconset/\(name).png")
try bitmap.representation(using: .png, properties: [:])!.write(to: url)

}
