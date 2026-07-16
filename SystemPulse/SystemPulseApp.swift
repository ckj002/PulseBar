import AppKit
import Combine
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var monitor: SystemMonitorService?
    private var settings: SettingsStore?
    private var statusBarController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let monitor = SystemMonitorService()
        let settings = SettingsStore()
        self.monitor = monitor
        self.settings = settings
        self.statusBarController = StatusBarController(monitor: monitor, settings: settings)

        if ProcessInfo.processInfo.arguments.contains("--open-settings") {
            SettingsWindowController.shared.show(settings: settings)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        monitor?.stop()
    }
}

@main
struct SystemPulseApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

@MainActor
final class PopoverPinState: ObservableObject {
    @Published private(set) var isPinned = false
    var onChange: ((Bool) -> Void)?

    func toggle() {
        setPinned(!isPinned)
    }

    func setPinned(_ value: Bool) {
        guard isPinned != value else { return }
        isPinned = value
        onChange?(isPinned)
    }
}

@MainActor
final class StatusBarController: NSObject {
    private let monitor: SystemMonitorService
    private let settings: SettingsStore
    private var cpuItem: NSStatusItem!
    private var memoryItem: NSStatusItem!
    private var diskItem: NSStatusItem!
    private var networkItem: NSStatusItem!
    private var temperatureItem: NSStatusItem!
    private var fanItem: NSStatusItem!
    private var appearanceItem: NSStatusItem!
    private let popover = NSPopover()
    private let popoverPinState = PopoverPinState()
    private var pinnedPanel: NSPanel?
    private var appliedMenuBarOrder: [MenuBarMetricKind] = []
    private var cancellables = Set<AnyCancellable>()
    private let menuBarTextColor = NSColor(calibratedWhite: 0.08, alpha: 0.88)

    init(monitor: SystemMonitorService, settings: SettingsStore) {
        self.monitor = monitor
        self.settings = settings
        super.init()

        popoverPinState.onChange = { [weak self] isPinned in
            guard let self else { return }
            self.popover.behavior = isPinned ? .applicationDefined : .transient
            if isPinned {
                self.showPinnedPanel()
            } else {
                self.closePinnedPanel()
            }
        }

        applyAppAppearance()
        configureStatusItems()
        configurePopover()
        applyStatusItemLengths()
        updateStatusItems(with: monitor.snapshot)

        monitor.$snapshot.sink { [weak self] snapshot in
            self?.updateStatusItems(with: snapshot)
        }
        .store(in: &cancellables)

        settings.didChange.sink { [weak self] in
            guard let self else { return }
            let menuBarOrder = SettingsStore.normalizedMenuBarMetricOrder(self.settings.menuBarMetricOrder)
            if menuBarOrder != self.appliedMenuBarOrder {
                self.configureStatusItems()
            }
            self.applyAppAppearance()
            self.applyStatusItemLengths()
            self.updatePopoverSize()
            self.updateStatusItems(with: self.monitor.snapshot)
        }
        .store(in: &cancellables)
    }

    private func configureStatusItems() {
        removeConfiguredStatusItems()

        for metric in SettingsStore.normalizedMenuBarMetricOrder(settings.menuBarMetricOrder) {
            let item = NSStatusBar.system.statusItem(withLength: 24)
            item.autosaveName = NSStatusItem.AutosaveName(metric.statusItemAutosaveName)
            assignStatusItem(item, for: metric)
        }
        appliedMenuBarOrder = SettingsStore.normalizedMenuBarMetricOrder(settings.menuBarMetricOrder)

        cpuItem.autosaveName = NSStatusItem.AutosaveName("dev.local.SystemPulse.cpu")
        memoryItem.autosaveName = NSStatusItem.AutosaveName("dev.local.SystemPulse.memory")
        diskItem.autosaveName = NSStatusItem.AutosaveName("dev.local.SystemPulse.disk")
        networkItem.autosaveName = NSStatusItem.AutosaveName("dev.local.SystemPulse.network")
        temperatureItem.autosaveName = NSStatusItem.AutosaveName("dev.local.SystemPulse.temperature")
        fanItem.autosaveName = NSStatusItem.AutosaveName("dev.local.SystemPulse.fan")
        appearanceItem.autosaveName = NSStatusItem.AutosaveName("dev.local.SystemPulse.appearance")

        [cpuItem, memoryItem, diskItem, networkItem, temperatureItem, fanItem].forEach { item in
            item.button?.target = self
            item.button?.action = #selector(togglePopover(_:))
            item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        appearanceItem.button?.target = self
        appearanceItem.button?.action = #selector(toggleAppearanceMode(_:))
        appearanceItem.button?.sendAction(on: [.leftMouseUp])

        [cpuItem, memoryItem, diskItem, networkItem, temperatureItem, fanItem, appearanceItem].forEach { item in
            item.button?.imagePosition = .imageOnly
            item.button?.imageScaling = .scaleNone
        }

        cpuItem.button?.toolTip = "CPU"
        memoryItem.button?.toolTip = "Memory"
        diskItem.button?.toolTip = "Disk"
        networkItem.button?.toolTip = "Network"
        temperatureItem.button?.toolTip = "CPU Temperature"
        fanItem.button?.toolTip = "Fan RPM"
        appearanceItem.button?.toolTip = "Toggle dark/light mode"
    }

    private func removeConfiguredStatusItems() {
        let existingItems: [NSStatusItem?] = [cpuItem, memoryItem, diskItem, networkItem, temperatureItem, fanItem, appearanceItem]
        existingItems.compactMap { $0 }.forEach {
            NSStatusBar.system.removeStatusItem($0)
        }
    }

    private func assignStatusItem(_ item: NSStatusItem, for metric: MenuBarMetricKind) {
        switch metric {
        case .cpu:
            cpuItem = item
        case .memory:
            memoryItem = item
        case .disk:
            diskItem = item
        case .network:
            networkItem = item
        case .temperature:
            temperatureItem = item
        case .fan:
            fanItem = item
        case .appearance:
            appearanceItem = item
        }
    }

    private func configurePopover() {
        popover.behavior = popoverPinState.isPinned ? .applicationDefined : .transient
        popover.appearance = currentAppearance
        popover.contentViewController = NSHostingController(
            rootView: MonitorPanelView()
                .environmentObject(monitor)
                .environmentObject(settings)
                .environmentObject(popoverPinState)
        )
        updatePopoverSize()
    }

    private func updateStatusItems(with snapshot: SystemSnapshot) {
        if shouldShowCPUInMenuBar {
            setStatusImage(
                cpuStatusImage(history: snapshot.cpu.history, usage: snapshot.cpu.usage),
                on: cpuItem
            )
        } else {
            clearStatusItem(cpuItem)
        }

        if settings.showsMemoryInMenuBar {
            setStatusImage(
                memoryStatusImage(usage: snapshot.memory.usage),
                on: memoryItem
            )
        } else {
            clearStatusItem(memoryItem)
        }

        if settings.showsNetworkInMenuBar {
            setStatusImage(
                networkStatusImage(network: snapshot.network),
                on: networkItem
            )
        } else {
            clearStatusItem(networkItem)
        }

        if settings.showsDiskInMenuBar {
            setStatusImage(
                diskStatusImage(disk: snapshot.disk),
                on: diskItem
            )
        } else {
            clearStatusItem(diskItem)
        }

        if settings.showsTemperatureInMenuBar {
            setStatusImage(
                temperatureStatusImage(
                    temperature: snapshot.thermal.cpuTemperatureCelsius,
                    history: snapshot.thermal.history
                ),
                on: temperatureItem
            )
        } else {
            clearStatusItem(temperatureItem)
        }

        if settings.showsFanInMenuBar {
            setStatusImage(
                fanStatusImage(
                    rpm: snapshot.fan.rpm,
                    history: snapshot.fan.history
                ),
                on: fanItem
            )
        } else {
            clearStatusItem(fanItem)
        }

        updateAppearanceStatusItem()
    }

    private func updatePopoverSize() {
        let width: CGFloat = 370
        let padding: CGFloat = 24
        let interSectionSpacing: CGFloat = 30
        let headerHeight: CGFloat = 22
        let cpuHeight: CGFloat = 105 + (settings.showsCPUGraphInPopover ? 86 : 0)
        let memoryHeight: CGFloat = 98 + (settings.showsMemoryGraphInPopover ? 44 : 0)
        let networkHeight: CGFloat = 74 + (settings.showsNetworkGraphInPopover ? 64 : 0)
        let compactMetricHeight: CGFloat = 76
        let thermalHeight = compactMetricHeight + (settings.showsTemperatureGraphInPopover ? 44 : 0)
        let fanHeight = compactMetricHeight + (settings.showsFanGraphInPopover ? 44 : 0)
        let diskHeight: CGFloat = 86
        let height = padding
            + headerHeight
            + interSectionSpacing
            + 10
            + cpuHeight
            + max(memoryHeight, networkHeight)
            + max(thermalHeight, fanHeight)
            + diskHeight

        popover.contentSize = NSSize(width: width, height: ceil(height))
        pinnedPanel?.setContentSize(popover.contentSize)
    }

    private func showPinnedPanel() {
        popover.performClose(nil)

        if let pinnedPanel {
            pinnedPanel.setContentSize(popover.contentSize)
            pinnedPanel.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hostingController = NSHostingController(
            rootView: MonitorPanelView()
                .environmentObject(monitor)
                .environmentObject(settings)
                .environmentObject(popoverPinState)
        )
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: popover.contentSize),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.contentViewController = hostingController
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.appearance = currentAppearance
        panel.hasShadow = true
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = []
        panel.delegate = self
        panel.center()
        pinnedPanel = panel
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func closePinnedPanel() {
        guard let panel = pinnedPanel else { return }
        pinnedPanel = nil
        panel.delegate = nil
        panel.close()
    }

    private func applyStatusItemLengths() {
        cpuItem.isVisible = shouldShowCPUInMenuBar
        memoryItem.isVisible = settings.showsMemoryInMenuBar
        diskItem.isVisible = settings.showsDiskInMenuBar
        networkItem.isVisible = settings.showsNetworkInMenuBar
        temperatureItem.isVisible = settings.showsTemperatureInMenuBar
        fanItem.isVisible = settings.showsFanInMenuBar
        appearanceItem.isVisible = settings.showsAppearanceToggleInMenuBar
        cpuItem.length = shouldShowCPUInMenuBar ? 24 : 0
        memoryItem.length = settings.showsMemoryInMenuBar ? 24 : 0
        diskItem.length = settings.showsDiskInMenuBar ? 24 : 0
        networkItem.length = settings.showsNetworkInMenuBar ? 24 : 0
        temperatureItem.length = settings.showsTemperatureInMenuBar ? 24 : 0
        fanItem.length = settings.showsFanInMenuBar ? 24 : 0
        appearanceItem.length = settings.showsAppearanceToggleInMenuBar ? 24 : 0
    }

    private func setStatusImage(_ image: NSImage, on item: NSStatusItem) {
        item.isVisible = true
        item.button?.attributedTitle = NSAttributedString(string: "")
        item.button?.title = ""
        item.button?.image = image
        item.length = image.size.width
    }

    private func clearStatusItem(_ item: NSStatusItem) {
        item.button?.image = nil
        item.button?.attributedTitle = NSAttributedString(string: "")
        item.button?.title = ""
        item.length = 0
        item.isVisible = false
    }

    private func updateAppearanceStatusItem() {
        guard settings.showsAppearanceToggleInMenuBar else {
            clearStatusItem(appearanceItem)
            return
        }

        let symbolName = settings.usesDarkAppearance ? "circle.lefthalf.filled" : "circle.righthalf.filled"
        let configuration = NSImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
        let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Toggle dark/light mode")?
            .withSymbolConfiguration(configuration)
            ?? NSImage(size: NSSize(width: 16, height: 16))
        image.isTemplate = true

        appearanceItem.isVisible = true
        appearanceItem.button?.attributedTitle = NSAttributedString(string: "")
        appearanceItem.button?.title = ""
        appearanceItem.button?.image = image
        appearanceItem.length = 24
    }

    private var currentAppearance: NSAppearance? {
        NSAppearance(named: settings.usesDarkAppearance ? .darkAqua : .aqua)
    }

    private func applyAppAppearance() {
        let appearance = currentAppearance
        NSApp.appearance = appearance
        popover.appearance = appearance
        pinnedPanel?.appearance = appearance
    }

    private var shouldShowCPUInMenuBar: Bool {
        settings.showsCPUInMenuBar || !hasVisibleMenuBarItem
    }

    private var hasVisibleMenuBarItem: Bool {
        settings.showsCPUInMenuBar
            || settings.showsMemoryInMenuBar
            || settings.showsDiskInMenuBar
            || settings.showsNetworkInMenuBar
            || settings.showsTemperatureInMenuBar
            || settings.showsFanInMenuBar
            || settings.showsAppearanceToggleInMenuBar
    }

    private func cpuStatusImage(history: [Double], usage: Double) -> NSImage {
        let height = menuBarImageHeight
        let showsLabel = settings.showsCPULabelInMenuBar
        let showsGraph = settings.showsCPUGraphInMenuBar
        let labelFontSize = settings.cpuLabelFontSize.clamped(to: 6.4...12)
        let labelSize = showsLabel ? verticalLabelSize(fontSize: labelFontSize) : .zero
        let valueFont = NSFont.monospacedSystemFont(
            ofSize: CGFloat(settings.cpuValueFontSize.clamped(to: 10...20)),
            weight: .medium
        )
        let valueAttributes: [NSAttributedString.Key: Any] = [
            .font: valueFont,
            .foregroundColor: menuBarTextColor
        ]
        let unitAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: CGFloat(settings.cpuUnitFontSize.clamped(to: 6...20)), weight: .medium),
            .foregroundColor: menuBarTextColor.withAlphaComponent(0.72)
        ]
        let horizontalInset = horizontalInset(settings.cpuHorizontalInset)
        let labelGraphSpacing = showsLabel && showsGraph ? spacing(settings.cpuLabelVisualSpacing) : 0
        let labelValueSpacing = showsLabel && !showsGraph ? spacing(settings.cpuVisualValueSpacing) : 0
        let graphValueSpacing = spacing(settings.cpuVisualValueSpacing)
        let graphSeconds = CGFloat(settings.cpuGraphDisplaySeconds.clamped(to: 10...40).rounded())
        let graphSize = showsGraph ? NSSize(width: graphSeconds, height: visualHeight(settings.cpuVisualHeight)) : .zero
        let percentWidth = percentTextWidth(
            usage,
            valueAttributes: valueAttributes,
            unitAttributes: unitAttributes,
            showsSymbol: settings.showsCPUUnitInMenuBar,
            spacing: settings.cpuValueUnitSpacing
        )
        let contentWidth = labelSize.width + labelGraphSpacing + labelValueSpacing + graphSize.width + (showsGraph ? graphValueSpacing : 0) + percentWidth
        let width = contentWidth + horizontalInset * 2
        let image = NSImage(size: NSSize(width: width, height: height))
        var x = horizontalInset

        image.lockFocus()
        NSGraphicsContext.current?.shouldAntialias = true
        if showsLabel {
            verticalLabelImage("CPU", fontSize: labelFontSize).draw(
                in: NSRect(x: x, y: centeredY(height: labelSize.height, in: height, offset: 0), width: labelSize.width, height: labelSize.height)
            )
            x += labelSize.width + labelGraphSpacing
            if !showsGraph {
                x += labelValueSpacing
            }
        }

        if showsGraph {
            cpuGraphImage(history, size: graphSize).draw(
                in: NSRect(x: x, y: centeredY(height: graphSize.height, in: height, offset: 0), width: graphSize.width, height: graphSize.height)
            )
            x += graphSize.width + graphValueSpacing
        }

        drawPercentText(
            usage,
            valueAttributes: valueAttributes,
            unitAttributes: unitAttributes,
            x: x,
            height: height,
            offset: 0,
            showsSymbol: settings.showsCPUUnitInMenuBar,
            spacing: settings.cpuValueUnitSpacing
        )
        image.unlockFocus()
        image.isTemplate = false

        return image
    }

    private func memoryStatusImage(usage: Double) -> NSImage {
        let height = menuBarImageHeight
        let showsLabel = settings.showsMemoryLabelInMenuBar
        let showsGraph = settings.showsMemoryGraphInMenuBar
        let labelFontSize = settings.memoryLabelFontSize.clamped(to: 6.4...12)
        let labelSize = showsLabel ? verticalLabelSize(fontSize: labelFontSize) : .zero
        let valueFont = NSFont.monospacedSystemFont(
            ofSize: CGFloat(settings.memoryValueFontSize.clamped(to: 10...20)),
            weight: .medium
        )
        let valueAttributes: [NSAttributedString.Key: Any] = [
            .font: valueFont,
            .foregroundColor: menuBarTextColor
        ]
        let unitAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: CGFloat(settings.memoryUnitFontSize.clamped(to: 6...20)), weight: .medium),
            .foregroundColor: menuBarTextColor.withAlphaComponent(0.72)
        ]
        let horizontalInset = horizontalInset(settings.memoryHorizontalInset)
        let labelGaugeSpacing = showsLabel && showsGraph ? spacing(settings.memoryLabelVisualSpacing) : 0
        let labelValueSpacing = showsLabel && !showsGraph ? spacing(settings.memoryVisualValueSpacing) : 0
        let gaugeValueSpacing = spacing(settings.memoryVisualValueSpacing)
        let gaugeSize = showsGraph ? NSSize(
            width: CGFloat(settings.memoryVisualWidth.clamped(to: 4...20)),
            height: visualHeight(settings.memoryVisualHeight)
        ) : .zero
        let percentWidth = percentTextWidth(
            usage,
            valueAttributes: valueAttributes,
            unitAttributes: unitAttributes,
            showsSymbol: settings.showsMemoryUnitInMenuBar,
            spacing: settings.memoryValueUnitSpacing
        )
        let contentWidth = labelSize.width + labelGaugeSpacing + labelValueSpacing + gaugeSize.width + (showsGraph ? gaugeValueSpacing : 0) + percentWidth
        let width = contentWidth + horizontalInset * 2
        let image = NSImage(size: NSSize(width: width, height: height))
        var x = horizontalInset

        image.lockFocus()
        NSGraphicsContext.current?.shouldAntialias = true
        if showsLabel {
            verticalLabelImage("MEM", fontSize: labelFontSize).draw(
                in: NSRect(x: x, y: centeredY(height: labelSize.height, in: height, offset: 0), width: labelSize.width, height: labelSize.height)
            )
            x += labelSize.width + labelGaugeSpacing
            if !showsGraph {
                x += labelValueSpacing
            }
        }

        if showsGraph {
            memoryGaugeImage(usage, size: gaugeSize).draw(
                in: NSRect(x: x, y: centeredY(height: gaugeSize.height, in: height, offset: 0), width: gaugeSize.width, height: gaugeSize.height)
            )
            x += gaugeSize.width + gaugeValueSpacing
        }

        drawPercentText(
            usage,
            valueAttributes: valueAttributes,
            unitAttributes: unitAttributes,
            x: x,
            height: height,
            offset: 0,
            showsSymbol: settings.showsMemoryUnitInMenuBar,
            spacing: settings.memoryValueUnitSpacing
        )
        image.unlockFocus()
        image.isTemplate = false

        return image
    }

    private func networkStatusImage(network: NetworkMetric) -> NSImage {
        let content = networkImage(network: network)
        let horizontalInset = horizontalInset(settings.networkHorizontalInset)
        let width = content.size.width + horizontalInset * 2
        let height = menuBarImageHeight
        let image = NSImage(size: NSSize(width: width, height: height))

        image.lockFocus()
        NSGraphicsContext.current?.shouldAntialias = true
        content.draw(
            in: NSRect(
                x: horizontalInset,
                y: centeredY(height: content.size.height, in: height, offset: 0),
                width: content.size.width,
                height: content.size.height
            )
        )
        image.unlockFocus()
        image.isTemplate = false

        return image
    }

    private func diskStatusImage(disk: DiskMetric) -> NSImage {
        let parts = diskValueParts(disk.freeText(showsDecimal: settings.showsDiskDecimalCapacity))
        return compactStatusImage(
            label: settings.showsDiskLabelInMenuBar ? "DSK" : nil,
            value: disk.availability == .available ? parts.number : "--",
            unit: settings.showsDiskUnitInMenuBar && disk.availability == .available ? parts.unit : nil,
            graph: nil,
            labelFontSize: settings.diskLabelFontSize,
            valueFontSize: settings.diskValueFontSize,
            unitFontSize: settings.diskUnitFontSize,
            labelValueSpacing: settings.diskLabelValueSpacing,
            graphValueSpacing: 0,
            valueUnitSpacing: settings.diskValueUnitSpacing,
            horizontalInset: settings.diskHorizontalInset
        )
    }

    private func diskValueParts(_ text: String) -> (number: String, unit: String) {
        let parts = text.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        guard parts.count == 2 else { return (text, "") }
        return (String(parts[0]), String(parts[1]))
    }

    private func temperatureStatusImage(temperature: Double?, history: [Double]) -> NSImage {
        let value = temperature.map { String(format: "%.0f", $0) } ?? "--"
        let graph = settings.showsTemperatureGraphInMenuBar
            ? compactGraphImage(
                history,
                width: settings.temperatureGraphWidth,
                height: settings.temperatureGraphHeight,
                low: settings.temperatureGraphLowColor,
                mid: settings.temperatureGraphMidColor,
                high: settings.temperatureGraphHighColor
            )
            : nil
        return compactStatusImage(
            label: settings.showsTemperatureLabelInMenuBar ? "TMP" : nil,
            value: value,
            unit: settings.showsTemperatureUnitInMenuBar ? "°C" : nil,
            graph: graph,
            labelFontSize: settings.temperatureLabelFontSize,
            valueFontSize: settings.temperatureValueFontSize,
            unitFontSize: settings.temperatureUnitFontSize,
            labelValueSpacing: settings.temperatureLabelValueSpacing,
            graphValueSpacing: settings.temperatureGraphValueSpacing,
            valueUnitSpacing: settings.temperatureValueUnitSpacing,
            horizontalInset: settings.temperatureHorizontalInset
        )
    }

    private func fanStatusImage(rpm: Int?, history: [Double]) -> NSImage {
        let value = rpm.map(String.init) ?? "--"
        let graph = settings.showsFanGraphInMenuBar
            ? compactGraphImage(
                history,
                width: settings.fanGraphWidth,
                height: settings.fanGraphHeight,
                low: settings.fanGraphLowColor,
                mid: settings.fanGraphMidColor,
                high: settings.fanGraphHighColor
            )
            : nil
        return compactStatusImage(
            label: settings.showsFanLabelInMenuBar ? "FAN" : nil,
            value: value,
            unit: settings.showsFanUnitInMenuBar ? "RPM" : nil,
            graph: graph,
            labelFontSize: settings.fanLabelFontSize,
            valueFontSize: settings.fanValueFontSize,
            unitFontSize: settings.fanUnitFontSize,
            labelValueSpacing: settings.fanLabelValueSpacing,
            graphValueSpacing: settings.fanGraphValueSpacing,
            valueUnitSpacing: settings.fanValueUnitSpacing,
            horizontalInset: settings.fanHorizontalInset
        )
    }

    private func compactStatusImage(
        label: String?,
        value: String,
        unit: String?,
        graph: NSImage?,
        labelFontSize: Double,
        valueFontSize: Double,
        unitFontSize: Double,
        labelValueSpacing: Double,
        graphValueSpacing: Double,
        valueUnitSpacing: Double,
        horizontalInset: Double
    ) -> NSImage {
        let height = menuBarImageHeight
        let labelSize = label.map { _ in verticalLabelSize(fontSize: labelFontSize.clamped(to: 6...14)) } ?? .zero
        let valueAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: CGFloat(valueFontSize.clamped(to: 8...20)), weight: .semibold),
            .foregroundColor: menuBarTextColor
        ]
        let unitAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: CGFloat(unitFontSize.clamped(to: 6...14)), weight: .medium),
            .foregroundColor: menuBarTextColor.withAlphaComponent(0.72)
        ]
        let horizontalInset = CGFloat(horizontalInset.clamped(to: 0...16))
        let labelValueSpacing = CGFloat(labelValueSpacing.clamped(to: 0...16))
        let valueUnitSpacing = CGFloat(valueUnitSpacing.clamped(to: 0...12))
        let valueWidth = value.size(withAttributes: valueAttributes).width
        let valueHeight = value.size(withAttributes: valueAttributes).height
        let unitWidth = unit?.size(withAttributes: unitAttributes).width ?? 0
        let unitHeight = unit?.size(withAttributes: unitAttributes).height ?? 0
        let unitGap = unit == nil ? 0 : valueUnitSpacing
        let labelSpacing = label == nil ? 0 : labelValueSpacing
        let graphSpacing = graph == nil ? 0 : CGFloat(graphValueSpacing.clamped(to: 0...16))
        let valueBlockWidth = valueWidth + unitGap + unitWidth
        let valueBlockHeight = max(valueHeight, unitHeight)
        let width = ceil(horizontalInset * 2 + labelSize.width + labelSpacing + (graph?.size.width ?? 0) + graphSpacing + valueBlockWidth)
        let image = NSImage(size: NSSize(width: width, height: height))
        var x = horizontalInset

        image.lockFocus()
        NSGraphicsContext.current?.shouldAntialias = true
        if let label {
            verticalLabelImage(label, fontSize: labelFontSize).draw(
                in: NSRect(x: x, y: centeredY(height: labelSize.height, in: height, offset: 0), width: labelSize.width, height: labelSize.height)
            )
            x += labelSize.width + labelValueSpacing
        }

        if let graph {
            graph.draw(
                in: NSRect(
                    x: x,
                    y: centeredY(height: graph.size.height, in: height, offset: 0),
                    width: graph.size.width,
                    height: graph.size.height
                )
            )
            x += graph.size.width + graphSpacing
        }

        let valueBaseY = centeredY(height: valueBlockHeight, in: height, offset: 0)
        let valueX = x
        let valueY = valueBaseY + (valueBlockHeight - valueHeight) / 2
        value.draw(in: NSRect(x: valueX, y: valueY, width: valueWidth + 1, height: valueHeight), withAttributes: valueAttributes)

        if let unit {
            let unitX = valueX + valueWidth + unitGap
            let unitY = valueY
            unit.draw(in: NSRect(x: unitX, y: unitY, width: unitWidth + 1, height: unitHeight), withAttributes: unitAttributes)
        }
        image.unlockFocus()
        image.isTemplate = false

        return image
    }

    private func compactGraphImage(
        _ history: [Double],
        width: Double,
        height: Double,
        low: GraphColor,
        mid: GraphColor,
        high: GraphColor
    ) -> NSImage {
        let size = NSSize(
            width: CGFloat(width.clamped(to: 8...40)),
            height: visualHeight(height.clamped(to: 4...18))
        )
        let image = NSImage(size: size)
        let values = Array(history.suffix(max(2, Int(size.width.rounded()))))
        let samples = values.isEmpty ? [0] : values
        let rect = NSRect(x: 0.5, y: 0.5, width: size.width - 1, height: max(1, size.height - 1))
        let plotRect = rect.insetBy(dx: 0.5, dy: 1)
        let points = samples.enumerated().map { index, value in
            let divisor = CGFloat(max(samples.count - 1, 1))
            return NSPoint(
                x: plotRect.minX + (CGFloat(index) / divisor) * plotRect.width,
                y: plotRect.minY + CGFloat(value.clampedUnit) * plotRect.height
            )
        }

        image.lockFocus()
        NSGraphicsContext.current?.shouldAntialias = true

        let baseline = NSBezierPath()
        baseline.move(to: NSPoint(x: rect.minX, y: rect.minY))
        baseline.line(to: NSPoint(x: rect.maxX, y: rect.minY))
        baseline.lineWidth = 0.5
        menuBarTextColor.withAlphaComponent(0.18).setStroke()
        baseline.stroke()

        if points.count > 1, let firstPoint = points.first, let lastPoint = points.last {
            let fillPath = NSBezierPath()
            fillPath.move(to: NSPoint(x: firstPoint.x, y: plotRect.minY))
            points.forEach { fillPath.line(to: $0) }
            fillPath.line(to: NSPoint(x: lastPoint.x, y: plotRect.minY))
            fillPath.close()

            usageColor(samples.last ?? 0, low: low, mid: mid, high: high)
                .withAlphaComponent(0.24)
                .setFill()
            fillPath.fill()
        }

        for index in 1..<points.count {
            let segment = NSBezierPath()
            segment.move(to: points[index - 1])
            segment.line(to: points[index])
            segment.lineWidth = 1
            segment.lineCapStyle = .round
            segment.lineJoinStyle = .round
            usageColor((samples[index - 1] + samples[index]) / 2, low: low, mid: mid, high: high).setStroke()
            segment.stroke()
        }

        let border = NSBezierPath(roundedRect: rect, xRadius: 2, yRadius: 2)
        menuBarBorderColor.setStroke()
        border.lineWidth = 0.5
        border.stroke()

        image.unlockFocus()
        image.isTemplate = false

        return image
    }

    private func horizontalInset(_ value: Double) -> CGFloat {
        CGFloat(value.clamped(to: 0...24))
    }

    private func spacing(_ value: Double) -> CGFloat {
        CGFloat(value.clamped(to: 0...24))
    }

    private func visualHeight(_ value: Double) -> CGFloat {
        min(max(4, CGFloat(value)), metricVisualHeight)
    }

    private var menuBarImageHeight: CGFloat {
        max(20, floor(NSStatusBar.system.thickness))
    }

    private var metricVisualHeight: CGFloat {
        max(14, menuBarImageHeight - 1)
    }

    private func centeredY(height: CGFloat, in containerHeight: CGFloat, offset: CGFloat) -> CGFloat {
        let y = ((containerHeight - height) / 2) + offset
        return min(max(0, y), max(0, containerHeight - height))
    }

    private func drawMenuBarText(
        _ text: String,
        attributes: [NSAttributedString.Key: Any],
        x: CGFloat,
        height: CGFloat,
        offset: CGFloat
    ) {
        let size = text.size(withAttributes: attributes)
        let y = centeredY(height: size.height, in: height, offset: offset)
        text.draw(in: NSRect(x: x, y: y, width: size.width + 2, height: size.height), withAttributes: attributes)
    }

    private func drawPercentText(
        _ value: Double,
        valueAttributes: [NSAttributedString.Key: Any],
        unitAttributes: [NSAttributedString.Key: Any],
        x: CGFloat,
        height: CGFloat,
        offset: CGFloat,
        showsSymbol: Bool,
        spacing: Double
    ) {
        let number = percentNumberText(value)
        let numberSize = number.size(withAttributes: valueAttributes)
        let unitSize = "%".size(withAttributes: unitAttributes)
        let blockHeight = max(numberSize.height, showsSymbol ? unitSize.height : 0)
        let y = centeredY(height: blockHeight, in: height, offset: offset)
        let numberY = y + (blockHeight - numberSize.height) / 2

        number.draw(
            in: NSRect(x: x, y: numberY, width: numberSize.width + 2, height: numberSize.height),
            withAttributes: valueAttributes
        )
        guard showsSymbol else { return }
        let percentX = x + numberSize.width + CGFloat(spacing.clamped(to: 0...8))
        "%".draw(
            in: NSRect(x: percentX, y: numberY, width: unitSize.width + 2, height: unitSize.height),
            withAttributes: unitAttributes
        )
    }

    private func percentTextWidth(
        _ value: Double,
        valueAttributes: [NSAttributedString.Key: Any],
        unitAttributes: [NSAttributedString.Key: Any],
        showsSymbol: Bool,
        spacing: Double
    ) -> CGFloat {
        let numberWidth = percentNumberText(value).size(withAttributes: valueAttributes).width
        guard showsSymbol else { return numberWidth }
        return numberWidth
            + CGFloat(spacing.clamped(to: 0...8))
            + "%".size(withAttributes: unitAttributes).width
    }

    private func percentNumberText(_ value: Double) -> String {
        let percent = Int((value.clampedUnit * 100).rounded())
        let digits = settings.usesTwoDigitPercent ? 2 : 1
        return String(format: "%0\(digits)d", percent)
    }

    private func verticalLabelSize(fontSize: Double) -> NSSize {
        let fontSize = CGFloat(fontSize.clamped(to: 6.4...12))
        return NSSize(width: max(12, ceil(fontSize * 1.85)), height: min(menuBarImageHeight, max(20, ceil(fontSize * 2.35))))
    }

    private func cpuGraphImage(_ history: [Double], size: NSSize) -> NSImage {
        let image = NSImage(size: size)
        let duration = Int(settings.cpuGraphDisplaySeconds.clamped(to: 10...40).rounded())
        let samples = Array(history.suffix(duration))
        let values = samples.isEmpty ? [0] : samples

        image.lockFocus()
        NSGraphicsContext.current?.shouldAntialias = true

        let graphRect = NSRect(
            x: 0.5,
            y: 0.5,
            width: size.width - 1,
            height: max(1, size.height - 1)
        )
        let guide = NSBezierPath()
        guide.move(to: NSPoint(x: graphRect.minX, y: graphRect.midY))
        guide.line(to: NSPoint(x: graphRect.maxX, y: graphRect.midY))
        guide.lineWidth = 0.5
        menuBarTextColor.withAlphaComponent(0.12).setStroke()
        guide.stroke()

        let border = NSBezierPath(roundedRect: graphRect, xRadius: 3, yRadius: 3)
        menuBarBorderColor.setStroke()
        border.lineWidth = 0.7

        let plotRect = graphRect.insetBy(dx: 1.5, dy: 1)
        let points = values.enumerated().map { index, value in
            let divisor = CGFloat(max(values.count - 1, 1))
            let x = plotRect.minX + (CGFloat(index) / divisor) * plotRect.width
            let y = plotRect.minY + CGFloat(value.clampedUnit) * plotRect.height
            return NSPoint(x: x, y: y)
        }

        if points.count > 1, let firstPoint = points.first, let lastPoint = points.last {
            let fillPath = NSBezierPath()
            fillPath.move(to: NSPoint(x: firstPoint.x, y: plotRect.minY))
            points.forEach { fillPath.line(to: $0) }
            fillPath.line(to: NSPoint(x: lastPoint.x, y: plotRect.minY))
            fillPath.close()

            NSGraphicsContext.saveGraphicsState()
            border.addClip()
            fillPath.addClip()
            let fillColor = usageColor(
                values.last ?? 0,
                low: settings.cpuGraphLowColor,
                mid: settings.cpuGraphMidColor,
                high: settings.cpuGraphHighColor
            )
            let lowColor = usageColor(
                0,
                low: settings.cpuGraphLowColor,
                mid: settings.cpuGraphMidColor,
                high: settings.cpuGraphHighColor
            )
            NSGradient(colors: [
                fillColor.withAlphaComponent(0.68),
                lowColor.withAlphaComponent(0.28)
            ])?.draw(in: graphRect, angle: 90)
            NSGraphicsContext.restoreGraphicsState()
        }

        for index in 1..<points.count {
            let segment = NSBezierPath()
            segment.move(to: points[index - 1])
            segment.line(to: points[index])
            segment.lineWidth = 1.15
            segment.lineCapStyle = .round
            segment.lineJoinStyle = .round
            usageColor(
                (values[index - 1] + values[index]) / 2,
                low: settings.cpuGraphLowColor,
                mid: settings.cpuGraphMidColor,
                high: settings.cpuGraphHighColor
            ).setStroke()
            segment.stroke()
        }

        menuBarBorderColor.setStroke()
        border.stroke()

        image.unlockFocus()
        image.isTemplate = false

        return image
    }

    private func verticalLabelImage(_ text: String, fontSize: Double) -> NSImage {
        let size = verticalLabelSize(fontSize: fontSize)
        let image = NSImage(size: size)
        let font = NSFont.monospacedSystemFont(
            ofSize: CGFloat(fontSize.clamped(to: 6.4...12)),
            weight: .bold
        )
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: menuBarTextColor,
            .paragraphStyle: paragraph
        ]
        let letters = Array(text)
        let step = size.height / CGFloat(max(letters.count, 1))

        image.lockFocus()
        for (index, letter) in letters.enumerated() {
            let y = size.height - (CGFloat(index) + 1) * step - 0.5
            String(letter).draw(in: NSRect(x: 0, y: y, width: size.width, height: step + 1), withAttributes: attributes)
        }
        image.unlockFocus()
        image.isTemplate = false

        return image
    }

    private func networkImage(network: NetworkMetric) -> NSImage {
        func rateParts(_ text: String) -> (number: String, unit: String) {
            let parts = text.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
            guard parts.count == 2 else { return (text, "") }
            return (String(parts[0]), String(parts[1]))
        }

        func rateWidth(_ parts: (number: String, unit: String), attributes: [NSAttributedString.Key: Any], unitSpacing: CGFloat, showsUnit: Bool) -> CGFloat {
            let numberWidth = parts.number.size(withAttributes: attributes).width
            guard showsUnit, !parts.unit.isEmpty else { return numberWidth }
            return numberWidth + unitSpacing + parts.unit.size(withAttributes: attributes).width
        }

        func drawRate(
            _ parts: (number: String, unit: String),
            x: CGFloat,
            y: CGFloat,
            width: CGFloat,
            attributes: [NSAttributedString.Key: Any],
            unitSpacing: CGFloat,
            showsUnit: Bool
        ) {
            let numberWidth = parts.number.size(withAttributes: attributes).width
            parts.number.draw(in: NSRect(x: x, y: y, width: numberWidth + 1, height: 10), withAttributes: attributes)

            guard showsUnit, !parts.unit.isEmpty else { return }
            parts.unit.draw(
                in: NSRect(x: x + numberWidth + unitSpacing, y: y, width: width - numberWidth - unitSpacing, height: 10),
                withAttributes: attributes
            )
        }

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .left
        let showsLabel = settings.showsNetworkLabelInMenuBar
        let labelFontSize = CGFloat(settings.networkLabelFontSize.clamped(to: 6.4...12))
        let valueFontSize = CGFloat(settings.networkValueFontSize.clamped(to: 8...12))
        let labelAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(
                ofSize: labelFontSize,
                weight: .bold
            ),
            .foregroundColor: menuBarTextColor,
            .paragraphStyle: paragraph
        ]
        let valueAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(
                ofSize: valueFontSize,
                weight: .semibold
            ),
            .foregroundColor: menuBarTextColor,
            .paragraphStyle: paragraph
        ]
        let labelWidth = showsLabel ? max(8, ceil(labelFontSize * 1.2)) : 0
        let showsGraph = settings.showsNetworkGraphInMenuBar
        let graphWidth = showsGraph ? CGFloat(settings.networkGraphWidth.clamped(to: 8...40)) : 0
        let graphHeight = showsGraph ? min(9, CGFloat(settings.networkGraphHeight.clamped(to: 4...10))) : 0
        let graphX = labelWidth + (showsLabel ? spacing(settings.networkLabelValueSpacing) : 0)
        let valueX = graphX + graphWidth + (showsGraph ? spacing(settings.networkGraphValueSpacing) : 0)
        let unitSpacing = CGFloat(settings.networkUnitSpacing.clamped(to: 0...8))
        let showsUnit = settings.showsNetworkUnitInMenuBar
        let uploadParts = rateParts(network.uploadCompactText)
        let downloadParts = rateParts(network.downloadCompactText)
        let valueWidth = max(
            rateWidth(uploadParts, attributes: valueAttributes, unitSpacing: unitSpacing, showsUnit: showsUnit),
            rateWidth(downloadParts, attributes: valueAttributes, unitSpacing: unitSpacing, showsUnit: showsUnit)
        )
        let size = NSSize(width: ceil(valueX + valueWidth + 1), height: 20)
        let image = NSImage(size: size)

        image.lockFocus()
        if showsLabel {
            "↑".draw(in: NSRect(x: 0, y: 10, width: labelWidth, height: 10), withAttributes: labelAttributes)
        }
        if showsGraph {
            compactGraphImage(
                network.uploadHistory,
                width: Double(graphWidth),
                height: Double(graphHeight),
                low: settings.networkGraphLowColor,
                mid: settings.networkGraphMidColor,
                high: settings.networkGraphHighColor
            )
            .draw(in: NSRect(x: graphX, y: 10 + (10 - graphHeight) / 2, width: graphWidth, height: graphHeight))
        }
        drawRate(uploadParts, x: valueX, y: 10, width: size.width - valueX, attributes: valueAttributes, unitSpacing: unitSpacing, showsUnit: showsUnit)
        if showsLabel {
            "↓".draw(in: NSRect(x: 0, y: 0, width: labelWidth, height: 10), withAttributes: labelAttributes)
        }
        if showsGraph {
            compactGraphImage(
                network.downloadHistory,
                width: Double(graphWidth),
                height: Double(graphHeight),
                low: settings.networkGraphLowColor,
                mid: settings.networkGraphMidColor,
                high: settings.networkGraphHighColor
            )
            .draw(in: NSRect(x: graphX, y: (10 - graphHeight) / 2, width: graphWidth, height: graphHeight))
        }
        drawRate(downloadParts, x: valueX, y: 0, width: size.width - valueX, attributes: valueAttributes, unitSpacing: unitSpacing, showsUnit: showsUnit)
        image.unlockFocus()
        image.isTemplate = false

        return image
    }

    private func memoryGaugeImage(_ usage: Double, size: NSSize) -> NSImage {
        let image = NSImage(size: size)

        image.lockFocus()

        let outerRect = NSRect(x: 1, y: 0.5, width: max(2, size.width - 2), height: size.height - 1)
        let cornerRadius = min(2, outerRect.width / 2)
        let background = NSBezierPath(roundedRect: outerRect, xRadius: cornerRadius, yRadius: cornerRadius)

        let fillHeight = max(1, outerRect.height * usage.clampedUnit)
        let fillRect = NSRect(x: outerRect.minX, y: outerRect.minY, width: outerRect.width, height: fillHeight)
        let fill = NSBezierPath(roundedRect: fillRect, xRadius: cornerRadius, yRadius: cornerRadius)
        let gradient = NSGradient(colors: [
            usageColor(
                max(0, usage - 0.35),
                low: settings.memoryGraphLowColor,
                mid: settings.memoryGraphMidColor,
                high: settings.memoryGraphHighColor
            )
                .withAlphaComponent(0.88),
            usageColor(
                usage,
                low: settings.memoryGraphLowColor,
                mid: settings.memoryGraphMidColor,
                high: settings.memoryGraphHighColor
            )
        ])
        gradient?.draw(in: fill, angle: 90)

        menuBarBorderColor.setStroke()
        background.lineWidth = 0.7
        background.stroke()

        image.unlockFocus()
        image.isTemplate = false

        return image
    }

    private func boundedVerticalInsets(_ insets: MetricInsets, maxTotal: CGFloat) -> (top: CGFloat, bottom: CGFloat) {
        var top = CGFloat(max(0, insets.top))
        var bottom = CGFloat(max(0, insets.bottom))
        let total = top + bottom

        if total > maxTotal, total > 0 {
            let scale = maxTotal / total
            top *= scale
            bottom *= scale
        }

        return (top, bottom)
    }

    private var menuBarBorderColor: NSColor {
        settings.menuBarBorderColor.nsColor
    }

    private func usageColor(_ usage: Double, low: GraphColor, mid: GraphColor, high: GraphColor) -> NSColor {
        guard settings.usesUsageGradient else {
            return low.nsColor.usingColorSpace(.sRGB) ?? low.nsColor
        }

        return settings.usageColor(low: low, mid: mid, high: high, intensity: usage).nsColor
    }

    private func blendColor(
        from start: (red: CGFloat, green: CGFloat, blue: CGFloat),
        to end: (red: CGFloat, green: CGFloat, blue: CGFloat),
        amount: Double
    ) -> NSColor {
        let amount = CGFloat(amount.clampedUnit)

        return NSColor(
            srgbRed: start.red + (end.red - start.red) * amount,
            green: start.green + (end.green - start.green) * amount,
            blue: start.blue + (end.blue - start.blue) * amount,
            alpha: 1
        )
    }

    @objc private func togglePopover(_ sender: NSStatusBarButton) {
        if NSApp.currentEvent?.type == .rightMouseUp {
            SettingsWindowController.shared.show(settings: settings)
            return
        }

        if popoverPinState.isPinned {
            showPinnedPanel()
            return
        }

        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
        }
    }

    @objc private func toggleAppearanceMode(_ sender: NSStatusBarButton) {
        if !toggleSystemAppearance() {
            settings.usesDarkAppearance.toggle()
        }
    }

    private func toggleSystemAppearance() -> Bool {
        let source = """
        tell application "System Events"
            tell appearance preferences
                set dark mode to not dark mode
                return dark mode
            end tell
        end tell
        """
        var error: NSDictionary?
        guard let result = NSAppleScript(source: source)?.executeAndReturnError(&error), error == nil else {
            if let error {
                NSLog("PulseBar appearance toggle failed: \(error)")
            }
            return false
        }

        settings.usesDarkAppearance = result.booleanValue
        return true
    }
}

extension StatusBarController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
              window === pinnedPanel
        else { return }

        pinnedPanel = nil
        popoverPinState.setPinned(false)
    }
}

@MainActor
final class SettingsWindowController: NSObject {
    static let shared = SettingsWindowController()

    private var window: NSWindow?
    private var settings: SettingsStore?

    func show(settings: SettingsStore) {
        self.settings = settings

        if window == nil {
            let hostingController = NSHostingController(
                rootView: SettingsWindowView()
                    .environmentObject(settings)
            )

            let window = NSWindow(contentViewController: hostingController)
            window.title = "PulseBar Settings"
            window.styleMask = [.titled, .closable, .resizable]
            window.titleVisibility = .visible
            window.isReleasedWhenClosed = false
            window.minSize = SettingsStore.minimumSettingsWindowSize
            window.setContentSize(settings.settingsWindowContentSize())
            window.delegate = self
            window.center()
            self.window = window
        }

        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

extension SettingsWindowController: NSWindowDelegate {
    func windowDidResize(_ notification: Notification) {
        saveWindowSize(from: notification)
    }

    func windowWillClose(_ notification: Notification) {
        saveWindowSize(from: notification)
    }

    private func saveWindowSize(from notification: Notification) {
        guard let window = notification.object as? NSWindow,
              window === self.window
        else { return }

        settings?.saveSettingsWindowContentSize(window.contentRect(forFrameRect: window.frame).size)
    }
}
