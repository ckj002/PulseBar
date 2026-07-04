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
        isPinned.toggle()
        onChange?(isPinned)
    }
}

@MainActor
final class StatusBarController: NSObject {
    private let monitor: SystemMonitorService
    private let settings: SettingsStore
    private let cpuItem = NSStatusBar.system.statusItem(withLength: 80)
    private let memoryItem = NSStatusBar.system.statusItem(withLength: 58)
    private let networkItem = NSStatusBar.system.statusItem(withLength: 72)
    private let popover = NSPopover()
    private let popoverPinState = PopoverPinState()
    private var cancellables = Set<AnyCancellable>()
    private let menuBarTextColor = NSColor(calibratedWhite: 0.08, alpha: 0.88)

    init(monitor: SystemMonitorService, settings: SettingsStore) {
        self.monitor = monitor
        self.settings = settings
        super.init()

        popoverPinState.onChange = { [weak self] isPinned in
            self?.popover.behavior = isPinned ? .applicationDefined : .transient
        }

        configureStatusItems()
        configurePopover()
        applyStatusItemLengths()
        updateStatusItems(with: monitor.snapshot)

        monitor.$snapshot.sink { [weak self] snapshot in
            self?.updateStatusItems(with: snapshot)
        }
        .store(in: &cancellables)

        settings.didChange.sink { [weak self] in
            self?.applyStatusItemLengths()
            guard let snapshot = self?.monitor.snapshot else { return }
            self?.updateStatusItems(with: snapshot)
        }
        .store(in: &cancellables)
    }

    private func configureStatusItems() {
        cpuItem.autosaveName = NSStatusItem.AutosaveName("dev.local.SystemPulse.cpu")
        memoryItem.autosaveName = NSStatusItem.AutosaveName("dev.local.SystemPulse.memory")
        networkItem.autosaveName = NSStatusItem.AutosaveName("dev.local.SystemPulse.network")

        [cpuItem, memoryItem, networkItem].forEach { item in
            item.button?.target = self
            item.button?.action = #selector(togglePopover(_:))
            item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        [cpuItem, memoryItem, networkItem].forEach { item in
            item.button?.imagePosition = .imageOnly
            item.button?.imageScaling = .scaleNone
        }

        cpuItem.button?.toolTip = "CPU"
        memoryItem.button?.toolTip = "Memory"
        networkItem.button?.toolTip = "Network"
    }

    private func configurePopover() {
        popover.behavior = popoverPinState.isPinned ? .applicationDefined : .transient
        popover.contentSize = NSSize(width: 370, height: 430)
        popover.contentViewController = NSHostingController(
            rootView: MonitorPanelView()
                .environmentObject(monitor)
                .environmentObject(settings)
                .environmentObject(popoverPinState)
        )
    }

    private func updateStatusItems(with snapshot: SystemSnapshot) {
        setStatusImage(
            cpuStatusImage(history: snapshot.cpu.history, usage: snapshot.cpu.usage),
            on: cpuItem
        )
        setStatusImage(
            memoryStatusImage(usage: snapshot.memory.usage),
            on: memoryItem
        )
        setStatusImage(
            networkStatusImage(
                download: snapshot.network.downloadCompactText,
                upload: snapshot.network.uploadCompactText
            ),
            on: networkItem
        )
    }

    private func applyStatusItemLengths() {
        cpuItem.length = 24
        memoryItem.length = 24
        networkItem.length = 24
    }

    private func setStatusImage(_ image: NSImage, on item: NSStatusItem) {
        item.button?.attributedTitle = NSAttributedString(string: "")
        item.button?.title = ""
        item.button?.image = image
        item.length = image.size.width
    }

    private func cpuStatusImage(history: [Double], usage: Double) -> NSImage {
        let height = menuBarImageHeight
        let labelFontSize = settings.cpuLabelFontSize.clamped(to: 6.4...12)
        let labelSize = verticalLabelSize(fontSize: labelFontSize)
        let valueFont = NSFont.monospacedSystemFont(
            ofSize: CGFloat(settings.cpuValueFontSize.clamped(to: 10...20)),
            weight: .medium
        )
        let attributes: [NSAttributedString.Key: Any] = [
            .font: valueFont,
            .foregroundColor: menuBarTextColor
        ]
        let horizontalInset = horizontalInset(settings.cpuHorizontalInset)
        let labelGraphSpacing = spacing(settings.cpuLabelVisualSpacing)
        let graphValueSpacing = spacing(settings.cpuVisualValueSpacing)
        let graphSeconds = CGFloat(settings.cpuGraphDisplaySeconds.clamped(to: 10...40).rounded())
        let graphSize = NSSize(width: graphSeconds, height: visualHeight(settings.cpuVisualHeight))
        let percentWidth = percentTextWidth(usage, attributes: attributes)
        let contentWidth = labelSize.width + labelGraphSpacing + graphSize.width + graphValueSpacing + percentWidth
        let width = contentWidth + horizontalInset * 2
        let image = NSImage(size: NSSize(width: width, height: height))
        var x = horizontalInset

        image.lockFocus()
        NSGraphicsContext.current?.shouldAntialias = true
        verticalLabelImage("CPU", fontSize: labelFontSize).draw(
            in: NSRect(x: x, y: centeredY(height: labelSize.height, in: height, offset: 0), width: labelSize.width, height: labelSize.height)
        )
        x += labelSize.width + labelGraphSpacing

        cpuGraphImage(history, size: graphSize).draw(
            in: NSRect(x: x, y: centeredY(height: graphSize.height, in: height, offset: 0), width: graphSize.width, height: graphSize.height)
        )
        x += graphSize.width + graphValueSpacing

        drawPercentText(usage, attributes: attributes, x: x, height: height, offset: 0)
        image.unlockFocus()
        image.isTemplate = false

        return image
    }

    private func memoryStatusImage(usage: Double) -> NSImage {
        let height = menuBarImageHeight
        let labelFontSize = settings.memoryLabelFontSize.clamped(to: 6.4...12)
        let labelSize = verticalLabelSize(fontSize: labelFontSize)
        let valueFont = NSFont.monospacedSystemFont(
            ofSize: CGFloat(settings.memoryValueFontSize.clamped(to: 10...20)),
            weight: .medium
        )
        let attributes: [NSAttributedString.Key: Any] = [
            .font: valueFont,
            .foregroundColor: menuBarTextColor
        ]
        let horizontalInset = horizontalInset(settings.memoryHorizontalInset)
        let labelGaugeSpacing = spacing(settings.memoryLabelVisualSpacing)
        let gaugeValueSpacing = spacing(settings.memoryVisualValueSpacing)
        let gaugeSize = NSSize(width: 8, height: visualHeight(settings.memoryVisualHeight))
        let percentWidth = percentTextWidth(usage, attributes: attributes)
        let contentWidth = labelSize.width + labelGaugeSpacing + gaugeSize.width + gaugeValueSpacing + percentWidth
        let width = contentWidth + horizontalInset * 2
        let image = NSImage(size: NSSize(width: width, height: height))
        var x = horizontalInset

        image.lockFocus()
        NSGraphicsContext.current?.shouldAntialias = true
        verticalLabelImage("MEM", fontSize: labelFontSize).draw(
            in: NSRect(x: x, y: centeredY(height: labelSize.height, in: height, offset: 0), width: labelSize.width, height: labelSize.height)
        )
        x += labelSize.width + labelGaugeSpacing

        memoryGaugeImage(usage, size: gaugeSize).draw(
            in: NSRect(x: x, y: centeredY(height: gaugeSize.height, in: height, offset: 0), width: gaugeSize.width, height: gaugeSize.height)
        )
        x += gaugeSize.width + gaugeValueSpacing

        drawPercentText(usage, attributes: attributes, x: x, height: height, offset: 0)
        image.unlockFocus()
        image.isTemplate = false

        return image
    }

    private func networkStatusImage(download: String, upload: String) -> NSImage {
        let content = networkImage(download: download, upload: upload)
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
        attributes: [NSAttributedString.Key: Any],
        x: CGFloat,
        height: CGFloat,
        offset: CGFloat
    ) {
        let number = percentNumberText(value)
        let spacing = CGFloat(settings.percentSymbolSpacing.clamped(to: 0...8))
        drawMenuBarText(number, attributes: attributes, x: x, height: height, offset: offset)
        let percentX = x + number.size(withAttributes: attributes).width + spacing
        drawMenuBarText("%", attributes: attributes, x: percentX, height: height, offset: offset)
    }

    private func percentTextWidth(_ value: Double, attributes: [NSAttributedString.Key: Any]) -> CGFloat {
        percentNumberText(value).size(withAttributes: attributes).width
            + CGFloat(settings.percentSymbolSpacing.clamped(to: 0...8))
            + "%".size(withAttributes: attributes).width
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

    private func networkImage(download: String, upload: String) -> NSImage {
        func rateParts(_ text: String) -> (number: String, unit: String) {
            let parts = text.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
            guard parts.count == 2 else { return (text, "") }
            return (String(parts[0]), String(parts[1]))
        }

        func rateWidth(_ parts: (number: String, unit: String), attributes: [NSAttributedString.Key: Any], unitSpacing: CGFloat) -> CGFloat {
            let numberWidth = parts.number.size(withAttributes: attributes).width
            guard !parts.unit.isEmpty else { return numberWidth }
            return numberWidth + unitSpacing + parts.unit.size(withAttributes: attributes).width
        }

        func drawRate(
            _ parts: (number: String, unit: String),
            x: CGFloat,
            y: CGFloat,
            width: CGFloat,
            attributes: [NSAttributedString.Key: Any],
            unitSpacing: CGFloat
        ) {
            let numberWidth = parts.number.size(withAttributes: attributes).width
            parts.number.draw(in: NSRect(x: x, y: y, width: numberWidth + 1, height: 10), withAttributes: attributes)

            guard !parts.unit.isEmpty else { return }
            parts.unit.draw(
                in: NSRect(x: x + numberWidth + unitSpacing, y: y, width: width - numberWidth - unitSpacing, height: 10),
                withAttributes: attributes
            )
        }

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .left
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
        let labelWidth = max(8, ceil(labelFontSize * 1.2))
        let valueX = labelWidth + spacing(settings.networkLabelValueSpacing)
        let unitSpacing = CGFloat(settings.networkUnitSpacing.clamped(to: 0...8))
        let uploadParts = rateParts(upload)
        let downloadParts = rateParts(download)
        let valueWidth = max(
            rateWidth(uploadParts, attributes: valueAttributes, unitSpacing: unitSpacing),
            rateWidth(downloadParts, attributes: valueAttributes, unitSpacing: unitSpacing)
        )
        let size = NSSize(width: ceil(valueX + valueWidth + 1), height: 20)
        let image = NSImage(size: size)

        image.lockFocus()
        "U".draw(in: NSRect(x: 0, y: 10, width: labelWidth, height: 10), withAttributes: labelAttributes)
        drawRate(uploadParts, x: valueX, y: 10, width: size.width - valueX, attributes: valueAttributes, unitSpacing: unitSpacing)
        "D".draw(in: NSRect(x: 0, y: 0, width: labelWidth, height: 10), withAttributes: labelAttributes)
        drawRate(downloadParts, x: valueX, y: 0, width: size.width - valueX, attributes: valueAttributes, unitSpacing: unitSpacing)
        image.unlockFocus()
        image.isTemplate = false

        return image
    }

    private func memoryGaugeImage(_ usage: Double, size: NSSize) -> NSImage {
        let image = NSImage(size: size)

        image.lockFocus()

        let outerRect = NSRect(x: 1, y: 0.5, width: 6, height: size.height - 1)
        let background = NSBezierPath(roundedRect: outerRect, xRadius: 2, yRadius: 2)

        let fillHeight = max(1, outerRect.height * usage.clampedUnit)
        let fillRect = NSRect(x: outerRect.minX, y: outerRect.minY, width: outerRect.width, height: fillHeight)
        let fill = NSBezierPath(roundedRect: fillRect, xRadius: 2, yRadius: 2)
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
        settings.menuBarBorderColor.nsColor.withAlphaComponent(0.85)
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

        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
        }
    }
}

@MainActor
final class SettingsWindowController: NSObject {
    static let shared = SettingsWindowController()

    private var window: NSWindow?

    func show(settings: SettingsStore) {
        if window == nil {
            let hostingController = NSHostingController(
                rootView: SettingsWindowView()
                    .environmentObject(settings)
            )
            let window = NSWindow(contentViewController: hostingController)
            window.title = "System Pulse Settings"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.setContentSize(NSSize(width: 420, height: 720))
            window.center()
            self.window = window
        }

        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
