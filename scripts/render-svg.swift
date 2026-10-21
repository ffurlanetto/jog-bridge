// render-svg.swift — render an SVG to a PNG of an exact pixel size (macOS, AppKit).
//
// Usage: swift scripts/render-svg.swift <in.svg> <out.png> <width> <height>
//
// Used for the social preview image and the app icon (see docs/branding.md). `qlmanage -t`
// is not suitable: it produces cropped square thumbnails.
import AppKit

let args = CommandLine.arguments
guard args.count == 5, let width = Int(args[3]), let height = Int(args[4]),
      let image = NSImage(contentsOf: URL(fileURLWithPath: args[1])) else {
    fputs("usage: render-svg.swift <in.svg> <out.png> <width> <height>\n", stderr)
    exit(1)
}

guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8,
    samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
    bytesPerRow: 0, bitsPerPixel: 0
) else { exit(1) }
rep.size = NSSize(width: width, height: height)

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
image.draw(in: NSRect(x: 0, y: 0, width: width, height: height))
NSGraphicsContext.restoreGraphicsState()

guard let png = rep.representation(using: .png, properties: [:]) else { exit(1) }
try png.write(to: URL(fileURLWithPath: args[2]))
