import AppKit
import SwiftUI

struct MonitorPanelView: View {
    @EnvironmentObject private var monitor: SystemMonitorService
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var popoverPinState: PopoverPinState

    var body: some View {
        VStack(spacing: 10) {
            header
            CPUCard(cpu: monitor.snapshot.cpu)

            HStack(spacing: 10) {
                MemoryCard(memory: monitor.snapshot.memory)
                NetworkCard(network: monitor.snapshot.network)
            }

            ThermalFanCard(thermal: monitor.snapshot.thermal, fan: monitor.snapshot.fan)
        }
        .padding(12)
        .frame(width: 370)
        .background(.regularMaterial)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text("System Pulse")
                .font(.system(size: 16, weight: .semibold))

            Spacer()

            Button {
                popoverPinState.toggle()
            } label: {
                Image(systemName: popoverPinState.isPinned ? "pin.fill" : "pin")
                    .font(.system(size: 13, weight: .semibold))
            }
            .buttonStyle(.borderless)
            .help("Pin panel")

            Button {
                SettingsWindowController.shared.show(settings: settings)
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 13, weight: .semibold))
            }
            .buttonStyle(.borderless)
            .help("Settings")

            Button {
                NSApp.terminate(nil)
            } label: {
                Image(systemName: "power")
                    .font(.system(size: 13, weight: .semibold))
            }
            .buttonStyle(.borderless)
            .help("Quit")
        }
    }
}

private struct CPUCard: View {
    @EnvironmentObject private var settings: SettingsStore
    let cpu: CPUMetric

    var body: some View {
        MetricCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    MetricTitle(icon: "cpu", title: "CPU")

                    Spacer()

                    Text(settings.percentText(cpu.usage))
                        .font(.system(size: 32, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(settings.adaptiveColor(low: settings.cpuGraphLowColor, mid: settings.cpuGraphMidColor, high: settings.cpuGraphHighColor, intensity: cpu.usage))
                }

                LineGraphView(
                    values: cpu.history,
                    colors: settings.gradientColors(low: settings.cpuGraphLowColor, mid: settings.cpuGraphMidColor, high: settings.cpuGraphHighColor, intensity: cpu.usage)
                )
                .frame(height: 86)

                HStack {
                    Text("\(cpu.coreCount) cores")
                    Spacer()
                    Text("1s refresh")
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            }
        }
    }
}

private struct MemoryCard: View {
    @EnvironmentObject private var settings: SettingsStore
    let memory: MemoryMetric

    var body: some View {
        MetricCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    MetricTitle(icon: "memorychip", title: "Memory")
                    Spacer()
                    Text(settings.percentText(memory.usage))
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                }

                LineGraphView(
                    values: memory.history,
                    colors: settings.gradientColors(low: settings.memoryGraphLowColor, mid: settings.memoryGraphMidColor, high: settings.memoryGraphHighColor, intensity: memory.usage)
                )
                .frame(height: 44)

                Text(memory.detailText)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
    }
}

private struct NetworkCard: View {
    @EnvironmentObject private var settings: SettingsStore
    let network: NetworkMetric

    var body: some View {
        MetricCard {
            VStack(alignment: .leading, spacing: 9) {
                MetricTitle(icon: "arrow.up.arrow.down", title: "Network")

                HStack(spacing: 10) {
                    NetworkCompactRate(icon: "arrow.up", value: network.uploadText, unitSpacing: settings.networkUnitSpacing)
                    NetworkCompactRate(icon: "arrow.down", value: network.downloadText, unitSpacing: settings.networkUnitSpacing)
                }

                LineGraphView(
                    values: network.downloadHistory,
                    colors: settings.gradientColors(low: settings.networkGraphLowColor, mid: settings.networkGraphMidColor, high: settings.networkGraphHighColor, intensity: network.downloadHistory.last ?? 0)
                )
                .frame(height: 30)

                VStack(alignment: .leading, spacing: 3) {
                    NetworkTotalRow(icon: "arrow.up", label: "Sent", value: network.totalUploadText)
                    NetworkTotalRow(icon: "arrow.down", label: "Received", value: network.totalDownloadText)
                    NetworkTotalRow(icon: "timer", label: "Measured", value: network.measuredDurationText)
                }
            }
        }
    }
}

private struct NetworkCompactRate: View {
    let icon: String
    let value: String
    let unitSpacing: Double

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.secondary)

            NetworkRateValueText(value: value, unitSpacing: CGFloat(unitSpacing.clamped(to: 0...8)))
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }
}

private struct NetworkTotalRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .semibold))
                .frame(width: 11)
            Text(label)
            Spacer(minLength: 6)
            Text(value)
                .monospacedDigit()
        }
        .font(.system(size: 10, weight: .medium))
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .minimumScaleFactor(0.75)
    }
}

private struct ThermalFanCard: View {
    let thermal: ThermalMetric
    let fan: FanMetric

    var body: some View {
        MetricCard {
            HStack(spacing: 14) {
                MetricValueBlock(icon: "thermometer.medium", title: "CPU Temp", value: thermal.displayText)
                Divider()
                MetricValueBlock(icon: "fan", title: "Fan", value: fan.displayText)
            }
        }
    }
}

struct SettingsWindowView: View {
    @EnvironmentObject private var settings: SettingsStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                MetricTitle(icon: "slider.horizontal.3", title: "Settings")

                SettingsSection(title: "General") {
                    Toggle("Usage gradient", isOn: $settings.usesUsageGradient)
                        .font(.system(size: 12, weight: .medium))
                    Toggle("Two-digit percent", isOn: $settings.usesTwoDigitPercent)
                        .font(.system(size: 12, weight: .medium))
                    SettingSlider(title: "CPU/MEM percent spacing", value: $settings.percentSymbolSpacing, range: 0...8, step: 0.1)
                    GraphColorPicker(title: "CPU/MEM border", color: $settings.menuBarBorderColor)
                }

                Divider()

                SettingsSection(title: "CPU") {
                    GradientColorPicker(title: "Graph color", lowColor: $settings.cpuGraphLowColor, midColor: $settings.cpuGraphMidColor, highColor: $settings.cpuGraphHighColor)
                    SettingRow {
                        SettingSlider(title: "Label text size", value: $settings.cpuLabelFontSize, range: 6.4...12, step: 0.1)
                        SettingSlider(title: "Value text size", value: $settings.cpuValueFontSize, range: 10...20, step: 0.1)
                    }
                    SettingRow {
                        SettingSlider(title: "Label-to-graph spacing", value: $settings.cpuLabelVisualSpacing, range: 0...16, step: 0.5)
                        SettingSlider(title: "Graph-to-value spacing", value: $settings.cpuVisualValueSpacing, range: 0...16, step: 0.5)
                    }
                    SettingSlider(title: "Horizontal inset", value: $settings.cpuHorizontalInset, range: 0...16, step: 0.5)
                    SettingSlider(title: "Graph height", value: $settings.cpuVisualHeight, range: 4...24, step: 0.5)
                    SettingSlider(title: "Graph duration", value: $settings.cpuGraphDisplaySeconds, range: 10...40, step: 1)
                }

                Divider()

                SettingsSection(title: "Memory") {
                    GradientColorPicker(title: "Gauge color", lowColor: $settings.memoryGraphLowColor, midColor: $settings.memoryGraphMidColor, highColor: $settings.memoryGraphHighColor)
                    SettingRow {
                        SettingSlider(title: "Label text size", value: $settings.memoryLabelFontSize, range: 6.4...12, step: 0.1)
                        SettingSlider(title: "Value text size", value: $settings.memoryValueFontSize, range: 10...20, step: 0.1)
                    }
                    SettingRow {
                        SettingSlider(title: "Label-to-gauge spacing", value: $settings.memoryLabelVisualSpacing, range: 0...16, step: 0.5)
                        SettingSlider(title: "Gauge-to-value spacing", value: $settings.memoryVisualValueSpacing, range: 0...16, step: 0.5)
                    }
                    SettingSlider(title: "Horizontal inset", value: $settings.memoryHorizontalInset, range: 0...16, step: 0.5)
                    SettingSlider(title: "Gauge height", value: $settings.memoryVisualHeight, range: 4...24, step: 0.5)
                }

                Divider()

                SettingsSection(title: "Network") {
                    GradientColorPicker(title: "Graph color", lowColor: $settings.networkGraphLowColor, midColor: $settings.networkGraphMidColor, highColor: $settings.networkGraphHighColor)
                    SettingRow {
                        SettingSlider(title: "Label text size", value: $settings.networkLabelFontSize, range: 6.4...12, step: 0.1)
                        SettingSlider(title: "Value text size", value: $settings.networkValueFontSize, range: 8...12, step: 0.1)
                    }
                    SettingRow {
                        SettingSlider(title: "Label-to-value spacing", value: $settings.networkLabelValueSpacing, range: 0...16, step: 0.5)
                        SettingSlider(title: "Value-to-unit spacing", value: $settings.networkUnitSpacing, range: 0...8, step: 0.1)
                    }
                    SettingSlider(title: "Horizontal inset", value: $settings.networkHorizontalInset, range: 0...16, step: 0.5)
                }
            }
            .padding(18)
        }
        .frame(width: 420, height: 720)
        .background(.regularMaterial)
    }
}

private struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 10) {
                content
            }
        }
    }
}

private struct SettingRow<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            content
        }
    }
}

private struct SettingSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                Spacer()
                Text(displayValue)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            ZStack(alignment: .leading) {
                Slider(value: $value, in: range, step: step)

                if showsZeroMark {
                    GeometryReader { proxy in
                        Rectangle()
                            .fill(.secondary.opacity(0.65))
                            .frame(width: 1, height: 10)
                            .offset(x: zeroOffset(width: proxy.size.width), y: 6)
                    }
                    .allowsHitTesting(false)
                }
            }
            .frame(height: 22)
        }
    }

    private var displayValue: String {
        step >= 1 ? String(format: "%.0f", value) : String(format: "%.1f", value)
    }

    private var showsZeroMark: Bool {
        range.lowerBound <= 0 && range.upperBound > 0
    }

    private func zeroOffset(width: CGFloat) -> CGFloat {
        let fraction = CGFloat((0 - range.lowerBound) / (range.upperBound - range.lowerBound))
        return min(max(0, width * fraction), max(0, width - 1))
    }
}

private struct GraphColorPicker: View {
    let title: String
    @Binding var color: GraphColor

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 12, weight: .medium))
            Spacer()
            CircularColorPicker(title: title, color: $color)
        }
    }
}

private struct GradientColorPicker: View {
    let title: String
    @Binding var lowColor: GraphColor
    @Binding var midColor: GraphColor
    @Binding var highColor: GraphColor

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .medium))

            HStack(spacing: 12) {
                ColorStopPicker(title: "Low", color: $lowColor)
                ColorStopPicker(title: "Mid", color: $midColor)
                ColorStopPicker(title: "High", color: $highColor)
            }
            .font(.system(size: 11, weight: .medium))
        }
    }
}

private struct ColorStopPicker: View {
    let title: String
    @Binding var color: GraphColor

    var body: some View {
        HStack(spacing: 6) {
            Text(title)
            CircularColorPicker(title: title, color: $color)
        }
    }
}

private struct CircularColorPicker: View {
    let title: String
    @Binding var color: GraphColor

    var body: some View {
        Button {
            ColorPanelController.shared.show(initialColor: color) { selectedColor in
                color = selectedColor
            }
        } label: {
            Circle()
                .fill(color.color)
                .frame(width: 22, height: 22)
                .overlay {
                    Circle()
                        .stroke(.primary.opacity(0.28), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .frame(width: 24, height: 24)
        .contentShape(Circle())
        .accessibilityLabel(title)
        .help(title)
    }
}

@MainActor
private final class ColorPanelController: NSObject {
    static let shared = ColorPanelController()

    private var updateColor: ((NSColor) -> Void)?
    private var colorObserver: NSObjectProtocol?

    deinit {
        if let colorObserver {
            NotificationCenter.default.removeObserver(colorObserver)
        }
    }

    func show(initialColor: GraphColor, update: @escaping (GraphColor) -> Void) {
        updateColor = { nsColor in
            update(GraphColor(nsColor))
        }

        let panel = NSColorPanel.shared
        panel.showsAlpha = false
        panel.isContinuous = true
        panel.color = initialColor.nsColor

        if let colorObserver {
            NotificationCenter.default.removeObserver(colorObserver)
        }
        colorObserver = NotificationCenter.default.addObserver(
            forName: NSColorPanel.colorDidChangeNotification,
            object: panel,
            queue: .main
        ) { [weak self] notification in
            guard let panel = notification.object as? NSColorPanel else { return }
            Task { @MainActor in
                self?.updateColor?(panel.color)
            }
        }

        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }
}
