# Sky Wallpaper for macOS

[English](README.md) | **简体中文**

一个基于原生 **Swift + Metal** 编写的轻量级 macOS 菜单栏实时天空壁纸应用：按真实天文位置在桌面图标和小组件背后实时渲染昼夜光影与星座，支持多屏原生 4K / Retina 输出，体积不到 1 MB。

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
- **原生 4K / 多屏 Metal 渲染**：显式锁定每块显示器的物理像素倍率（支持 4K 横屏、Retina 内置屏、4K 竖屏），感知空间多段平滑渐变 + 三角抖动消除色带。
- **三套天空风格**：
  - **纯净**（默认）：极简通透大气渐变 + 疏朗克制的真实星座；
  - **卷云**：日间与晨昏叠加 6 阶高空细丝卷云，夜晚保持清透；
  - **深空**：增强真实银道面星簇与微弱银河尘埃带。
- **菜单栏交互时间轴**：支持 60fps 拖动太阳弧线预览 24 小时、一键 **「演示全天」** 循环演播、6 时段快捷跳转、可选开启 3D 月相，一键回到当前实时时间。
- **零素材程序化微风声**：用 `AVAudioEngine` 实时合成随昼夜音色变化的柔和微风声，无需内嵌音频文件。
- **低功耗与无侵入**：二进制仅 ~683 KB，无账号、无埋点，熄屏自动暂停渲染；不覆盖 macOS 原有壁纸与锁屏，暂停或退出立即恢复原壁纸。

## 环境要求

- macOS 14 (Sonoma) 及以上（支持 Apple Silicon / Intel）
- 已安装 Xcode Command Line Tools（用于从源码编译）

## 快速开始

```bash
git clone https://github.com/Juns-g/sky-wallpaper.git
cd sky-wallpaper

# 运行天文与星空单元测试
swift test

# 编译并安装到 /Applications/Sky.app
bash scripts/build-app.sh --install

# 启动应用（仅驻留顶部菜单栏，不占 Dock）
open /Applications/Sky.app
```

### 离线生成 4K 场景画廊

```bash
/Applications/Sky.app/Contents/MacOS/SkyWallpaper --render-preview ./previews
open ./previews/gallery.html
```

## 目录结构

- `Sources/SkyCore/` — 纯 Swift 天文核心（`SolarAstronomy`）、真实亮星与银道面星库（`StarCatalog`）、城市预设与配置持久化（`Models`）。
- `Sources/SkyApp/` — Metal 大气与星点着色器（`SkyShaderSource`、`SkyRenderer`）、多显示器桌面底层窗口管理（`DesktopWindowManager`）、程序化风声引擎（`AmbientWindEngine`）与 SwiftUI 菜单栏控制面板（`MenuBarPopoverView`）。
- `Tests/SkyCoreTests/` — 单元测试（夏至/冬至昼长、北极星高度角校验、昼夜星点显隐）。

## 开源协议

[MIT](LICENSE)
