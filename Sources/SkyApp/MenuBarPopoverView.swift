import SkyCore
import SwiftUI

struct MenuBarPopoverView: View {
    @ObservedObject var viewModel: SkyViewModel
    let onQuit: () -> Void

    @State private var showMoreSettings = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerSection
            solarTimelineCard
            scenePresetsSection
            appearanceCard
            moreSettingsCard
            footerSection
        }
        .padding(14)
        .frame(width: 348)
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Image(systemName: viewModel.snapshot.phase.symbolName)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(phaseAccentColor)
                        .font(.system(size: 16, weight: .semibold))
                    Text(viewModel.snapshot.phase.chineseTitle)
                        .font(.system(size: 17, weight: .semibold))
                        .lineLimit(1)
                    if let weather = viewModel.activeWeather {
                        Label(weather.shortBadge, systemImage: weather.condition.symbolName)
                            .font(.system(size: 10.5, weight: .medium))
                            .lineLimit(1)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.primary.opacity(0.08), in: Capsule())
                    }
                    if viewModel.isDemoPlaying {
                        Text("演示中")
                            .font(.system(size: 10, weight: .medium))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.22), in: Capsule())
                            .foregroundStyle(.orange)
                    } else if viewModel.isPreviewing {
                        Text("预览")
                            .font(.system(size: 10, weight: .medium))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.18), in: Capsule())
                            .foregroundStyle(Color.accentColor)
                    }
                }
                Text("\(viewModel.settings.location.name) · \(viewModel.settings.location.formattedCoordinates)")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                Text(viewModel.displayedTimeString)
                    .font(.system(size: 20, weight: .medium, design: .rounded))
                    .monospacedDigit()
                Text(String(format: "太阳高度 %.0f°", viewModel.snapshot.solar.elevationDegrees))
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
    }

    // MARK: - Interactive Solar Arc Timeline

    private var solarTimelineCard: some View {
        VStack(spacing: 6) {
            ZStack(alignment: .topTrailing) {
                SolarArcTimeline(
                    samples: viewModel.timelineSamples,
                    currentHour: viewModel.displayedHour,
                    onScrub: { hour in
                        viewModel.scrubTo(hour: hour, activeDrag: true)
                    },
                    onEnd: {
                        viewModel.finishScrubbing()
                    }
                )
                .frame(height: 74)
                .padding(.horizontal, 8)
                .padding(.vertical, 7)

                Button {
                    viewModel.toggleDemoTour()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: viewModel.isDemoPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 9))
                        Text(viewModel.isDemoPlaying ? "停止" : "演示全天")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial, in: Capsule())
                    .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .padding(7)
            }
            .background(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: timelineBackdropColors,
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.14), lineWidth: 0.75)
                    )
            )

            HStack {
                Label("日出 \(viewModel.sunriseString)", systemImage: "sunrise")
                Spacer()
                Text("昼长 \(viewModel.daylightDurationString)")
                Spacer()
                Label("日落 \(viewModel.sunsetString)", systemImage: "sunset")
            }
            .font(.system(size: 10.5))
            .foregroundStyle(.secondary)
            .monospacedDigit()
        }
    }

    // MARK: - 6 Scene Quick Preview Chips

    private var scenePresetsSection: some View {
        let sunrise = viewModel.snapshot.daylight.sunriseHour ?? 6.8
        let noon = viewModel.snapshot.daylight.solarNoonHour
        let sunset = viewModel.snapshot.daylight.sunsetHour ?? 17.2

        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                quickButton("黎明", hour: sunrise - 0.50)
                quickButton("日出", hour: sunrise + 0.20)
                quickButton("正午", hour: noon)
                quickButton("日落", hour: sunset - 0.15)
                quickButton("暮色", hour: sunset + 0.48)
                quickButton("星夜", hour: 22.5)
            }

            if viewModel.isPreviewing {
                Button {
                    viewModel.returnToNow()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 11))
                        Text("回到当前实时时间")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 5)
                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func quickButton(_ title: String, hour: Double) -> some View {
        Button {
            viewModel.jumpToPresetHour(hour)
        } label: {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 5)
                .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Primary Appearance & Display Card

    private var appearanceCard: some View {
        SectionCard {
            VStack(alignment: .leading, spacing: 10) {
                // Style picker row
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Image(systemName: "paintpalette")
                            .font(.system(size: 12.5))
                            .foregroundStyle(.secondary)
                            .frame(width: 18, alignment: .center)
                        Text("天空风格")
                            .font(.system(size: 12.5, weight: .medium))
                        Spacer(minLength: 8)
                        Picker("", selection: Binding(
                            get: { viewModel.settings.style },
                            set: { viewModel.setStyle($0) }
                        )) {
                            ForEach(SkyStyle.allCases) { s in
                                Text(s.chineseTitle).tag(s)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .frame(width: 162)
                        .controlSize(.small)
                    }
                    Text(viewModel.settings.style.description)
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                        .padding(.leading, 26)
                }

                Divider().opacity(0.35)

                SettingToggleRow(
                    icon: "sparkles.rectangle.stack",
                    title: "实时天空桌面",
                    subtitle: nil,
                    isOn: Binding(
                        get: { viewModel.settings.isWallpaperActive },
                        set: { viewModel.setWallpaperActive($0) }
                    )
                )

                if viewModel.displays.count > 1 {
                    SettingToggleRow(
                        icon: "display.2",
                        title: "多屏连续天穹（\(viewModel.enabledDisplayCount) 屏）",
                        subtitle: "把多块屏幕拼成同一片连续天空",
                        isOn: Binding(
                            get: { viewModel.settings.spanAcrossDisplays },
                            set: { viewModel.setSpanAcrossDisplays($0) }
                        )
                    )
                    .disabled(viewModel.enabledDisplayCount < 2)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("显示器")
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundStyle(.secondary)
                            .padding(.leading, 26)
                        ForEach(viewModel.displays) { display in
                            SettingToggleRow(
                                icon: "display",
                                title: "\(display.name)（\(display.width)×\(display.height)）",
                                subtitle: nil,
                                isOn: Binding(
                                    get: { viewModel.isDisplayEnabled(display.id) },
                                    set: { viewModel.setDisplayEnabled(uuid: display.id, enabled: $0) }
                                )
                            )
                        }
                    }
                }

                SettingToggleRow(
                    icon: "cloud.sun.rain",
                    title: "实时天气氛围",
                    subtitle: "按当地晴/云/雨/雪柔和叠加天气层次",
                    isOn: Binding(
                        get: { viewModel.settings.liveWeatherEnabled },
                        set: { viewModel.setLiveWeatherEnabled($0) }
                    )
                )

                Divider().opacity(0.35)

                // Equal-width 3-column element chips (zero wrapping, crisp alignment)
                HStack(spacing: 6) {
                    FeatureChipButton(
                        icon: "sparkles",
                        title: "星空",
                        isOn: viewModel.settings.showStars
                    ) {
                        viewModel.setShowStars(!viewModel.settings.showStars)
                    }
                    .help("夜晚显示基于真实星表的星座与星点")

                    FeatureChipButton(
                        icon: "moon.circle",
                        title: "月相",
                        isOn: viewModel.settings.showMoon
                    ) {
                        viewModel.setShowMoon(!viewModel.settings.showMoon)
                    }
                    .help("按真实盈亏与方位渲染月亮")

                    FeatureChipButton(
                        icon: "wind.snow",
                        title: "微动效",
                        isOn: viewModel.settings.ambientMotion
                    ) {
                        viewModel.setAmbientMotion(!viewModel.settings.ambientMotion)
                    }
                    .help("插电时让卷云与星点缓慢流动；关闭可保持极低功耗")
                }

                if viewModel.settings.showStars {
                    HStack(spacing: 8) {
                        Image(systemName: "star.leadinghalf.filled")
                            .font(.system(size: 11.5))
                            .foregroundStyle(.secondary)
                            .frame(width: 18, alignment: .center)
                        Text("星点亮度")
                            .font(.system(size: 11.5))
                            .foregroundStyle(.secondary)
                            .fixedSize()
                        Slider(
                            value: Binding(
                                get: { viewModel.settings.starIntensity },
                                set: { viewModel.setStarIntensity($0) }
                            ),
                            in: 0.4...1.5
                        )
                        .controlSize(.small)
                        Text("\(Int((viewModel.settings.starIntensity * 100).rounded()))%")
                            .font(.system(size: 10.5))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                            .frame(width: 34, alignment: .trailing)
                    }
                    .padding(.top, 2)
                }
            }
        }
    }

    // MARK: - Collapsible More Settings Card

    private var moreSettingsSummary: String {
        var tags: [String] = [viewModel.settings.location.name]
        if viewModel.settings.syncSystemWallpaper {
            tags.append("锁屏同步")
        }
        if viewModel.settings.syncSystemAppearance {
            tags.append("深浅联动")
        }
        if viewModel.settings.ambientWindEnabled {
            tags.append("微风声")
        }
        return tags.joined(separator: " · ")
    }

    private var moreSettingsCard: some View {
        SectionCard {
            VStack(alignment: .leading, spacing: 10) {
                Button {
                    withAnimation(.easeInOut(duration: 0.16)) {
                        showMoreSettings.toggle()
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .frame(width: 18, alignment: .center)
                        Text("更多设置")
                            .font(.system(size: 12.5, weight: .medium))
                        Spacer(minLength: 6)
                        if !showMoreSettings {
                            Text(moreSettingsSummary)
                                .font(.system(size: 10.5))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                        Image(systemName: showMoreSettings ? "chevron.up" : "chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if showMoreSettings {
                    Divider().opacity(0.35)

                    // Lock screen sync
                    VStack(alignment: .leading, spacing: 6) {
                        SettingToggleRow(
                            icon: "lock.display",
                            title: "同步锁屏与系统壁纸",
                            subtitle: "定时同步天色，锁屏与调度中心保持一致",
                            isOn: Binding(
                                get: { viewModel.settings.syncSystemWallpaper },
                                set: { viewModel.setSyncSystemWallpaper($0) }
                            )
                        )
                        if viewModel.settings.syncSystemWallpaper {
                            HStack {
                                Spacer()
                                Button {
                                    viewModel.syncLockScreenWallpaperNow(showToast: true)
                                } label: {
                                    Label("立即同步当前天色", systemImage: "arrow.triangle.2.circlepath")
                                        .font(.system(size: 11, weight: .medium))
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                    }

                    // System Light/Dark appearance sync
                    SettingToggleRow(
                        icon: "circle.lefthalf.filled",
                        title: "随日出日落切浅色/深色",
                        subtitle: "日落自动切深色模式，日出切回浅色",
                        isOn: Binding(
                            get: { viewModel.settings.syncSystemAppearance },
                            set: { viewModel.setSyncSystemAppearance($0) }
                        )
                    )

                    // Ambient wind
                    VStack(alignment: .leading, spacing: 6) {
                        SettingToggleRow(
                            icon: "wind",
                            title: "环境微风声",
                            subtitle: "随昼夜轻柔变化的低频风声白噪音",
                            isOn: Binding(
                                get: { viewModel.settings.ambientWindEnabled },
                                set: { viewModel.setAmbientWindEnabled($0) }
                            )
                        )
                        if viewModel.settings.ambientWindEnabled {
                            HStack(spacing: 8) {
                                Image(systemName: "speaker.wave.1")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 18, alignment: .center)
                                Slider(
                                    value: Binding(
                                        get: { viewModel.settings.ambientWindVolume },
                                        set: { viewModel.setAmbientWindVolume($0) }
                                    ),
                                    in: 0.05...1.0
                                )
                                .controlSize(.small)
                                Image(systemName: "speaker.wave.3")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    Divider().opacity(0.35)

                    // Location picker row
                    HStack(spacing: 8) {
                        Image(systemName: "location")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .frame(width: 18, alignment: .center)
                        Text("天文位置")
                            .font(.system(size: 12.5))
                        Spacer(minLength: 8)
                        Menu {
                            ForEach(CityPreset.all, id: \.self) { city in
                                Button {
                                    viewModel.selectCity(city)
                                } label: {
                                    HStack {
                                        Text(city.name)
                                        if city.name == viewModel.settings.location.name {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                            Divider()
                            Button("使用系统自动定位") {
                                viewModel.requestAutoLocation()
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(viewModel.settings.location.name)
                                    .font(.system(size: 12, weight: .medium))
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 9))
                            }
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                        }
                        .menuStyle(.borderlessButton)
                        .fixedSize()
                    }

                    // Launch at login row
                    SettingToggleRow(
                        icon: "power",
                        title: "开机自动启动",
                        subtitle: nil,
                        isOn: Binding(
                            get: { viewModel.launchAtLogin },
                            set: { viewModel.setLaunchAtLogin($0) }
                        )
                    )
                }

                if let notice = viewModel.statusNotice {
                    Text(notice)
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    // MARK: - Footer

    private var footerSection: some View {
        HStack(spacing: 8) {
            Text(viewModel.resolutionSummary)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 8)
            Button("退出 Sky") {
                onQuit()
            }
            .buttonStyle(.plain)
            .font(.system(size: 11.5, weight: .medium))
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 2)
    }

    // MARK: - Colors

    private var phaseAccentColor: Color {
        switch viewModel.snapshot.phase {
        case .dawn: return Color(red: 0.90, green: 0.62, blue: 0.54)
        case .sunrise: return Color(red: 0.98, green: 0.66, blue: 0.34)
        case .day: return Color(red: 0.25, green: 0.64, blue: 0.98)
        case .sunset: return Color(red: 0.96, green: 0.52, blue: 0.38)
        case .dusk: return Color(red: 0.62, green: 0.56, blue: 0.92)
        case .night: return Color(red: 0.56, green: 0.72, blue: 0.98)
        }
    }

    private var timelineBackdropColors: [Color] {
        switch viewModel.snapshot.phase {
        case .dawn, .dusk:
            return [Color(red: 0.14, green: 0.20, blue: 0.48), Color(red: 0.45, green: 0.35, blue: 0.54)]
        case .sunrise, .sunset:
            return [Color(red: 0.16, green: 0.30, blue: 0.68), Color(red: 0.76, green: 0.54, blue: 0.46)]
        case .day:
            return [Color(red: 0.14, green: 0.39, blue: 0.90), Color(red: 0.42, green: 0.67, blue: 0.98)]
        case .night:
            return [Color(red: 0.03, green: 0.06, blue: 0.16), Color(red: 0.13, green: 0.20, blue: 0.42)]
        }
    }
}

// MARK: - Reusable Layout Components

private struct SectionCard<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 11)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.primary.opacity(0.055))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.07), lineWidth: 0.5)
                    )
            )
    }
}

private struct SettingToggleRow: View {
    let icon: String
    let title: String
    let subtitle: String?
    @Binding var isOn: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12.5))
                .foregroundStyle(.secondary)
                .frame(width: 18, alignment: .center)

            VStack(alignment: .leading, spacing: 1.5) {
                Text(title)
                    .font(.system(size: 12.5))
                    .lineLimit(1)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct FeatureChipButton: View {
    let icon: String
    let title: String
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11.5, weight: .medium))
                Text(title)
                    .font(.system(size: 11.5, weight: .medium))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(isOn ? Color.accentColor.opacity(0.22) : Color.primary.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .strokeBorder(isOn ? Color.accentColor.opacity(0.65) : Color.primary.opacity(0.08), lineWidth: 0.75)
                    )
            )
            .foregroundStyle(isOn ? Color.accentColor : Color.primary.opacity(0.85))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Solar Arc Timeline

private struct SolarArcTimeline: View {
    let samples: [TimelineSample]
    let currentHour: Double
    let onScrub: (Double) -> Void
    let onEnd: () -> Void

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let minElev = min(-25.0, samples.map(\.elevationDegrees).min() ?? -45.0)
            let maxElev = max(25.0, samples.map(\.elevationDegrees).max() ?? 65.0)
            let elevSpan = max(40.0, maxElev - minElev)

            let mapY: (Double) -> CGFloat = { elev in
                let norm = (elev - minElev) / elevSpan
                return h - 10 - CGFloat(norm) * (h - 20)
            }
            let horizonY = mapY(0.0)

            Canvas { ctx, size in
                var horizonPath = Path()
                horizonPath.move(to: CGPoint(x: 0, y: horizonY))
                horizonPath.addLine(to: CGPoint(x: size.width, y: horizonY))
                ctx.stroke(
                    horizonPath,
                    with: .color(Color.white.opacity(0.28)),
                    style: StrokeStyle(lineWidth: 0.8, dash: [3, 3])
                )

                guard samples.count >= 2 else { return }
                var curve = Path()
                for (idx, s) in samples.enumerated() {
                    let x = CGFloat(s.hour / 24.0) * size.width
                    let y = mapY(s.elevationDegrees)
                    if idx == 0 {
                        curve.move(to: CGPoint(x: x, y: y))
                    } else {
                        curve.addLine(to: CGPoint(x: x, y: y))
                    }
                }

                var fillPath = curve
                fillPath.addLine(to: CGPoint(x: size.width, y: horizonY))
                fillPath.addLine(to: CGPoint(x: 0, y: horizonY))
                fillPath.closeSubpath()
                ctx.fill(fillPath, with: .color(Color.white.opacity(0.10)))

                ctx.stroke(
                    curve,
                    with: .linearGradient(
                        Gradient(colors: [
                            Color(red: 0.45, green: 0.62, blue: 0.95).opacity(0.75),
                            Color(red: 1.00, green: 0.78, blue: 0.45),
                            Color(red: 1.00, green: 0.92, blue: 0.72),
                            Color(red: 0.98, green: 0.62, blue: 0.42),
                            Color(red: 0.45, green: 0.62, blue: 0.95).opacity(0.75)
                        ]),
                        startPoint: .zero,
                        endPoint: CGPoint(x: size.width, y: 0)
                    ),
                    style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round)
                )

                let clampedHour = max(0.0, min(24.0, currentHour))
                let handleX = CGFloat(clampedHour / 24.0) * size.width
                let handleElev = interpolatedElevation(at: clampedHour)
                let handleY = mapY(handleElev)
                let isAboveHorizon = handleElev >= -1.0

                let glowRect = CGRect(x: handleX - 11, y: handleY - 11, width: 22, height: 22)
                ctx.fill(
                    Path(ellipseIn: glowRect),
                    with: .color(isAboveHorizon ? Color(red: 1.0, green: 0.84, blue: 0.45).opacity(0.38) : Color(red: 0.60, green: 0.78, blue: 1.0).opacity(0.32))
                )

                let coreRect = CGRect(x: handleX - 5.5, y: handleY - 5.5, width: 11, height: 11)
                ctx.fill(
                    Path(ellipseIn: coreRect),
                    with: .color(isAboveHorizon ? Color(red: 1.0, green: 0.94, blue: 0.76) : Color(red: 0.82, green: 0.90, blue: 1.0))
                )
                ctx.stroke(
                    Path(ellipseIn: coreRect),
                    with: .color(Color.white.opacity(0.85)),
                    lineWidth: 1.0
                )
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let ratio = max(0.0, min(1.0, value.location.x / max(1.0, w)))
                        onScrub(Double(ratio) * 24.0)
                    }
                    .onEnded { _ in
                        onEnd()
                    }
            )
        }
    }

    private func interpolatedElevation(at hour: Double) -> Double {
        guard samples.count >= 2 else { return 0.0 }
        let step = 24.0 / Double(samples.count - 1)
        let idx = max(0, min(samples.count - 2, Int(hour / step)))
        let frac = (hour - Double(idx) * step) / step
        return samples[idx].elevationDegrees + (samples[idx + 1].elevationDegrees - samples[idx].elevationDegrees) * frac
    }
}
