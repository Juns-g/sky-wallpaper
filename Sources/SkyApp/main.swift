import AppKit
import Foundation
import SkyCore

// CLI mode: --render-preview <dir> renders a full 4K scene & style showcase (PNGs + interactive gallery.html)
if let idx = CommandLine.arguments.firstIndex(of: "--render-preview"), idx + 1 < CommandLine.arguments.count {
    let outDir = URL(fileURLWithPath: CommandLine.arguments[idx + 1], isDirectory: true)
    try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

    guard let context = SkyMetalContext.shared else {
        fputs("Error: Metal context unavailable\n", stderr)
        exit(1)
    }

    let beijing = CityPreset.all[0]
    let startOfDay = SolarAstronomy.startOfLocalDay(for: Date(), timeZone: beijing.timeZone)
    let daylight = SolarAstronomy.daylightInfo(date: Date(), location: beijing)
    let sr = daylight.sunriseHour ?? 7.0
    let noon = daylight.solarNoonHour
    let ss = daylight.sunsetHour ?? 17.0

    struct CaseSpec {
        let filename: String
        let title: String
        let subtitle: String
        let hour: Double
        let style: SkyStyle
        let width: Int
        let height: Int
    }

    let cases: [CaseSpec] = [
        CaseSpec(filename: "01-dawn-pure.png", title: "黎明 · 紫罗兰晨光", subtitle: "纯净蓝紫过渡与地平线暖杏微光", hour: sr - 0.50, style: .pure, width: 2560, height: 1440),
        CaseSpec(filename: "02-sunrise-pure.png", title: "日出 · 极简微光", subtitle: "皇家钴蓝 + 小巧柔和太阳光核", hour: sr + 0.25, style: .pure, width: 2560, height: 1440),
        CaseSpec(filename: "03-noon-pure.png", title: "正午 · 澄澈钴蓝", subtitle: "通透高饱和日光蓝天", hour: noon, style: .pure, width: 2560, height: 1440),
        CaseSpec(filename: "04-noon-cirrus.png", title: "正午 · 细丝卷云", subtitle: "可选高空细丝卷云风格", hour: noon, style: .cirrus, width: 2560, height: 1440),
        CaseSpec(filename: "05-sunset-pure.png", title: "日落 · 杏桃余晖", subtitle: "干净无灰浊的钴蓝到暖金过渡", hour: ss - 0.15, style: .pure, width: 2560, height: 1440),
        CaseSpec(filename: "06-dusk-pure.png", title: "暮色 · 蓝调时刻", subtitle: "电光紫蓝与初现亮星", hour: ss + 0.48, style: .pure, width: 2560, height: 1440),
        CaseSpec(filename: "07-night-pure.png", title: "星夜 · 极简通透 4K", subtitle: "深海蓝夜空 + 疏朗真实星座（无杂乱雾感）", hour: 22.5, style: .pure, width: 3840, height: 2160),
        CaseSpec(filename: "08-night-cosmos.png", title: "星夜 · 深空银河 4K", subtitle: "增强银道面星簇与微弱尘埃带", hour: 22.5, style: .cosmos, width: 3840, height: 2160)
    ]

    var cardsHTML = ""
    for item in cases {
        let d = startOfDay.addingTimeInterval(item.hour * 3600.0)
        let snap = SolarAstronomy.snapshot(date: d, location: beijing)
        let url = outDir.appendingPathComponent(item.filename)
        try context.renderPreviewPNG(
            to: url,
            snapshot: snap,
            style: item.style,
            showStars: true,
            starIntensity: 1.0,
            width: item.width,
            height: item.height
        )
        let stars = StarCatalog.projectVisibleStars(
            snapshot: snap,
            aspectRatio: Double(item.width) / Double(item.height),
            starIntensity: 1.0,
            style: item.style
        ).count
        let timeStr = SolarAstronomy.formatHour(item.hour)
        print("Rendered \(item.filename) (\(item.width)x\(item.height)) | \(item.title) | \(timeStr) | elev=\(String(format: "%.1f", snap.solar.elevationDegrees))° | stars=\(stars)")
        cardsHTML += """
        <figure class="card \(item.height > item.width ? "portrait" : "")">
          <a href="\(item.filename)" target="_blank"><img src="\(item.filename)" alt="\(item.title)" loading="lazy"></a>
          <figcaption>
            <div class="row"><strong>\(item.title)</strong><span>\(timeStr) · \(item.width)×\(item.height) · \(stars) 星</span></div>
            <p>\(item.subtitle)</p>
          </figcaption>
        </figure>
        """
    }

    let html = """
    <!doctype html>
    <html lang="zh-CN">
    <head>
    <meta charset="utf-8">
    <title>Sky 4K 场景与风格效果预览</title>
    <style>
      :root { color-scheme: dark; }
      body { margin: 0; padding: 28px 36px 48px; background: #070b14; color: #e8eefc; font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", "PingFang SC", sans-serif; }
      header { display: flex; justify-content: space-between; align-items: baseline; margin-bottom: 22px; }
      h1 { margin: 0; font-size: 22px; font-weight: 600; }
      .meta { color: #8fa1c4; font-size: 13px; }
      .grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(460px, 1fr)); gap: 18px; }
      .card { margin: 0; background: #101726; border: 1px solid rgba(255,255,255,0.09); border-radius: 14px; overflow: hidden; }
      .card img { width: 100%; display: block; aspect-ratio: 16 / 9; object-fit: cover; cursor: zoom-in; }
      .card.portrait img { aspect-ratio: 16 / 9; object-fit: contain; background: #040710; }
      figcaption { padding: 12px 14px 14px; }
      .row { display: flex; justify-content: space-between; align-items: baseline; gap: 12px; }
      .row strong { font-size: 14px; }
      .row span { font-size: 11.5px; color: #8fa1c4; font-variant-numeric: tabular-nums; }
      figcaption p { margin: 4px 0 0; font-size: 12px; color: #a7b6d6; }
    </style>
    </head>
    <body>
      <header>
        <h1>Sky — 4K Metal 实时场景与风格画廊</h1>
        <div class="meta">点击任意预览图可新标签查看原生 4K / 2.5K 原图 · 实际桌面效果在菜单栏点「演示全天」或切换风格即时生效</div>
      </header>
      <div class="grid">\(cardsHTML)</div>
    </body>
    </html>
    """
    try html.write(to: outDir.appendingPathComponent("gallery.html"), atomically: true, encoding: .utf8)
    exit(0)
}

MainActor.assumeIsolated {
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)
    let delegate = AppDelegate()
    app.delegate = delegate
    app.run()
}
