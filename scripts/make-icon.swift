// 绘制 Dayline 图标并生成 Resources/AppIcon.icns。
// 用法：swift scripts/make-icon.swift [输出的 1024px PNG 路径]
//
// 图形：深青到灰绿的渐变底，一条地平线，一轮从线上升起的太阳，线下几道倒影。
// 外形按 macOS 图标网格：1024 画布中 824 的圆角方形（超椭圆），留出投影空间。
import AppKit

let canvas: CGFloat = 1024
let bodySize: CGFloat = 824
let bodyOrigin = (canvas - bodySize) / 2

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

/// 接近 Apple 连续圆角的超椭圆。
func squirclePath(in rect: CGRect, exponent: CGFloat = 5) -> CGPath {
    let path = CGMutablePath()
    let steps = 720
    for step in 0...steps {
        let t = CGFloat(step) / CGFloat(steps) * 2 * .pi
        let cosT = cos(t), sinT = sin(t)
        let x = pow(abs(cosT), 2 / exponent) * (cosT < 0 ? -1 : 1)
        let y = pow(abs(sinT), 2 / exponent) * (sinT < 0 ? -1 : 1)
        let point = CGPoint(x: rect.midX + x * rect.width / 2, y: rect.midY + y * rect.height / 2)
        step == 0 ? path.move(to: point) : path.addLine(to: point)
    }
    path.closeSubpath()
    return path
}

func drawIcon(in context: CGContext) {
    let body = CGRect(x: bodyOrigin, y: bodyOrigin, width: bodySize, height: bodySize)
    let shape = squirclePath(in: body)
    let space = CGColorSpace(name: CGColorSpace.sRGB)!

    // 投影
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: color(0x000000, 0.32))
    context.addPath(shape)
    context.setFillColor(color(0x1B3438))
    context.fillPath()
    context.restoreGState()

    context.saveGState()
    context.addPath(shape)
    context.clip()

    // 背景：上深下浅
    let background = CGGradient(
        colorsSpace: space,
        colors: [color(0x14282F), color(0x2C5552), color(0x6E9A88)] as CFArray,
        locations: [0, 0.55, 1]
    )!
    context.drawLinearGradient(
        background,
        start: CGPoint(x: body.midX, y: body.maxY),
        end: CGPoint(x: body.midX, y: body.minY),
        options: []
    )

    let horizonY = body.minY + bodySize * 0.42
    let sunCenter = CGPoint(x: body.midX, y: horizonY)
    let sunRadius = bodySize * 0.2

    // 太阳的光晕，线下也有一点，像照在水面上
    let glow = CGGradient(
        colorsSpace: space,
        colors: [color(0xFFD9A0, 0.34), color(0xFFD9A0, 0.30), color(0xFFD9A0, 0)] as CFArray,
        locations: [0, 0.4, 1]
    )!
    context.drawRadialGradient(
        glow,
        startCenter: sunCenter, startRadius: 0,
        endCenter: sunCenter, endRadius: sunRadius * 2.3,
        options: []
    )

    // 太阳：线以上的半圆
    context.saveGState()
    context.clip(to: CGRect(x: body.minX, y: horizonY, width: bodySize, height: bodySize))
    context.addArc(center: sunCenter, radius: sunRadius, startAngle: 0, endAngle: .pi, clockwise: false)
    context.closePath()
    context.clip()
    let sun = CGGradient(
        colorsSpace: space,
        colors: [color(0xFFF1CF), color(0xF7B56E)] as CFArray,
        locations: [0, 1]
    )!
    context.drawLinearGradient(
        sun,
        start: CGPoint(x: sunCenter.x, y: sunCenter.y + sunRadius),
        end: sunCenter,
        options: []
    )
    context.restoreGState()

    // 地平线
    let lineWidth = bodySize * 0.018
    context.setLineCap(.round)
    context.setLineWidth(lineWidth)
    context.setStrokeColor(color(0xF5EBDD, 0.95))
    context.move(to: CGPoint(x: body.minX + bodySize * 0.16, y: horizonY))
    context.addLine(to: CGPoint(x: body.maxX - bodySize * 0.16, y: horizonY))
    context.strokePath()

    // 倒影：越往下越短越淡
    let reflections: [(width: CGFloat, alpha: CGFloat)] = [(0.30, 0.55), (0.20, 0.38), (0.11, 0.24)]
    for (index, reflection) in reflections.enumerated() {
        let y = horizonY - bodySize * (0.075 + 0.06 * CGFloat(index))
        let half = bodySize * reflection.width / 2
        context.setLineWidth(lineWidth * 0.8)
        context.setStrokeColor(color(0xFFD9A0, reflection.alpha))
        context.move(to: CGPoint(x: body.midX - half, y: y))
        context.addLine(to: CGPoint(x: body.midX + half, y: y))
        context.strokePath()
    }

    // 顶部一道极淡的高光，让表面有点质感
    let sheen = CGGradient(
        colorsSpace: space,
        colors: [color(0xFFFFFF, 0.10), color(0xFFFFFF, 0)] as CFArray,
        locations: [0, 1]
    )!
    context.drawLinearGradient(
        sheen,
        start: CGPoint(x: body.midX, y: body.maxY),
        end: CGPoint(x: body.midX, y: body.maxY - bodySize * 0.35),
        options: []
    )
    context.restoreGState()

    // 内描边
    context.addPath(shape)
    context.setLineWidth(2)
    context.setStrokeColor(color(0xFFFFFF, 0.12))
    context.strokePath()
}

func renderPNG(size: Int) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    let graphics = NSGraphicsContext(bitmapImageRep: rep)!
    let context = graphics.cgContext
    let scale = CGFloat(size) / canvas
    context.scaleBy(x: scale, y: scale)
    drawIcon(in: context)
    graphics.flushGraphics()
    return rep.representation(using: .png, properties: [:])!
}

let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

for points in [16, 32, 128, 256, 512] {
    try renderPNG(size: points).write(to: iconset.appendingPathComponent("icon_\(points)x\(points).png"))
    try renderPNG(size: points * 2).write(to: iconset.appendingPathComponent("icon_\(points)x\(points)@2x.png"))
}
if CommandLine.arguments.count > 1 {
    try renderPNG(size: 1024).write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
}

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", root.appendingPathComponent("Resources/AppIcon.icns").path]
try iconutil.run()
iconutil.waitUntilExit()
print(iconutil.terminationStatus == 0 ? "已生成 Resources/AppIcon.icns" : "iconutil 失败")
