import AppKit

let output = URL(fileURLWithPath: CommandLine.arguments[1])
let size = CommandLine.arguments.count > 2 ? Int(CommandLine.arguments[2])! : 1024

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

let space = CGColorSpace(name: CGColorSpace.sRGB)!
let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0, space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
context.scaleBy(x: CGFloat(size) / 1024, y: CGFloat(size) / 1024)

let body = CGRect(x: 100, y: 100, width: 824, height: 824)
let shape = CGPath(roundedRect: body, cornerWidth: 186, cornerHeight: 186, transform: nil)

context.saveGState()
context.setShadow(offset: CGSize(width: 0, height: -10), blur: 28, color: color(0x000000, 0.45))
context.addPath(shape)
context.setFillColor(color(0x0A44E8))
context.fillPath()
context.restoreGState()

context.addPath(shape)
context.setStrokeColor(color(0xFFFFFF, 0.06))
context.setLineWidth(3)
context.strokePath()

let barWidth: CGFloat = 176
let gap: CGFloat = 64
let radius: CGFloat = 44
let tall: CGFloat = 480
let short: CGFloat = 300
let left = 512 - barWidth - gap / 2
let base = 512 - tall / 2

let bars: [(CGRect, CGColor)] = [
    (CGRect(x: left, y: base, width: barWidth, height: tall), color(0xF5F5F7)),
    (CGRect(x: left + barWidth + gap, y: base, width: barWidth, height: short), color(0xF5F5F7, 0.5))
]

for (rect, fill) in bars {
    context.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil))
    context.setFillColor(fill)
    context.fillPath()
}

let image = context.makeImage()!
let destination = CGImageDestinationCreateWithURL(output as CFURL, "public.png" as CFString, 1, nil)!
CGImageDestinationAddImage(destination, image, nil)
CGImageDestinationFinalize(destination)
