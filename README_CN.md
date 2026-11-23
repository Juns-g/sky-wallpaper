# Sky Wallpaper for macOS

[English](README.md) | **简体中文**

一个基于原生 **Swift + Metal** 编写的轻量级 macOS 菜单栏实时天空壁纸应用：按真实天文位置在桌面图标和小组件背后实时渲染昼夜光影与星座，支持多屏原生 4K / 跨屏连续天穹与锁屏同步，体积不到 1 MB。

<table>
  <tr>
    <td><img src="docs/preview-sunrise.jpg" alt="日出" /></td>
    <td><img src="docs/preview-noon.jpg" alt="正午" /></td>
  </tr>
  <tr>
    <td align="center"><sub>日出 · 皇家钴蓝与暖杏微光</sub></td>
    <td align="center"><sub>正午 · 澄澈蓝天</sub></td>
  </tr>
  <tr>
    <td><img src="docs/preview-dusk.jpg" alt="暮色" /></td>
    <td><img src="docs/preview-night.jpg" alt="星夜" /></td>
  </tr>
  <tr>
    <td align="center"><sub>暮色 · 蓝调时刻</sub></td>
    <td align="center"><sub>星夜 · 真实星座 4K 渲染</sub></td>
  </tr>
</table>

## 核心特性

- **真实天文计算**：基于 NOAA/Meeus 算法，按当前日期、季节与经纬度实时计算太阳高度角、方位角、日出日落、昼长、月相与恒星时。
- **原生 4K & 多屏连续天穹**：显式锁定每块显示器的物理像素倍率（支持 4K 横屏、Retina 内置屏、4K 竖屏），支持将多块显示器**无缝拼接成同一片连续天空**（太阳早上从左屏升起、正午经过主屏、傍晚滑到右屏落下）。
- **接近 0% 的静默功耗**：平时采用事件驱动按需单帧渲染，全屏窗口遮挡自动停绘、熄屏暂停、电池模式自动降频，几乎不占用 CPU/GPU。
- **锁屏 & Mission Control 同步**：可选自动将当前实时天色离屏渲染并同步为 macOS 系统壁纸（定时 + 锁屏瞬间触发），关闭时自动还原你原有的系统壁纸。
- **三套天空风格 + 实时天气**：
  - **纯净**（默认）：极简通透大气渐变 + 疏朗克制的真实星座；
  - **卷云**：日间与晨昏叠加 6 阶高空细丝卷云，夜晚保持清透；
  - **深空**：增强真实银道面星簇与微弱银河尘埃带；
  - **可选实时天气（Open-Meteo，免 Key）**：按本地晴/多云/阴/雨/雪柔和叠加对应云量、微雨丝或细雪氛围。
- **原生细节与联动**：菜单栏图标随昼夜阶段自带柔光着色，支持 60fps 拖动 24h 时间轴与一键「演示全天」、可选随日出日落自动切换 macOS 浅色/深色模式、内置零素材程序化微风声。

## 环境要求

- macOS 14 (Sonoma) 及以上（支持 Apple Silicon / Intel）
- 从源码编译需安装 Xcode Command Line Tools（也可直接从 [Releases](https://github.com/Juns-g/sky-wallpaper/releases) 下载 `.dmg` 安装包）

## 快速开始

```bash
git clone https://github.com/Juns-g/sky-wallpaper.git
cd sky-wallpaper

# 运行天文、多屏拼接与天气单元测试
swift test

# 编译并安装到 /Applications/Sky.app
bash scripts/build-app.sh --install

# 启动应用（仅驻留顶部菜单栏，不占 Dock）
open /Applications/Sky.app
```

### 打包 DMG 分发镜像

```bash
bash scripts/build-dmg.sh 1.1.0
```

### 离线生成 4K 场景画廊

```bash
/Applications/Sky.app/Contents/MacOS/SkyWallpaper --render-preview ./previews
open ./previews/gallery.html
```

## 目录结构

- `Sources/SkyCore/` — 纯 Swift 天文核心（`SolarAstronomy`）、真实亮星与银道面星库（`StarCatalog`）、多屏全景 UV 切分（`PanoramaLayout`）、WMO 天气映射（`WeatherModels`）与配置模型（`Models`）。
- `Sources/SkyApp/` — Metal 大气/星点/雨雪着色器（`SkyShaderSource`、`SkyRenderer`）、支持遮挡休眠与多屏拼接的桌面窗口管理（`DesktopWindowManager`）、锁屏壁纸同步（`WallpaperSyncManager`）、Open-Meteo 天气客户端（`WeatherService`）、深色模式/电量联动（`SystemIntegration`）、程序化微风引擎（`AmbientWindEngine`）与 SwiftUI 菜单栏面板（`MenuBarPopoverView`）。
- `Tests/SkyCoreTests/` — 单元测试（夏至/冬至昼长、北极星高度角、三屏全景无缝切分、WMO 天气映射）。

## 开源协议

[MIT](LICENSE)
