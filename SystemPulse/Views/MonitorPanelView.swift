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

            HStack(alignment: .top, spacing: 10) {
                MemoryCard(memory: monitor.snapshot.memory)
                    .frame(width: 134)
                    .frame(height: memoryNetworkRowHeight)
                NetworkCard(network: monitor.snapshot.network)
                    .frame(width: 202)
                    .frame(height: memoryNetworkRowHeight)
            }

            HStack(alignment: .top, spacing: 10) {
                ThermalCard(thermal: monitor.snapshot.thermal)
                    .frame(width: 168)
                FanCard(fan: monitor.snapshot.fan)
                    .frame(width: 168)
            }
        }
        .padding(12)
        .frame(width: 370)
        .fixedSize(horizontal: false, vertical: true)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.regularMaterial)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .environment(\.colorScheme, .dark)
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
                confirmQuit()
            } label: {
                Image(systemName: "power")
                    .font(.system(size: 13, weight: .semibold))
            }
            .buttonStyle(.borderless)
            .help("Quit")
        }
    }

    private func confirmQuit() {
        let alert = NSAlert()
        alert.messageText = "Quit System Pulse?"
        alert.informativeText = "System monitoring will stop until you open the app again."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Quit")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            NSApp.terminate(nil)
        }
    }

    private var memoryNetworkRowHeight: CGFloat {
        max(
            settings.showsMemoryGraphInPopover ? 148 : 98,
            settings.showsNetworkGraphInPopover ? 148 : 98
        )
    }
}

private struct CPUCard: View {
    @EnvironmentObject private var settings: SettingsStore
    let cpu: CPUMetric

    var body: some View {
        MetricCard(fillsHeight: true) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    MetricTitle(icon: "cpu", title: "CPU")

                    Spacer()

                    Text(settings.percentText(cpu.usage))
                        .font(.system(size: 32, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(settings.adaptiveColor(low: settings.cpuGraphLowColor, mid: settings.cpuGraphMidColor, high: settings.cpuGraphHighColor, intensity: cpu.usage))
                }

                if settings.showsCPUGraphInPopover {
                    LineGraphView(
                        values: cpu.history,
                        colors: settings.gradientColors(low: settings.cpuGraphLowColor, mid: settings.cpuGraphMidColor, high: settings.cpuGraphHighColor, intensity: cpu.usage)
                    )
                    .frame(height: 86)
                }

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
                VStack(alignment: .leading, spacing: 3) {
                    MetricTitle(icon: "memorychip", title: "Memory")
                    Text(settings.percentText(memory.usage))
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                }

                if settings.showsMemoryGraphInPopover {
                    LineGraphView(
                        values: memory.history,
                        colors: settings.gradientColors(low: settings.memoryGraphLowColor, mid: settings.memoryGraphMidColor, high: settings.memoryGraphHighColor, intensity: memory.usage)
                    )
                    .frame(height: 44)
                }

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
        MetricCard(fillsHeight: true) {
            VStack(alignment: .leading, spacing: 9) {
                MetricTitle(icon: "arrow.up.arrow.down", title: "Network")

                Spacer(minLength: 0)

                if settings.showsNetworkGraphInPopover {
                    HStack(alignment: .top, spacing: 8) {
                        NetworkGraphColumn(
                            icon: "arrow.up",
                            value: network.uploadText,
                            values: network.uploadHistory,
                            intensity: network.uploadHistory.last ?? 0
                        )
                        NetworkGraphColumn(
                            icon: "arrow.down",
                            value: network.downloadText,
                            values: network.downloadHistory,
                            intensity: network.downloadHistory.last ?? 0
                        )
                    }
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        NetworkCompactRate(icon: "arrow.up", value: network.uploadText, unitSpacing: settings.networkUnitSpacing)
                        NetworkCompactRate(icon: "arrow.down", value: network.downloadText, unitSpacing: settings.networkUnitSpacing)
                    }
                }

                NetworkTotalsSummaryRow(
                    upload: network.totalUploadText,
                    download: network.totalDownloadText,
                    duration: network.measuredDurationText
                )
            }
            .frame(maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

private struct NetworkGraphColumn: View {
    @EnvironmentObject private var settings: SettingsStore
    let icon: String
    let value: String
    let values: [Double]
    let intensity: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            NetworkCompactRate(icon: icon, value: value, unitSpacing: settings.networkUnitSpacing, valueSizeBoost: 4.5)
            LineGraphView(
                values: values,
                colors: settings.gradientColors(low: settings.networkGraphLowColor, mid: settings.networkGraphMidColor, high: settings.networkGraphHighColor, intensity: intensity)
            )
            .frame(height: 44)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct NetworkCompactRate: View {
    @EnvironmentObject private var settings: SettingsStore
    let icon: String
    let value: String
    let unitSpacing: Double
    var valueSizeBoost: Double = 2.5

    var body: some View {
        let parts = rateParts

        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.secondary)

            HStack(spacing: CGFloat(unitSpacing.clamped(to: 0...8))) {
                Text(parts.number)
                    .font(.system(size: CGFloat((settings.networkValueFontSize + valueSizeBoost).clamped(to: 11...18)), weight: .semibold, design: .monospaced))
                if !parts.unit.isEmpty {
                    Text(parts.unit)
                        .font(.system(size: CGFloat(settings.networkUnitFontSize.clamped(to: 6...12)), weight: .semibold, design: .monospaced))
                }
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }

    private var rateParts: (number: String, unit: String) {
        let parts = value.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        guard parts.count == 2 else { return (value, "") }
        return (String(parts[0]), String(parts[1]))
    }
}

private struct NetworkTotalsSummaryRow: View {
    let upload: String
    let download: String
    let duration: String

    var body: some View {
        HStack(spacing: 6) {
            Text("Total")
                .font(.system(size: 10, weight: .semibold))
            Spacer(minLength: 2)
            NetworkTotalInlineItem(icon: "arrow.up", value: upload)
            NetworkTotalInlineItem(icon: "arrow.down", value: download)
            Spacer(minLength: 2)
            Text(duration)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .monospacedDigit()
        }
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .minimumScaleFactor(0.65)
    }
}

private struct NetworkTotalInlineItem: View {
    let icon: String
    let value: String

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .semibold))
            Text(value)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .monospacedDigit()
        }
    }
}

private struct ThermalCard: View {
    @EnvironmentObject private var settings: SettingsStore
    let thermal: ThermalMetric

    var body: some View {
        MetricCard {
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    MetricTitle(icon: "thermometer.medium", title: "CPU Temp")
                    Text(thermal.displayText)
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if settings.showsTemperatureGraphInPopover {
                    LineGraphView(
                        values: thermal.history,
                        colors: settings.gradientColors(low: settings.temperatureGraphLowColor, mid: settings.temperatureGraphMidColor, high: settings.temperatureGraphHighColor, intensity: thermal.history.last ?? 0)
                    )
                    .frame(height: 44)
                }
            }
        }
    }
}

private struct FanCard: View {
    @EnvironmentObject private var settings: SettingsStore
    let fan: FanMetric

    var body: some View {
        MetricCard {
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    MetricTitle(icon: "fan", title: "Fan")
                    Text(fan.displayText)
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if settings.showsFanGraphInPopover {
                    LineGraphView(
                        values: fan.history,
                        colors: settings.gradientColors(low: settings.fanGraphLowColor, mid: settings.fanGraphMidColor, high: settings.fanGraphHighColor, intensity: fan.history.last ?? 0)
                    )
                    .frame(height: 44)
                }
            }
        }
    }
}

struct SettingsWindowView: View {
    @EnvironmentObject private var settings: SettingsStore
    @State private var selectedTab: SettingsMetricTab = .cpu

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Spacer()
                    SettingsOrderModeToggle()
                }

                SettingsSection(title: "General", icon: "slider.horizontal.3") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Menu Bar Display")
                            .font(.system(size: 12, weight: .semibold))
                        HStack(spacing: 14) {
                            Toggle("CPU", isOn: $settings.showsCPUInMenuBar)
                                .disabled(!canHideCPU)
                            Toggle("Memory", isOn: $settings.showsMemoryInMenuBar)
                                .disabled(!canHideMemory)
                            Toggle("Network", isOn: $settings.showsNetworkInMenuBar)
                                .disabled(!canHideNetwork)
                            Toggle("CPU Temp", isOn: $settings.showsTemperatureInMenuBar)
                                .disabled(!canHideTemperature)
                            Toggle("Fan RPM", isOn: $settings.showsFanInMenuBar)
                                .disabled(!canHideFan)
                        }
                    }
                    .font(.system(size: 12, weight: .medium))

                    if settings.isMenuBarOrderModeEnabled {
                        MenuBarOrderEditor()
                    }

                    SettingRow {
                        Toggle("Usage gradient", isOn: $settings.usesUsageGradient)
                        Toggle("Two-digit percent", isOn: $settings.usesTwoDigitPercent)
                    }
                    .font(.system(size: 12, weight: .medium))
                    GraphColorPicker(title: "Graph border color", color: $settings.menuBarBorderColor)
                }

                Divider()

                SettingsTabPicker(selection: $selectedTab)
                selectedTabContent
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minWidth: 560, maxWidth: .infinity)
        .background(.regularMaterial)
    }

    @ViewBuilder
    private var selectedTabContent: some View {
        switch selectedTab {
        case .cpu:
            SettingsSection(title: "CPU", icon: "cpu") {
                SettingRow {
                    Toggle("Label", isOn: $settings.showsCPULabelInMenuBar)
                    Toggle("Graph", isOn: $settings.showsCPUGraphInMenuBar)
                    Toggle("Unit", isOn: $settings.showsCPUUnitInMenuBar)
                }
                .font(.system(size: 12, weight: .medium))
                GradientColorPicker(title: "Graph color", lowColor: $settings.cpuGraphLowColor, midColor: $settings.cpuGraphMidColor, highColor: $settings.cpuGraphHighColor)
                SettingRow {
                    SettingSlider(title: "Label text size", value: $settings.cpuLabelFontSize, range: 6.4...12, step: 0.1)
                    SettingSlider(title: "Value text size", value: $settings.cpuValueFontSize, range: 10...20, step: 0.1)
                    SettingSlider(title: "Unit text size", value: $settings.cpuUnitFontSize, range: 6...20, step: 0.1)
                }
                SettingRow {
                    SettingSlider(title: "Label-graph spacing", value: $settings.cpuLabelVisualSpacing, range: 0...16, step: 0.5)
                    SettingSlider(title: "Graph-value spacing", value: $settings.cpuVisualValueSpacing, range: 0...16, step: 0.5)
                    SettingSlider(title: "Value-unit spacing", value: $settings.cpuValueUnitSpacing, range: 0...8, step: 0.1)
                }
                SettingRow {
                    SettingSlider(title: "Graph height", value: $settings.cpuVisualHeight, range: 4...24, step: 0.5)
                    SettingSlider(title: "Graph duration", value: $settings.cpuGraphDisplaySeconds, range: 10...40, step: 1)
                }
                SettingSlider(title: "Horizontal inset", value: $settings.cpuHorizontalInset, range: 0...16, step: 0.5)
                Toggle("Popup graph display", isOn: $settings.showsCPUGraphInPopover)
                    .font(.system(size: 12, weight: .medium))
            }

        case .memory:
            SettingsSection(title: "Memory", icon: "memorychip") {
                SettingRow {
                    Toggle("Label", isOn: $settings.showsMemoryLabelInMenuBar)
                    Toggle("Graph", isOn: $settings.showsMemoryGraphInMenuBar)
                    Toggle("Unit", isOn: $settings.showsMemoryUnitInMenuBar)
                }
                .font(.system(size: 12, weight: .medium))
                GradientColorPicker(title: "Gauge color", lowColor: $settings.memoryGraphLowColor, midColor: $settings.memoryGraphMidColor, highColor: $settings.memoryGraphHighColor)
                SettingRow {
                    SettingSlider(title: "Label text size", value: $settings.memoryLabelFontSize, range: 6.4...12, step: 0.1)
                    SettingSlider(title: "Value text size", value: $settings.memoryValueFontSize, range: 10...20, step: 0.1)
                    SettingSlider(title: "Unit text size", value: $settings.memoryUnitFontSize, range: 6...20, step: 0.1)
                }
                SettingRow {
                    SettingSlider(title: "Label-gauge spacing", value: $settings.memoryLabelVisualSpacing, range: 0...16, step: 0.5)
                    SettingSlider(title: "Gauge-value spacing", value: $settings.memoryVisualValueSpacing, range: 0...16, step: 0.5)
                    SettingSlider(title: "Value-unit spacing", value: $settings.memoryValueUnitSpacing, range: 0...8, step: 0.1)
                }
                SettingRow {
                    SettingSlider(title: "Gauge height", value: $settings.memoryVisualHeight, range: 4...24, step: 0.5)
                    SettingSlider(title: "Gauge width", value: $settings.memoryVisualWidth, range: 4...20, step: 0.5)
                }
                SettingSlider(title: "Horizontal inset", value: $settings.memoryHorizontalInset, range: 0...16, step: 0.5)
                Toggle("Popup graph display", isOn: $settings.showsMemoryGraphInPopover)
                    .font(.system(size: 12, weight: .medium))
            }

        case .network:
            SettingsSection(title: "Network", icon: "network") {
                SettingRow {
                    Toggle("Label", isOn: $settings.showsNetworkLabelInMenuBar)
                    Toggle("Graph", isOn: $settings.showsNetworkGraphInMenuBar)
                    Toggle("Unit", isOn: $settings.showsNetworkUnitInMenuBar)
                }
                .font(.system(size: 12, weight: .medium))
                GradientColorPicker(title: "Graph color", lowColor: $settings.networkGraphLowColor, midColor: $settings.networkGraphMidColor, highColor: $settings.networkGraphHighColor)
                SettingRow {
                    SettingSlider(title: "Label text size", value: $settings.networkLabelFontSize, range: 6.4...12, step: 0.1)
                    SettingSlider(title: "Value text size", value: $settings.networkValueFontSize, range: 8...12, step: 0.1)
                    SettingSlider(title: "Unit text size", value: $settings.networkUnitFontSize, range: 6...12, step: 0.1)
                }
                SettingRow {
                    SettingSlider(title: "Label-graph spacing", value: $settings.networkLabelValueSpacing, range: 0...16, step: 0.5)
                    SettingSlider(title: "Graph-value spacing", value: $settings.networkGraphValueSpacing, range: 0...16, step: 0.5)
                    SettingSlider(title: "Value-unit spacing", value: $settings.networkUnitSpacing, range: 0...8, step: 0.1)
                }
                SettingRow {
                    SettingSlider(title: "Graph height", value: $settings.networkGraphHeight, range: 4...10, step: 0.5)
                    SettingSlider(title: "Graph width", value: $settings.networkGraphWidth, range: 8...40, step: 1)
                }
                SettingSlider(title: "Horizontal inset", value: $settings.networkHorizontalInset, range: 0...16, step: 0.5)
                Toggle("Popup graph display", isOn: $settings.showsNetworkGraphInPopover)
                    .font(.system(size: 12, weight: .medium))
            }

        case .temperature:
            SettingsSection(title: "CPU Temperature", icon: "thermometer.medium") {
                SettingRow {
                    Toggle("Label", isOn: $settings.showsTemperatureLabelInMenuBar)
                    Toggle("Graph", isOn: $settings.showsTemperatureGraphInMenuBar)
                    Toggle("Unit", isOn: $settings.showsTemperatureUnitInMenuBar)
                }
                .font(.system(size: 12, weight: .medium))
                GradientColorPicker(title: "Graph color", lowColor: $settings.temperatureGraphLowColor, midColor: $settings.temperatureGraphMidColor, highColor: $settings.temperatureGraphHighColor)
                SettingRow {
                    SettingSlider(title: "Label text size", value: $settings.temperatureLabelFontSize, range: 6...14, step: 0.1)
                    SettingSlider(title: "Value text size", value: $settings.temperatureValueFontSize, range: 8...20, step: 0.1)
                    SettingSlider(title: "Unit text size", value: $settings.temperatureUnitFontSize, range: 6...14, step: 0.1)
                }
                SettingRow {
                    SettingSlider(title: "Label-graph spacing", value: $settings.temperatureLabelValueSpacing, range: 0...16, step: 0.5)
                    SettingSlider(title: "Graph-value spacing", value: $settings.temperatureGraphValueSpacing, range: 0...16, step: 0.5)
                    SettingSlider(title: "Value-unit spacing", value: $settings.temperatureValueUnitSpacing, range: 0...12, step: 0.5)
                }
                SettingRow {
                    SettingSlider(title: "Graph height", value: $settings.temperatureGraphHeight, range: 4...18, step: 0.5)
                    SettingSlider(title: "Graph width", value: $settings.temperatureGraphWidth, range: 8...40, step: 1)
                }
                SettingSlider(title: "Horizontal inset", value: $settings.temperatureHorizontalInset, range: 0...16, step: 0.5)
                Toggle("Popup graph display", isOn: $settings.showsTemperatureGraphInPopover)
                    .font(.system(size: 12, weight: .medium))
            }

        case .fan:
            SettingsSection(title: "Fan", icon: "fan") {
                SettingRow {
                    Toggle("Label", isOn: $settings.showsFanLabelInMenuBar)
                    Toggle("Graph", isOn: $settings.showsFanGraphInMenuBar)
                    Toggle("Unit", isOn: $settings.showsFanUnitInMenuBar)
                }
                .font(.system(size: 12, weight: .medium))
                GradientColorPicker(title: "Graph color", lowColor: $settings.fanGraphLowColor, midColor: $settings.fanGraphMidColor, highColor: $settings.fanGraphHighColor)
                SettingRow {
                    SettingSlider(title: "Label text size", value: $settings.fanLabelFontSize, range: 6...14, step: 0.1)
                    SettingSlider(title: "Value text size", value: $settings.fanValueFontSize, range: 8...20, step: 0.1)
                    SettingSlider(title: "Unit text size", value: $settings.fanUnitFontSize, range: 6...14, step: 0.1)
                }
                SettingRow {
                    SettingSlider(title: "Label-graph spacing", value: $settings.fanLabelValueSpacing, range: 0...16, step: 0.5)
                    SettingSlider(title: "Graph-value spacing", value: $settings.fanGraphValueSpacing, range: 0...16, step: 0.5)
                    SettingSlider(title: "Value-unit spacing", value: $settings.fanValueUnitSpacing, range: 0...12, step: 0.5)
                }
                SettingRow {
                    SettingSlider(title: "Graph height", value: $settings.fanGraphHeight, range: 4...18, step: 0.5)
                    SettingSlider(title: "Graph width", value: $settings.fanGraphWidth, range: 8...40, step: 1)
                }
                SettingSlider(title: "Horizontal inset", value: $settings.fanHorizontalInset, range: 0...16, step: 0.5)
                Toggle("Popup graph display", isOn: $settings.showsFanGraphInPopover)
                    .font(.system(size: 12, weight: .medium))
            }
        }
    }

    private var canHideCPU: Bool {
        settings.showsMemoryInMenuBar
            || settings.showsNetworkInMenuBar
            || settings.showsTemperatureInMenuBar
            || settings.showsFanInMenuBar
    }

    private var canHideMemory: Bool {
        settings.showsCPUInMenuBar
            || settings.showsNetworkInMenuBar
            || settings.showsTemperatureInMenuBar
            || settings.showsFanInMenuBar
    }

    private var canHideNetwork: Bool {
        settings.showsCPUInMenuBar
            || settings.showsMemoryInMenuBar
            || settings.showsTemperatureInMenuBar
            || settings.showsFanInMenuBar
    }

    private var canHideTemperature: Bool {
        settings.showsCPUInMenuBar
            || settings.showsMemoryInMenuBar
            || settings.showsNetworkInMenuBar
            || settings.showsFanInMenuBar
    }

    private var canHideFan: Bool {
        settings.showsCPUInMenuBar
            || settings.showsMemoryInMenuBar
            || settings.showsNetworkInMenuBar
            || settings.showsTemperatureInMenuBar
    }
}

struct SettingsOrderModeToggle: View {
    @EnvironmentObject private var settings: SettingsStore

    var body: some View {
        Toggle("Order mode", isOn: $settings.isMenuBarOrderModeEnabled)
            .toggleStyle(.checkbox)
            .font(.system(size: 12, weight: .medium))
            .padding(.trailing, 4)
    }
}

private struct MenuBarOrderEditor: View {
    @EnvironmentObject private var settings: SettingsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Menu Bar Order")
                .font(.system(size: 12, weight: .semibold))

            HStack(spacing: 8) {
                ForEach(SettingsStore.normalizedMenuBarMetricOrder(settings.menuBarMetricOrder)) { metric in
                    HStack(spacing: 5) {
                        Image(systemName: metric.icon)
                            .font(.system(size: 10, weight: .semibold))
                        Text(metric.title)
                            .font(.system(size: 11, weight: .semibold))
                            .lineLimit(1)

                        VStack(spacing: 1) {
                            orderButton(icon: "chevron.left", metric: metric, offset: -1)
                            orderButton(icon: "chevron.right", metric: metric, offset: 1)
                        }
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(Color.primary.opacity(0.08))
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func orderButton(icon: String, metric: MenuBarMetricKind, offset: Int) -> some View {
        Button {
            move(metric, by: offset)
        } label: {
            Image(systemName: icon)
                .font(.system(size: 8, weight: .bold))
                .frame(width: 11, height: 9)
        }
        .buttonStyle(.plain)
        .foregroundStyle(canMove(metric, by: offset) ? Color.secondary : Color.secondary.opacity(0.35))
        .disabled(!canMove(metric, by: offset))
    }

    private func move(_ metric: MenuBarMetricKind, by offset: Int) {
        var order = SettingsStore.normalizedMenuBarMetricOrder(settings.menuBarMetricOrder)
        guard let index = order.firstIndex(of: metric) else { return }
        let newIndex = index + offset
        guard order.indices.contains(newIndex) else { return }
        order.swapAt(index, newIndex)
        settings.menuBarMetricOrder = order
    }

    private func canMove(_ metric: MenuBarMetricKind, by offset: Int) -> Bool {
        let order = SettingsStore.normalizedMenuBarMetricOrder(settings.menuBarMetricOrder)
        guard let index = order.firstIndex(of: metric) else { return false }
        return order.indices.contains(index + offset)
    }
}

private enum SettingsMetricTab: String, CaseIterable, Identifiable {
    case cpu
    case memory
    case network
    case temperature
    case fan

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cpu: return "CPU"
        case .memory: return "Memory"
        case .network: return "Network"
        case .temperature: return "CPU Temp"
        case .fan: return "Fan RPM"
        }
    }

    var icon: String {
        switch self {
        case .cpu: return "cpu"
        case .memory: return "memorychip"
        case .network: return "network"
        case .temperature: return "thermometer.medium"
        case .fan: return "fan"
        }
    }
}

private struct SettingsTabPicker: View {
    @Binding var selection: SettingsMetricTab

    var body: some View {
        HStack(spacing: 6) {
            ForEach(SettingsMetricTab.allCases) { tab in
                Button {
                    selection = tab
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 11, weight: .semibold))
                        Text(tab.title)
                            .font(.system(size: 12, weight: .semibold))
                            .lineLimit(1)
                    }
                    .foregroundStyle(selection == tab ? .primary : .secondary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(selection == tab ? Color.primary.opacity(0.10) : Color.clear)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct SettingsSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 14)
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 12) {
                content
            }
        }
        .padding(.bottom, 4)
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

            TicklessSlider(value: $value, range: range, step: step)
                .frame(height: 22)
        }
        .frame(maxWidth: .infinity)
    }

    private var displayValue: String {
        if step >= 1 {
            return String(format: "%.0f", value)
        }

        return step < 0.1 ? String(format: "%.2f", value) : String(format: "%.1f", value)
    }
}

private struct TicklessSlider: NSViewRepresentable {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double

    func makeNSView(context: Context) -> NSSlider {
        let slider = NSSlider(value: value, minValue: range.lowerBound, maxValue: range.upperBound, target: context.coordinator, action: #selector(Coordinator.changed(_:)))
        slider.isContinuous = true
        slider.numberOfTickMarks = 0
        slider.allowsTickMarkValuesOnly = false
        slider.controlSize = .small
        return slider
    }

    func updateNSView(_ slider: NSSlider, context: Context) {
        context.coordinator.parent = self
        slider.minValue = range.lowerBound
        slider.maxValue = range.upperBound
        slider.numberOfTickMarks = 0
        slider.allowsTickMarkValuesOnly = false
        if abs(slider.doubleValue - value) > 0.0001 {
            slider.doubleValue = value
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject {
        var parent: TicklessSlider

        init(_ parent: TicklessSlider) {
            self.parent = parent
        }

        @objc func changed(_ sender: NSSlider) {
            let rawValue = sender.doubleValue.clamped(to: parent.range)
            let steppedValue: Double
            if parent.step > 0 {
                steppedValue = (rawValue / parent.step).rounded() * parent.step
            } else {
                steppedValue = rawValue
            }
            parent.value = steppedValue.clamped(to: parent.range)
        }
    }
}

private struct GraphColorPicker: View {
    let title: String
    @Binding var color: GraphColor

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
            CircularColorPicker(title: title, color: $color)
            Spacer()
        }
    }
}

private struct BorderColorOpacityControl: View {
    let title: String
    @Binding var color: GraphColor
    @Binding var opacity: Double

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            HStack {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                Spacer()
                CircularColorPicker(title: title, color: $color)
            }
            .frame(maxWidth: .infinity)

            SettingSlider(title: "Opacity", value: $opacity, range: 0...1, step: 0.05)
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
            Capsule()
                .fill(color.color)
                .frame(width: 22, height: 14)
                .overlay {
                    Capsule()
                        .stroke(.primary.opacity(0.28), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .frame(width: 24, height: 18)
        .contentShape(Capsule())
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
        panel.showsAlpha = true
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
