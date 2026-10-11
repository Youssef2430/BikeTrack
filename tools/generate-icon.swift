import AppKit

// Run from the project root: swift tools/generate-icon.swift
// Geometry is vendored from Phosphor Icons (MIT); see assets/brand/PHOSPHOR-LICENSE.txt.
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let catalog = root.appendingPathComponent("WatchApp/Assets.xcassets/AppIcon.appiconset")
let source = try String(contentsOf: root.appendingPathComponent("assets/brand/bicycle-bold.svg"), encoding: .utf8)
guard let start = source.range(of: "<path"), let end = source.range(of: "</svg>") else {
    fatalError("The vendored bicycle SVG is missing its path")
}
let glyph = String(source[start.lowerBound..<end.lowerBound])

func artwork(rounded: Bool) -> String {
    """
    <svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
      <title>BikeTrack</title>
      <defs>
        <linearGradient id="lime" x1="0" y1="0" x2="0.8" y2="1">
          <stop stop-color="#DDFB84"/>
          <stop offset="0.55" stop-color="#C4F553"/>
          <stop offset="1" stop-color="#AAE43A"/>
        </linearGradient>
      </defs>
      <rect width="1024" height="1024" rx="\(rounded ? 224 : 0)" fill="url(#lime)"/>
      <g transform="translate(154 142) scale(2.8)" fill="#15251C">
        \(glyph)
      </g>
    </svg>
    """
}

func png(svg: String, pixels: Int, opaque: Bool) throws -> Data {
    guard let image = NSImage(data: Data(svg.utf8)),
          let context = CGContext(data: nil, width: pixels, height: pixels, bitsPerComponent: 8,
                                  bytesPerRow: pixels * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: (opaque ? CGImageAlphaInfo.noneSkipLast : .premultipliedLast).rawValue) else {
        fatalError("Could not create the SVG renderer")
    }
    // The Watch gets a full, opaque square; watchOS applies the circular mask.
    if opaque {
        context.setFillColor(CGColor(red: 196.0 / 255, green: 245.0 / 255, blue: 83.0 / 255, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: pixels, height: pixels))
    }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
    let rect = NSRect(x: 0, y: 0, width: pixels, height: pixels)
    image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1,
               respectFlipped: true, hints: [.interpolation: NSImageInterpolation.high])
    NSGraphicsContext.restoreGraphicsState()
    guard let rendered = context.makeImage(),
          let data = NSBitmapImageRep(cgImage: rendered).representation(using: .png, properties: [:]) else {
        fatalError("Could not encode the icon")
    }
    return data
}

struct Catalog: Decodable {
    struct Entry: Decodable { var filename: String; var size: String; var scale: String }
    var images: [Entry]
}
let entries = try JSONDecoder().decode(Catalog.self, from: Data(contentsOf: catalog.appendingPathComponent("Contents.json")))
let appSVG = artwork(rounded: false)
let faviconSVG = artwork(rounded: true)
try appSVG.write(to: root.appendingPathComponent("assets/brand/AppIcon.svg"), atomically: true, encoding: .utf8)
try faviconSVG.write(to: root.appendingPathComponent("favicon.svg"), atomically: true, encoding: .utf8)
let resources = root.appendingPathComponent("WatchApp/Resources")
try FileManager.default.createDirectory(at: resources, withIntermediateDirectories: true)
try Data(contentsOf: root.appendingPathComponent("assets/brand/PHOSPHOR-LICENSE.txt"))
    .write(to: resources.appendingPathComponent("Phosphor-LICENSE.txt"))

for entry in entries.images {
    guard let size = Double(entry.size.split(separator: "x")[0]),
          let scale = Double(entry.scale.dropLast()) else { fatalError("Invalid icon size in asset catalog") }
    let pixels = Int((size * scale).rounded())
    try png(svg: appSVG, pixels: pixels, opaque: true).write(to: catalog.appendingPathComponent(entry.filename))
}

// PNG favicon for tools that don't support SVG, and a multi-resolution ICO.
try png(svg: faviconSVG, pixels: 256, opaque: false).write(to: root.appendingPathComponent("assets/brand/favicon.png"))
let sizes = [16, 32, 48, 64, 128, 256]
let frames = try sizes.map { try png(svg: faviconSVG, pixels: $0, opaque: false) }
var ico = Data()
func appendLE<T: FixedWidthInteger>(_ value: T, to data: inout Data) {
    var littleEndian = value.littleEndian
    withUnsafeBytes(of: &littleEndian) { data.append(contentsOf: $0) }
}
appendLE(UInt16(0), to: &ico)
appendLE(UInt16(1), to: &ico)
appendLE(UInt16(frames.count), to: &ico)
var offset = 6 + frames.count * 16
for (pixels, frame) in zip(sizes, frames) {
    ico.append(contentsOf: [pixels == 256 ? 0 : UInt8(pixels), pixels == 256 ? 0 : UInt8(pixels), 0, 0])
    appendLE(UInt16(1), to: &ico)
    appendLE(UInt16(32), to: &ico)
    appendLE(UInt32(frame.count), to: &ico)
    appendLE(UInt32(offset), to: &ico)
    offset += frame.count
}
for frame in frames { ico.append(frame) }
try ico.write(to: root.appendingPathComponent("assets/brand/favicon.ico"))
print("Generated \(entries.images.count) Watch icons plus SVG, PNG, and ICO project favicons.")
