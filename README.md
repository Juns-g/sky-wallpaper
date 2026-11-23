# Sky Wallpaper for macOS

**English** | [简体中文](README_CN.md)

A lightweight, native **Swift + Metal** live sky wallpaper for macOS that renders the real-time rhythm of daylight, twilight, and authentic constellations directly behind your desktop icons and widgets — at native 4K / Retina resolution, in under 1 MB.

<table>
  <tr>
    <td><img src="docs/preview-sunrise.jpg" alt="Sunrise" /></td>
    <td><img src="docs/preview-noon.jpg" alt="Noon" /></td>
  </tr>
  <tr>
    <td align="center"><sub>Sunrise · Royal Cobalt & Apricot</sub></td>
    <td align="center"><sub>Midday · Clear Sky</sub></td>
  </tr>
  <tr>
    <td><img src="docs/preview-dusk.jpg" alt="Dusk" /></td>
    <td><img src="docs/preview-night.jpg" alt="Starry Night" /></td>
  </tr>
  <tr>
    <td align="center"><sub>Dusk · Blue Hour Twilight</sub></td>
    <td align="center"><sub>Night · Real Constellations (4K)</sub></td>
  </tr>
</table>

## Features

- **Real Astronomical Calculations**: Uses NOAA/Meeus solar & sidereal formulas to compute exact solar altitude, azimuth, sunrise/sunset, daylight duration, lunar phase, and star positions for your location and season.
- **Native 4K & Multi-Display Panorama**: Explicitly locks per-screen `backingScaleFactor` (`3840×2160`, Retina XDR, portrait 4K, etc.) and supports **spanning one continuous sky dome seamlessly across all connected monitors** (the Sun rises on your left display, arcs across center, and sets on the right!).
- **Near-0% Idle Power Footprint**: On-demand single-frame rendering during steady state, automatic pause when displays sleep or are occluded by full-screen windows, and automatic battery-power protection.
- **Lock Screen & Mission Control Sync**: Optional automatic sync renders the live sky to your macOS system wallpaper periodically and right on screen lock (with automatic backup & one-click restore of your original wallpaper).
- **3 Visual Styles + Live Weather**:
  - **Pure** *(default)*: Minimalist, crystal-clear atmospheric sky and curated constellations.
  - **Cirrus**: Subtle 6-octave wispy high-altitude clouds during daytime and golden hour.
  - **Deep Cosmos**: Enhanced galactic-plane Milky Way star clusters and subtle dust lanes.
  - **Optional Live Weather (Open-Meteo, zero API key)**: Softly reflects local clear, cloudy, rain, or snow conditions.
- **macOS Native Touches**: Phase-tinted menu bar icon, 60fps interactive 24h solar timeline + one-click Full-Day Demo, optional automatic Light/Dark mode switch at sunrise/sunset, and zero-asset procedural ambient wind via `AVAudioEngine`.

## Requirements

- macOS 14 (Sonoma) or later (Apple Silicon / Intel)
- Xcode Command Line Tools (`swift`) to build from source (or download the `.dmg` from [Releases](https://github.com/Juns-g/sky-wallpaper/releases))

## Quick Start

```bash
git clone https://github.com/Juns-g/sky-wallpaper.git
cd sky-wallpaper

# Run astronomy, panorama & weather unit tests
swift test

# Build and install to /Applications/Sky.app
bash scripts/build-app.sh --install

# Launch (lives in the menu bar, no Dock icon)
open /Applications/Sky.app
```

### Package a Distributable DMG

```bash
bash scripts/build-dmg.sh 1.1.0
```

### Generate an Offline 4K Preview Gallery

```bash
/Applications/Sky.app/Contents/MacOS/SkyWallpaper --render-preview ./previews
open ./previews/gallery.html
```

## Architecture

- `Sources/SkyCore/` — Pure Swift astronomy engine (`SolarAstronomy`), curated J2000 bright star + Milky Way catalog (`StarCatalog`), multi-display panorama UV slicing (`PanoramaLayout`), WMO weather mapping (`WeatherModels`), and settings (`Models`).
- `Sources/SkyApp/` — Metal fragment/instanced-star/precipitation shaders (`SkyShaderSource`, `SkyRenderer`), occlusion- & battery-aware multi-monitor window manager (`DesktopWindowManager`), lock-screen wallpaper sync (`WallpaperSyncManager`), Open-Meteo client (`WeatherService`), appearance sync (`SystemIntegration`), procedural wind (`AmbientWindEngine`), and SwiftUI menu bar popover (`MenuBarPopoverView`).
- `Tests/SkyCoreTests/` — Unit tests covering seasonal daylight shifts, Polaris altitude, panoramic 3-display UV partitioning, and WMO weather mapping.

## License

[MIT](LICENSE)
