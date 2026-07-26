import AppKit
import Foundation

guard CommandLine.arguments.count == 3 else {
  fputs("Usage: generate-icon.swift <internet-angel.png> <output.png>\n", stderr)
  exit(2)
}

let sourcePath = CommandLine.arguments[1]
let outputPath = CommandLine.arguments[2]
guard let source = NSImage(contentsOfFile: sourcePath), source.isValid else {
  fputs("Could not load the Internet Angel icon source.\n", stderr)
  exit(1)
}

let pixels = 1024
guard let bitmap = NSBitmapImageRep(
  bitmapDataPlanes: nil,
  pixelsWide: pixels,
  pixelsHigh: pixels,
  bitsPerSample: 8,
  samplesPerPixel: 4,
  hasAlpha: true,
  isPlanar: false,
  colorSpaceName: .deviceRGB,
  bytesPerRow: 0,
  bitsPerPixel: 0
) else {
  fputs("Could not create icon bitmap.\n", stderr)
  exit(1)
}
bitmap.size = NSSize(width: pixels, height: pixels)
NSGraphicsContext.saveGraphicsState()
guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
  fputs("Could not create icon graphics context.\n", stderr)
  exit(1)
}
NSGraphicsContext.current = context

NSColor.clear.setFill()
NSRect(x: 0, y: 0, width: pixels, height: pixels).fill()
context.imageInterpolation = .none
source.draw(
  in: NSRect(x: 0, y: 0, width: pixels, height: pixels),
  from: NSRect(origin: .zero, size: source.size),
  operation: .sourceOver,
  fraction: 1
)

context.flushGraphics()
NSGraphicsContext.restoreGraphicsState()

guard let data = bitmap.representation(using: .png, properties: [:]) else {
  fputs("Could not encode icon PNG.\n", stderr)
  exit(1)
}
do {
  try data.write(to: URL(fileURLWithPath: outputPath), options: .atomic)
} catch {
  fputs("Could not write icon: \(error.localizedDescription)\n", stderr)
  exit(1)
}
