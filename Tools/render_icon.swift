import AppKit
import CoreText

let arguments = CommandLine.arguments
let fontURL = URL(fileURLWithPath: arguments[1])
let output = URL(fileURLWithPath: arguments[2])
CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, nil)

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

func scoreFont(_ size: CGFloat, weight: CGFloat) -> CTFont {
    let base = CTFontDescriptorCreateWithAttributes([kCTFontFamilyNameAttribute: "Score"] as CFDictionary)
    let varied = CTFontDescriptorCreateCopyWithAttributes(base, [kCTFontVariationAttribute: [0x7767_6874: weight, 0x7764_7468: 82]] as CFDictionary)
    return CTFontCreateWithFontDescriptor(varied, size, nil)
}

let size = 1024
let space = CGColorSpace(name: CGColorSpace.sRGB)!
let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0, space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!

let body = CGRect(x: 100, y: 100, width: 824, height: 824)
let shape = CGPath(roundedRect: body, cornerWidth: 186, cornerHeight: 186, transform: nil)

context.saveGState()
context.setShadow(offset: CGSize(width: 0, height: -10), blur: 28, color: color(0x000000, 0.45))
context.addPath(shape)
context.setFillColor(color(0x151516))
context.fillPath()
context.restoreGState()

context.saveGState()
context.addPath(shape)
context.clip()
let gradient = CGGradient(colorsSpace: space, colors: [color(0x1A1A1C), color(0x050506)] as CFArray, locations: [0, 1])!
context.drawLinearGradient(gradient, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])
context.restoreGState()

context.addPath(shape)
context.setStrokeColor(color(0xFFFFFF, 0.06))
context.setLineWidth(3)
context.strokePath()

let tileWidth: CGFloat = 270
let tileHeight: CGFloat = 360
let gap: CGFloat = 92
let tileY: CGFloat = 512 - tileHeight / 2
let digits = ["2", "1"]

for (index, digit) in digits.enumerated() {
    let x = index == 0 ? 512 - gap / 2 - tileWidth : 512 + gap / 2
    let tile = CGRect(x: x, y: tileY, width: tileWidth, height: tileHeight)
    let tilePath = CGPath(roundedRect: tile, cornerWidth: 34, cornerHeight: 34, transform: nil)

    let palettes: [(UInt32, UInt32)] = [(0x4FD8C4, 0x168A7B), (0xFF6B76, 0xC8283A)]
    let (top, bottom) = palettes[index]

    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -8), blur: 24, color: color(bottom, 0.45))
    context.addPath(tilePath)
    context.setFillColor(color(bottom))
    context.fillPath()
    context.restoreGState()

    context.saveGState()
    context.addPath(tilePath)
    context.clip()
    let tileGradient = CGGradient(colorsSpace: space, colors: [color(top), color(bottom)] as CFArray, locations: [0, 1])!
    context.drawLinearGradient(tileGradient, start: CGPoint(x: tile.midX, y: tile.maxY), end: CGPoint(x: tile.midX, y: tile.minY), options: [])
    context.setFillColor(color(0xFFFFFF, 0.08))
    context.fill(CGRect(x: tile.minX, y: tile.midY, width: tile.width, height: tile.height / 2))

    let font = scoreFont(300, weight: 850)
    let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color(0xFFFFFF)]
    let line = CTLineCreateWithAttributedString(NSAttributedString(string: digit, attributes: attributes))
    context.textPosition = .zero
    let bounds = CTLineGetImageBounds(line, context)
    context.textPosition = CGPoint(x: tile.midX - bounds.width / 2 - bounds.minX, y: tile.midY - bounds.height / 2 - bounds.minY)
    CTLineDraw(line, context)

    context.setFillColor(color(0x000000, 0.35))
    context.fill(CGRect(x: tile.minX, y: tile.midY - 3, width: tile.width, height: 6))
    context.restoreGState()
}

context.setFillColor(color(0xF5F5F7))
context.fillEllipse(in: CGRect(x: 512 - 20, y: 512 + 32, width: 40, height: 40))
context.fillEllipse(in: CGRect(x: 512 - 20, y: 512 - 72, width: 40, height: 40))

let image = context.makeImage()!
let destination = CGImageDestinationCreateWithURL(output as CFURL, "public.png" as CFString, 1, nil)!
CGImageDestinationAddImage(destination, image, nil)
CGImageDestinationFinalize(destination)
