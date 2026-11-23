# Sky — macOS 原生 4K 实时天空壁纸

用原生 **Swift + Metal** 编写的轻量级 macOS 菜单栏动态天空应用（支持 macOS 14+，横屏 4K / Built-in Retina / 竖屏 4K 多显示器原生物理像素渲染）。

## 功能特点

- **真实天文计算**：基于 NOAA/Meeus 算法，按当前日期、季节、经纬度实时计算太阳高度角、方位角、日出日落时间、昼长、月相与恒星时。
- **Metal 原生 4K 感知调色渲染**：7 段 5 阶通透大气色板平滑过渡、精致柔光太阳光核、三角抖动（Dithering）彻底消除色带，显式锁定各屏 `backingScaleFactor` 物理像素输出。
- **三套天空风格**：
  - **纯净**（默认）：零云雾干扰，清澈钴蓝白昼、紫罗兰晨昏与通透深海蓝星空；
  - **卷云**：日间与晨昏叠加 6 阶高空细丝卷云，夜晚清透；
  - **深空**：增强真实银道面星簇与微弱银河尘埃带。
- **真实天文星空 & 可选月相**：内置 130+ 颗真实亮星（含猎户、北斗、仙后、天鹅、天琴等星座真星色温）+ 2450 颗天球/银道面微星，随地球自转实时转动；支持按需开启 3D 月相渲染。
- **菜单栏交互时间轴**：图标随昼夜阶段变化，支持 60fps 拖动太阳弧线预览全天 24 小时、一键 **「演示全天」** 循环演播、6 时段快捷切换（黎明/日出/正午/日落/暮色/星夜）与「回到当前实时时间」。
- **零素材程序化微风声**：基于 `AVAudioEngine` 实时合成随昼夜音色变化的柔和微风声，安装包仅 ~683 KB。
- **低功耗与无侵入设计**：休眠自动暂停渲染；不修改系统原有壁纸与锁屏，暂停或退出立即恢复原壁纸。

## 构建、测试与安装

```bash
# 运行天文与星空单元测试
swift test

# 构建 .app 包到 dist/Sky.app
bash scripts/build-app.sh

# 构建并安装到 /Applications/Sky.app
bash scripts/build-app.sh --install

# 启动应用
open /Applications/Sky.app
```

## 离线 4K 场景画廊生成

```bash
/Applications/Sky.app/Contents/MacOS/SkyWallpaper --render-preview ./previews
open ./previews/gallery.html
```
