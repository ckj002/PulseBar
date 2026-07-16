import AppKit
import Combine
import ServiceManagement
import SwiftUI

struct GraphColor: Codable, Equatable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double

    var color: Color {
        Color(red: red, green: green, blue: blue, opacity: alpha)
    }

    var nsColor: NSColor {
        NSColor(srgbRed: CGFloat(red), green: CGFloat(green), blue: CGFloat(blue), alpha: CGFloat(alpha))
    }

    init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red.clampedUnit
        self.green = green.clampedUnit
        self.blue = blue.clampedUnit
        self.alpha = alpha.clampedUnit
    }

    init(_ color: Color) {
        let nsColor = NSColor(color).usingColorSpace(.sRGB)
            ?? NSColor(color).usingColorSpace(.deviceRGB)
            ?? .controlAccentColor
        self.red = Double(nsColor.redComponent).clampedUnit
        self.green = Double(nsColor.greenComponent).clampedUnit
        self.blue = Double(nsColor.blueComponent).clampedUnit
        self.alpha = Double(nsColor.alphaComponent).clampedUnit
    }

    init(_ color: NSColor) {
        let nsColor = color.usingColorSpace(.sRGB)
            ?? color.usingColorSpace(.deviceRGB)
            ?? .controlAccentColor
        self.red = Double(nsColor.redComponent).clampedUnit
        self.green = Double(nsColor.greenComponent).clampedUnit
        self.blue = Double(nsColor.blueComponent).clampedUnit
        self.alpha = Double(nsColor.alphaComponent).clampedUnit
    }

    func blended(with other: GraphColor, amount: Double) -> GraphColor {
        let amount = amount.clampedUnit
        return GraphColor(
            red: red + (other.red - red) * amount,
            green: green + (other.green - green) * amount,
            blue: blue + (other.blue - blue) * amount,
            alpha: alpha + (other.alpha - alpha) * amount
        )
    }

    private enum CodingKeys: String, CodingKey {
        case red
        case green
        case blue
        case alpha
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        red = try container.decode(Double.self, forKey: .red).clampedUnit
        green = try container.decode(Double.self, forKey: .green).clampedUnit
        blue = try container.decode(Double.self, forKey: .blue).clampedUnit
        alpha = try container.decodeIfPresent(Double.self, forKey: .alpha)?.clampedUnit ?? 1
    }
}

enum LoginItemController {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func setEnabled(_ isEnabled: Bool) {
        let service = SMAppService.mainApp

        do {
            if isEnabled {
                if service.status != .enabled {
                    try service.register()
                }
            } else if service.status != .notRegistered {
                try service.unregister()
            }
        } catch {
            NSLog("SystemPulse login item update failed: \(error.localizedDescription)")
        }
    }
}

struct MetricInsets: Codable, Equatable {
    var top: Double
    var right: Double
    var bottom: Double
    var left: Double

    static let zero = MetricInsets(top: 0, right: 0, bottom: 0, left: 0)

    static func vertical(_ value: Double) -> MetricInsets {
        MetricInsets(top: value, right: 0, bottom: value, left: 0)
    }

    static func trailing(_ value: Double) -> MetricInsets {
        MetricInsets(top: 0, right: value, bottom: 0, left: 0)
    }

    var horizontal: Double {
        left + right
    }

    var verticalOffset: Double {
        (bottom - top) / 2
    }
}

enum StatusMetricKind {
    case cpu
    case memory
    case network
    case disk
}

enum MenuBarMetricKind: String, CaseIterable, Codable, Identifiable {
    case cpu
    case memory
    case disk
    case network
    case fan
    case temperature
    case appearance

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cpu: return "CPU"
        case .memory: return "Memory"
        case .disk: return "Disk"
        case .network: return "Network"
        case .fan: return "Fan RPM"
        case .temperature: return "CPU Temp"
        case .appearance: return "Theme"
        }
    }

    var icon: String {
        switch self {
        case .cpu: return "cpu"
        case .memory: return "memorychip"
        case .disk: return "internaldrive"
        case .network: return "network"
        case .fan: return "fan"
        case .temperature: return "thermometer.medium"
        case .appearance: return "circle.lefthalf.filled"
        }
    }

    var statusItemAutosaveName: String {
        "dev.local.SystemPulse.\(rawValue)"
    }
}

@MainActor
final class SettingsStore: ObservableObject {
    static let initialSettingsWindowContentSize = NSSize(width: 560, height: 660)
    static let minimumSettingsWindowSize = NSSize(width: 560, height: 430)

    @Published var cpuGraphLowColor: GraphColor {
        didSet {
            save(cpuGraphLowColor, key: Keys.cpuGraphLowColor)
            didChange.send()
        }
    }

    @Published var cpuGraphMidColor: GraphColor {
        didSet {
            save(cpuGraphMidColor, key: Keys.cpuGraphMidColor)
            didChange.send()
        }
    }

    @Published var cpuGraphHighColor: GraphColor {
        didSet {
            save(cpuGraphHighColor, key: Keys.cpuGraphHighColor)
            didChange.send()
        }
    }

    @Published var memoryGraphLowColor: GraphColor {
        didSet {
            save(memoryGraphLowColor, key: Keys.memoryGraphLowColor)
            didChange.send()
        }
    }

    @Published var memoryGraphMidColor: GraphColor {
        didSet {
            save(memoryGraphMidColor, key: Keys.memoryGraphMidColor)
            didChange.send()
        }
    }

    @Published var memoryGraphHighColor: GraphColor {
        didSet {
            save(memoryGraphHighColor, key: Keys.memoryGraphHighColor)
            didChange.send()
        }
    }

    @Published var networkGraphLowColor: GraphColor {
        didSet {
            save(networkGraphLowColor, key: Keys.networkGraphLowColor)
            didChange.send()
        }
    }

    @Published var networkGraphMidColor: GraphColor {
        didSet {
            save(networkGraphMidColor, key: Keys.networkGraphMidColor)
            didChange.send()
        }
    }

    @Published var networkGraphHighColor: GraphColor {
        didSet {
            save(networkGraphHighColor, key: Keys.networkGraphHighColor)
            didChange.send()
        }
    }

    @Published var temperatureGraphLowColor: GraphColor {
        didSet {
            save(temperatureGraphLowColor, key: Keys.temperatureGraphLowColor)
            didChange.send()
        }
    }

    @Published var temperatureGraphMidColor: GraphColor {
        didSet {
            save(temperatureGraphMidColor, key: Keys.temperatureGraphMidColor)
            didChange.send()
        }
    }

    @Published var temperatureGraphHighColor: GraphColor {
        didSet {
            save(temperatureGraphHighColor, key: Keys.temperatureGraphHighColor)
            didChange.send()
        }
    }

    @Published var fanGraphLowColor: GraphColor {
        didSet {
            save(fanGraphLowColor, key: Keys.fanGraphLowColor)
            didChange.send()
        }
    }

    @Published var fanGraphMidColor: GraphColor {
        didSet {
            save(fanGraphMidColor, key: Keys.fanGraphMidColor)
            didChange.send()
        }
    }

    @Published var fanGraphHighColor: GraphColor {
        didSet {
            save(fanGraphHighColor, key: Keys.fanGraphHighColor)
            didChange.send()
        }
    }

    @Published var usesUsageGradient: Bool {
        didSet {
            save(usesUsageGradient, key: Keys.usesUsageGradient)
            didChange.send()
        }
    }

    @Published var usesTwoDigitPercent: Bool {
        didSet {
            save(usesTwoDigitPercent, key: Keys.usesTwoDigitPercent)
            didChange.send()
        }
    }

    @Published var opensAtLogin: Bool {
        didSet {
            save(opensAtLogin, key: Keys.opensAtLogin)
            LoginItemController.setEnabled(opensAtLogin)
            didChange.send()
        }
    }

    @Published var usesDarkAppearance: Bool {
        didSet {
            save(usesDarkAppearance, key: Keys.usesDarkAppearance)
            didChange.send()
        }
    }

    @Published var showsCPUInMenuBar: Bool {
        didSet {
            save(showsCPUInMenuBar, key: Keys.showsCPUInMenuBar)
            didChange.send()
        }
    }

    @Published var showsMemoryInMenuBar: Bool {
        didSet {
            save(showsMemoryInMenuBar, key: Keys.showsMemoryInMenuBar)
            didChange.send()
        }
    }

    @Published var showsNetworkInMenuBar: Bool {
        didSet {
            save(showsNetworkInMenuBar, key: Keys.showsNetworkInMenuBar)
            didChange.send()
        }
    }

    @Published var showsDiskInMenuBar: Bool {
        didSet {
            save(showsDiskInMenuBar, key: Keys.showsDiskInMenuBar)
            didChange.send()
        }
    }

    @Published var showsCPULabelInMenuBar: Bool {
        didSet {
            save(showsCPULabelInMenuBar, key: Keys.showsCPULabelInMenuBar)
            didChange.send()
        }
    }

    @Published var showsMemoryLabelInMenuBar: Bool {
        didSet {
            save(showsMemoryLabelInMenuBar, key: Keys.showsMemoryLabelInMenuBar)
            didChange.send()
        }
    }

    @Published var showsNetworkLabelInMenuBar: Bool {
        didSet {
            save(showsNetworkLabelInMenuBar, key: Keys.showsNetworkLabelInMenuBar)
            didChange.send()
        }
    }

    @Published var showsDiskLabelInMenuBar: Bool {
        didSet {
            save(showsDiskLabelInMenuBar, key: Keys.showsDiskLabelInMenuBar)
            didChange.send()
        }
    }

    @Published var showsNetworkGraphInMenuBar: Bool {
        didSet {
            save(showsNetworkGraphInMenuBar, key: Keys.showsNetworkGraphInMenuBar)
            didChange.send()
        }
    }

    @Published var showsCPUGraphInMenuBar: Bool {
        didSet {
            save(showsCPUGraphInMenuBar, key: Keys.showsCPUGraphInMenuBar)
            didChange.send()
        }
    }

    @Published var showsMemoryGraphInMenuBar: Bool {
        didSet {
            save(showsMemoryGraphInMenuBar, key: Keys.showsMemoryGraphInMenuBar)
            didChange.send()
        }
    }

    @Published var showsCPUUnitInMenuBar: Bool {
        didSet {
            save(showsCPUUnitInMenuBar, key: Keys.showsCPUUnitInMenuBar)
            didChange.send()
        }
    }

    @Published var showsMemoryUnitInMenuBar: Bool {
        didSet {
            save(showsMemoryUnitInMenuBar, key: Keys.showsMemoryUnitInMenuBar)
            didChange.send()
        }
    }

    @Published var showsNetworkUnitInMenuBar: Bool {
        didSet {
            save(showsNetworkUnitInMenuBar, key: Keys.showsNetworkUnitInMenuBar)
            didChange.send()
        }
    }

    @Published var showsDiskUnitInMenuBar: Bool {
        didSet {
            save(showsDiskUnitInMenuBar, key: Keys.showsDiskUnitInMenuBar)
            didChange.send()
        }
    }

    @Published var showsDiskDecimalCapacity: Bool {
        didSet {
            save(showsDiskDecimalCapacity, key: Keys.showsDiskDecimalCapacity)
            didChange.send()
        }
    }

    @Published var showsTemperatureInMenuBar: Bool {
        didSet {
            save(showsTemperatureInMenuBar, key: Keys.showsTemperatureInMenuBar)
            didChange.send()
        }
    }

    @Published var showsFanInMenuBar: Bool {
        didSet {
            save(showsFanInMenuBar, key: Keys.showsFanInMenuBar)
            didChange.send()
        }
    }

    @Published var showsAppearanceToggleInMenuBar: Bool {
        didSet {
            save(showsAppearanceToggleInMenuBar, key: Keys.showsAppearanceToggleInMenuBar)
            didChange.send()
        }
    }

    @Published var showsTemperatureLabelInMenuBar: Bool {
        didSet {
            save(showsTemperatureLabelInMenuBar, key: Keys.showsTemperatureLabelInMenuBar)
            didChange.send()
        }
    }

    @Published var showsFanLabelInMenuBar: Bool {
        didSet {
            save(showsFanLabelInMenuBar, key: Keys.showsFanLabelInMenuBar)
            didChange.send()
        }
    }

    @Published var showsTemperatureGraphInMenuBar: Bool {
        didSet {
            save(showsTemperatureGraphInMenuBar, key: Keys.showsTemperatureGraphInMenuBar)
            didChange.send()
        }
    }

    @Published var showsFanGraphInMenuBar: Bool {
        didSet {
            save(showsFanGraphInMenuBar, key: Keys.showsFanGraphInMenuBar)
            didChange.send()
        }
    }

    @Published var showsTemperatureUnitInMenuBar: Bool {
        didSet {
            save(showsTemperatureUnitInMenuBar, key: Keys.showsTemperatureUnitInMenuBar)
            didChange.send()
        }
    }

    @Published var showsFanUnitInMenuBar: Bool {
        didSet {
            save(showsFanUnitInMenuBar, key: Keys.showsFanUnitInMenuBar)
            didChange.send()
        }
    }

    @Published var isMenuBarOrderModeEnabled: Bool {
        didSet {
            save(isMenuBarOrderModeEnabled, key: Keys.isMenuBarOrderModeEnabled)
            didChange.send()
        }
    }

    @Published var menuBarMetricOrder: [MenuBarMetricKind] {
        didSet {
            let normalizedOrder = Self.normalizedMenuBarMetricOrder(menuBarMetricOrder)
            if normalizedOrder != menuBarMetricOrder {
                menuBarMetricOrder = normalizedOrder
                return
            }
            save(menuBarMetricOrder, key: Keys.menuBarMetricOrder)
            saveStatusItemPreferredPositions(for: menuBarMetricOrder)
            didChange.send()
        }
    }

    @Published var showsCPUGraphInPopover: Bool {
        didSet {
            save(showsCPUGraphInPopover, key: Keys.showsCPUGraphInPopover)
            didChange.send()
        }
    }

    @Published var showsMemoryGraphInPopover: Bool {
        didSet {
            save(showsMemoryGraphInPopover, key: Keys.showsMemoryGraphInPopover)
            didChange.send()
        }
    }

    @Published var showsNetworkGraphInPopover: Bool {
        didSet {
            save(showsNetworkGraphInPopover, key: Keys.showsNetworkGraphInPopover)
            didChange.send()
        }
    }

    @Published var showsTemperatureGraphInPopover: Bool {
        didSet {
            save(showsTemperatureGraphInPopover, key: Keys.showsTemperatureGraphInPopover)
            didChange.send()
        }
    }

    @Published var showsFanGraphInPopover: Bool {
        didSet {
            save(showsFanGraphInPopover, key: Keys.showsFanGraphInPopover)
            didChange.send()
        }
    }

    @Published var temperatureLabelFontSize: Double {
        didSet {
            save(temperatureLabelFontSize, key: Keys.temperatureLabelFontSize)
            didChange.send()
        }
    }

    @Published var temperatureValueFontSize: Double {
        didSet {
            save(temperatureValueFontSize, key: Keys.temperatureValueFontSize)
            didChange.send()
        }
    }

    @Published var temperatureUnitFontSize: Double {
        didSet {
            save(temperatureUnitFontSize, key: Keys.temperatureUnitFontSize)
            didChange.send()
        }
    }

    @Published var temperatureLabelValueSpacing: Double {
        didSet {
            save(temperatureLabelValueSpacing, key: Keys.temperatureLabelValueSpacing)
            didChange.send()
        }
    }

    @Published var temperatureValueUnitSpacing: Double {
        didSet {
            save(temperatureValueUnitSpacing, key: Keys.temperatureValueUnitSpacing)
            didChange.send()
        }
    }

    @Published var temperatureHorizontalInset: Double {
        didSet {
            save(temperatureHorizontalInset, key: Keys.temperatureHorizontalInset)
            didChange.send()
        }
    }

    @Published var fanLabelFontSize: Double {
        didSet {
            save(fanLabelFontSize, key: Keys.fanLabelFontSize)
            didChange.send()
        }
    }

    @Published var fanValueFontSize: Double {
        didSet {
            save(fanValueFontSize, key: Keys.fanValueFontSize)
            didChange.send()
        }
    }

    @Published var fanUnitFontSize: Double {
        didSet {
            save(fanUnitFontSize, key: Keys.fanUnitFontSize)
            didChange.send()
        }
    }

    @Published var fanLabelValueSpacing: Double {
        didSet {
            save(fanLabelValueSpacing, key: Keys.fanLabelValueSpacing)
            didChange.send()
        }
    }

    @Published var fanValueUnitSpacing: Double {
        didSet {
            save(fanValueUnitSpacing, key: Keys.fanValueUnitSpacing)
            didChange.send()
        }
    }

    @Published var fanHorizontalInset: Double {
        didSet {
            save(fanHorizontalInset, key: Keys.fanHorizontalInset)
            didChange.send()
        }
    }

    @Published var percentSymbolSpacing: Double {
        didSet {
            save(percentSymbolSpacing, key: Keys.percentSymbolSpacing)
            didChange.send()
        }
    }

    @Published var menuBarValueFontSize: Double {
        didSet {
            save(menuBarValueFontSize, key: Keys.menuBarValueFontSize)
            didChange.send()
        }
    }

    @Published var cpuValueFontSize: Double {
        didSet {
            save(cpuValueFontSize, key: Keys.cpuValueFontSize)
            didChange.send()
        }
    }

    @Published var memoryValueFontSize: Double {
        didSet {
            save(memoryValueFontSize, key: Keys.memoryValueFontSize)
            didChange.send()
        }
    }

    @Published var cpuUnitFontSize: Double {
        didSet {
            save(cpuUnitFontSize, key: Keys.cpuUnitFontSize)
            didChange.send()
        }
    }

    @Published var memoryUnitFontSize: Double {
        didSet {
            save(memoryUnitFontSize, key: Keys.memoryUnitFontSize)
            didChange.send()
        }
    }

    @Published var networkValueFontSize: Double {
        didSet {
            save(networkValueFontSize, key: Keys.networkValueFontSize)
            didChange.send()
        }
    }

    @Published var networkUnitFontSize: Double {
        didSet {
            save(networkUnitFontSize, key: Keys.networkUnitFontSize)
            didChange.send()
        }
    }

    @Published var diskValueFontSize: Double {
        didSet {
            save(diskValueFontSize, key: Keys.diskValueFontSize)
            didChange.send()
        }
    }

    @Published var diskUnitFontSize: Double {
        didSet {
            save(diskUnitFontSize, key: Keys.diskUnitFontSize)
            didChange.send()
        }
    }

    @Published var menuBarLabelFontSize: Double {
        didSet {
            save(menuBarLabelFontSize, key: Keys.menuBarLabelFontSize)
            didChange.send()
        }
    }

    @Published var cpuLabelFontSize: Double {
        didSet {
            save(cpuLabelFontSize, key: Keys.cpuLabelFontSize)
            didChange.send()
        }
    }

    @Published var memoryLabelFontSize: Double {
        didSet {
            save(memoryLabelFontSize, key: Keys.memoryLabelFontSize)
            didChange.send()
        }
    }

    @Published var networkLabelFontSize: Double {
        didSet {
            save(networkLabelFontSize, key: Keys.networkLabelFontSize)
            didChange.send()
        }
    }

    @Published var diskLabelFontSize: Double {
        didSet {
            save(diskLabelFontSize, key: Keys.diskLabelFontSize)
            didChange.send()
        }
    }

    @Published var cpuHorizontalInset: Double {
        didSet {
            save(cpuHorizontalInset, key: Keys.cpuHorizontalInset)
            didChange.send()
        }
    }

    @Published var memoryHorizontalInset: Double {
        didSet {
            save(memoryHorizontalInset, key: Keys.memoryHorizontalInset)
            didChange.send()
        }
    }

    @Published var networkHorizontalInset: Double {
        didSet {
            save(networkHorizontalInset, key: Keys.networkHorizontalInset)
            didChange.send()
        }
    }

    @Published var diskHorizontalInset: Double {
        didSet {
            save(diskHorizontalInset, key: Keys.diskHorizontalInset)
            didChange.send()
        }
    }

    @Published var cpuVisualHeight: Double {
        didSet {
            save(cpuVisualHeight, key: Keys.cpuVisualHeight)
            didChange.send()
        }
    }

    @Published var cpuGraphDisplaySeconds: Double {
        didSet {
            save(cpuGraphDisplaySeconds, key: Keys.cpuGraphDisplaySeconds)
            didChange.send()
        }
    }

    @Published var memoryVisualHeight: Double {
        didSet {
            save(memoryVisualHeight, key: Keys.memoryVisualHeight)
            didChange.send()
        }
    }

    @Published var memoryVisualWidth: Double {
        didSet {
            save(memoryVisualWidth, key: Keys.memoryVisualWidth)
            didChange.send()
        }
    }

    @Published var networkGraphHeight: Double {
        didSet {
            save(networkGraphHeight, key: Keys.networkGraphHeight)
            didChange.send()
        }
    }

    @Published var networkGraphWidth: Double {
        didSet {
            save(networkGraphWidth, key: Keys.networkGraphWidth)
            didChange.send()
        }
    }

    @Published var temperatureGraphHeight: Double {
        didSet {
            save(temperatureGraphHeight, key: Keys.temperatureGraphHeight)
            didChange.send()
        }
    }

    @Published var temperatureGraphWidth: Double {
        didSet {
            save(temperatureGraphWidth, key: Keys.temperatureGraphWidth)
            didChange.send()
        }
    }

    @Published var fanGraphHeight: Double {
        didSet {
            save(fanGraphHeight, key: Keys.fanGraphHeight)
            didChange.send()
        }
    }

    @Published var fanGraphWidth: Double {
        didSet {
            save(fanGraphWidth, key: Keys.fanGraphWidth)
            didChange.send()
        }
    }

    @Published var cpuLabelVisualSpacing: Double {
        didSet {
            save(cpuLabelVisualSpacing, key: Keys.cpuLabelVisualSpacing)
            didChange.send()
        }
    }

    @Published var memoryLabelVisualSpacing: Double {
        didSet {
            save(memoryLabelVisualSpacing, key: Keys.memoryLabelVisualSpacing)
            didChange.send()
        }
    }

    @Published var cpuVisualValueSpacing: Double {
        didSet {
            save(cpuVisualValueSpacing, key: Keys.cpuVisualValueSpacing)
            didChange.send()
        }
    }

    @Published var memoryVisualValueSpacing: Double {
        didSet {
            save(memoryVisualValueSpacing, key: Keys.memoryVisualValueSpacing)
            didChange.send()
        }
    }

    @Published var cpuValueUnitSpacing: Double {
        didSet {
            save(cpuValueUnitSpacing, key: Keys.cpuValueUnitSpacing)
            didChange.send()
        }
    }

    @Published var memoryValueUnitSpacing: Double {
        didSet {
            save(memoryValueUnitSpacing, key: Keys.memoryValueUnitSpacing)
            didChange.send()
        }
    }

    @Published var networkLabelValueSpacing: Double {
        didSet {
            save(networkLabelValueSpacing, key: Keys.networkLabelValueSpacing)
            didChange.send()
        }
    }

    @Published var networkGraphValueSpacing: Double {
        didSet {
            save(networkGraphValueSpacing, key: Keys.networkGraphValueSpacing)
            didChange.send()
        }
    }

    @Published var networkUnitSpacing: Double {
        didSet {
            save(networkUnitSpacing, key: Keys.networkUnitSpacing)
            didChange.send()
        }
    }

    @Published var diskLabelValueSpacing: Double {
        didSet {
            save(diskLabelValueSpacing, key: Keys.diskLabelValueSpacing)
            didChange.send()
        }
    }

    @Published var diskValueUnitSpacing: Double {
        didSet {
            save(diskValueUnitSpacing, key: Keys.diskValueUnitSpacing)
            didChange.send()
        }
    }

    @Published var menuBarNetworkFontSize: Double {
        didSet {
            save(menuBarNetworkFontSize, key: Keys.menuBarNetworkFontSize)
            didChange.send()
        }
    }

    @Published var temperatureGraphValueSpacing: Double {
        didSet {
            save(temperatureGraphValueSpacing, key: Keys.temperatureGraphValueSpacing)
            didChange.send()
        }
    }

    @Published var fanGraphValueSpacing: Double {
        didSet {
            save(fanGraphValueSpacing, key: Keys.fanGraphValueSpacing)
            didChange.send()
        }
    }

    @Published var cpuGraphVerticalPadding: Double {
        didSet {
            save(cpuGraphVerticalPadding, key: Keys.cpuGraphVerticalPadding)
            didChange.send()
        }
    }

    @Published var memoryGaugeVerticalPadding: Double {
        didSet {
            save(memoryGaugeVerticalPadding, key: Keys.memoryGaugeVerticalPadding)
            didChange.send()
        }
    }

    @Published var cpuItemMargin: Double {
        didSet {
            save(cpuItemMargin, key: Keys.cpuItemMargin)
            didChange.send()
        }
    }

    @Published var memoryItemMargin: Double {
        didSet {
            save(memoryItemMargin, key: Keys.memoryItemMargin)
            didChange.send()
        }
    }

    @Published var networkItemMargin: Double {
        didSet {
            save(networkItemMargin, key: Keys.networkItemMargin)
            didChange.send()
        }
    }

    @Published var cpuMarginInsets: MetricInsets {
        didSet {
            save(cpuMarginInsets, key: Keys.cpuMarginInsets)
            didChange.send()
        }
    }

    @Published var cpuPaddingInsets: MetricInsets {
        didSet {
            save(cpuPaddingInsets, key: Keys.cpuPaddingInsets)
            didChange.send()
        }
    }

    @Published var memoryMarginInsets: MetricInsets {
        didSet {
            save(memoryMarginInsets, key: Keys.memoryMarginInsets)
            didChange.send()
        }
    }

    @Published var memoryPaddingInsets: MetricInsets {
        didSet {
            save(memoryPaddingInsets, key: Keys.memoryPaddingInsets)
            didChange.send()
        }
    }

    @Published var networkMarginInsets: MetricInsets {
        didSet {
            save(networkMarginInsets, key: Keys.networkMarginInsets)
            didChange.send()
        }
    }

    @Published var networkPaddingInsets: MetricInsets {
        didSet {
            save(networkPaddingInsets, key: Keys.networkPaddingInsets)
            didChange.send()
        }
    }

    @Published var menuBarBorderColor: GraphColor {
        didSet {
            save(menuBarBorderColor, key: Keys.menuBarBorderColor)
            didChange.send()
        }
    }

    @Published var menuBarBorderOpacity: Double {
        didSet {
            save(menuBarBorderOpacity, key: Keys.menuBarBorderOpacity)
            didChange.send()
        }
    }

    let didChange = PassthroughSubject<Void, Never>()

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        Self.registerInitialDefaults(on: defaults)
        self.cpuGraphLowColor = Self.loadColor(key: Keys.cpuGraphLowColor, defaults: defaults)
            ?? Self.loadColor(key: Keys.cpuGraphColor, defaults: defaults)
            ?? .cpuDefault
        self.cpuGraphMidColor = Self.loadColor(key: Keys.cpuGraphMidColor, defaults: defaults) ?? .midUsageDefault
        self.cpuGraphHighColor = Self.loadColor(key: Keys.cpuGraphHighColor, defaults: defaults) ?? .highUsageDefault
        self.memoryGraphLowColor = Self.loadColor(key: Keys.memoryGraphLowColor, defaults: defaults)
            ?? Self.loadColor(key: Keys.memoryGraphColor, defaults: defaults)
            ?? .memoryDefault
        self.memoryGraphMidColor = Self.loadColor(key: Keys.memoryGraphMidColor, defaults: defaults) ?? .midUsageDefault
        self.memoryGraphHighColor = Self.loadColor(key: Keys.memoryGraphHighColor, defaults: defaults) ?? .highUsageDefault
        self.networkGraphLowColor = Self.loadColor(key: Keys.networkGraphLowColor, defaults: defaults)
            ?? Self.loadColor(key: Keys.networkGraphColor, defaults: defaults)
            ?? .networkDefault
        self.networkGraphMidColor = Self.loadColor(key: Keys.networkGraphMidColor, defaults: defaults) ?? .midUsageDefault
        self.networkGraphHighColor = Self.loadColor(key: Keys.networkGraphHighColor, defaults: defaults) ?? .highUsageDefault
        self.temperatureGraphLowColor = Self.loadColor(key: Keys.temperatureGraphLowColor, defaults: defaults) ?? .cpuDefault
        self.temperatureGraphMidColor = Self.loadColor(key: Keys.temperatureGraphMidColor, defaults: defaults) ?? .midUsageDefault
        self.temperatureGraphHighColor = Self.loadColor(key: Keys.temperatureGraphHighColor, defaults: defaults) ?? .highUsageDefault
        self.fanGraphLowColor = Self.loadColor(key: Keys.fanGraphLowColor, defaults: defaults) ?? .networkDefault
        self.fanGraphMidColor = Self.loadColor(key: Keys.fanGraphMidColor, defaults: defaults) ?? .midUsageDefault
        self.fanGraphHighColor = Self.loadColor(key: Keys.fanGraphHighColor, defaults: defaults) ?? .highUsageDefault
        self.usesUsageGradient = defaults.object(forKey: Keys.usesUsageGradient) as? Bool ?? true
        self.usesTwoDigitPercent = defaults.object(forKey: Keys.usesTwoDigitPercent) as? Bool ?? true
        self.opensAtLogin = defaults.object(forKey: Keys.opensAtLogin) as? Bool ?? LoginItemController.isEnabled
        self.usesDarkAppearance = defaults.object(forKey: Keys.usesDarkAppearance) as? Bool ?? true
        self.showsCPUInMenuBar = defaults.object(forKey: Keys.showsCPUInMenuBar) as? Bool ?? true
        self.showsMemoryInMenuBar = defaults.object(forKey: Keys.showsMemoryInMenuBar) as? Bool ?? true
        self.showsNetworkInMenuBar = defaults.object(forKey: Keys.showsNetworkInMenuBar) as? Bool ?? true
        self.showsDiskInMenuBar = defaults.object(forKey: Keys.showsDiskInMenuBar) as? Bool ?? true
        self.showsCPULabelInMenuBar = defaults.object(forKey: Keys.showsCPULabelInMenuBar) as? Bool ?? true
        self.showsMemoryLabelInMenuBar = defaults.object(forKey: Keys.showsMemoryLabelInMenuBar) as? Bool ?? true
        self.showsNetworkLabelInMenuBar = defaults.object(forKey: Keys.showsNetworkLabelInMenuBar) as? Bool ?? true
        self.showsDiskLabelInMenuBar = defaults.object(forKey: Keys.showsDiskLabelInMenuBar) as? Bool ?? true
        self.showsNetworkGraphInMenuBar = defaults.object(forKey: Keys.showsNetworkGraphInMenuBar) as? Bool ?? false
        self.showsCPUGraphInMenuBar = defaults.object(forKey: Keys.showsCPUGraphInMenuBar) as? Bool ?? true
        self.showsMemoryGraphInMenuBar = defaults.object(forKey: Keys.showsMemoryGraphInMenuBar) as? Bool ?? true
        self.showsCPUUnitInMenuBar = defaults.object(forKey: Keys.showsCPUUnitInMenuBar) as? Bool ?? true
        self.showsMemoryUnitInMenuBar = defaults.object(forKey: Keys.showsMemoryUnitInMenuBar) as? Bool ?? true
        self.showsNetworkUnitInMenuBar = defaults.object(forKey: Keys.showsNetworkUnitInMenuBar) as? Bool ?? true
        self.showsDiskUnitInMenuBar = defaults.object(forKey: Keys.showsDiskUnitInMenuBar) as? Bool ?? true
        self.showsDiskDecimalCapacity = defaults.object(forKey: Keys.showsDiskDecimalCapacity) as? Bool ?? false
        self.showsTemperatureInMenuBar = defaults.object(forKey: Keys.showsTemperatureInMenuBar) as? Bool ?? false
        self.showsFanInMenuBar = defaults.object(forKey: Keys.showsFanInMenuBar) as? Bool ?? false
        self.showsAppearanceToggleInMenuBar = defaults.object(forKey: Keys.showsAppearanceToggleInMenuBar) as? Bool ?? true
        self.showsTemperatureLabelInMenuBar = defaults.object(forKey: Keys.showsTemperatureLabelInMenuBar) as? Bool ?? true
        self.showsFanLabelInMenuBar = defaults.object(forKey: Keys.showsFanLabelInMenuBar) as? Bool ?? true
        self.showsTemperatureGraphInMenuBar = defaults.object(forKey: Keys.showsTemperatureGraphInMenuBar) as? Bool ?? false
        self.showsFanGraphInMenuBar = defaults.object(forKey: Keys.showsFanGraphInMenuBar) as? Bool ?? false
        self.showsTemperatureUnitInMenuBar = defaults.object(forKey: Keys.showsTemperatureUnitInMenuBar) as? Bool ?? true
        self.showsFanUnitInMenuBar = defaults.object(forKey: Keys.showsFanUnitInMenuBar) as? Bool ?? true
        self.isMenuBarOrderModeEnabled = defaults.object(forKey: Keys.isMenuBarOrderModeEnabled) as? Bool ?? false
        self.menuBarMetricOrder = Self.loadMenuBarMetricOrder(defaults: defaults)
        self.showsCPUGraphInPopover = defaults.object(forKey: Keys.showsCPUGraphInPopover) as? Bool ?? true
        self.showsMemoryGraphInPopover = defaults.object(forKey: Keys.showsMemoryGraphInPopover) as? Bool ?? true
        self.showsNetworkGraphInPopover = defaults.object(forKey: Keys.showsNetworkGraphInPopover) as? Bool ?? true
        self.showsTemperatureGraphInPopover = defaults.object(forKey: Keys.showsTemperatureGraphInPopover) as? Bool ?? true
        self.showsFanGraphInPopover = defaults.object(forKey: Keys.showsFanGraphInPopover) as? Bool ?? true
        self.temperatureLabelFontSize = Self.loadDouble(key: Keys.temperatureLabelFontSize, defaults: defaults, fallback: 8)
        self.temperatureValueFontSize = Self.loadDouble(key: Keys.temperatureValueFontSize, defaults: defaults, fallback: 11.5)
        self.temperatureUnitFontSize = Self.loadDouble(key: Keys.temperatureUnitFontSize, defaults: defaults, fallback: 7.8)
        self.temperatureLabelValueSpacing = Self.loadDouble(key: Keys.temperatureLabelValueSpacing, defaults: defaults, fallback: 3)
        self.temperatureValueUnitSpacing = Self.loadDouble(key: Keys.temperatureValueUnitSpacing, defaults: defaults, fallback: 3)
        self.temperatureHorizontalInset = Self.loadDouble(key: Keys.temperatureHorizontalInset, defaults: defaults, fallback: 3)
        self.fanLabelFontSize = Self.loadDouble(key: Keys.fanLabelFontSize, defaults: defaults, fallback: 8)
        self.fanValueFontSize = Self.loadDouble(key: Keys.fanValueFontSize, defaults: defaults, fallback: 11.5)
        self.fanUnitFontSize = Self.loadDouble(key: Keys.fanUnitFontSize, defaults: defaults, fallback: 7.8)
        self.fanLabelValueSpacing = Self.loadDouble(key: Keys.fanLabelValueSpacing, defaults: defaults, fallback: 3)
        self.fanValueUnitSpacing = Self.loadDouble(key: Keys.fanValueUnitSpacing, defaults: defaults, fallback: 3)
        self.fanHorizontalInset = Self.loadDouble(key: Keys.fanHorizontalInset, defaults: defaults, fallback: 3)
        self.percentSymbolSpacing = Self.loadDouble(key: Keys.percentSymbolSpacing, defaults: defaults, fallback: 1.2)
        self.menuBarValueFontSize = Self.loadDouble(key: Keys.menuBarValueFontSize, defaults: defaults, fallback: 14)
        self.cpuValueFontSize = Self.loadDouble(key: Keys.cpuValueFontSize, defaults: defaults, fallback: Self.loadDouble(key: Keys.menuBarValueFontSize, defaults: defaults, fallback: 14))
        self.memoryValueFontSize = Self.loadDouble(key: Keys.memoryValueFontSize, defaults: defaults, fallback: Self.loadDouble(key: Keys.menuBarValueFontSize, defaults: defaults, fallback: 14))
        self.cpuUnitFontSize = Self.loadDouble(key: Keys.cpuUnitFontSize, defaults: defaults, fallback: Self.loadDouble(key: Keys.cpuValueFontSize, defaults: defaults, fallback: 14))
        self.memoryUnitFontSize = Self.loadDouble(key: Keys.memoryUnitFontSize, defaults: defaults, fallback: Self.loadDouble(key: Keys.memoryValueFontSize, defaults: defaults, fallback: 14))
        self.networkValueFontSize = Self.loadDouble(key: Keys.networkValueFontSize, defaults: defaults, fallback: 9.8)
        self.networkUnitFontSize = Self.loadDouble(key: Keys.networkUnitFontSize, defaults: defaults, fallback: 8.6)
        self.diskValueFontSize = Self.loadDouble(key: Keys.diskValueFontSize, defaults: defaults, fallback: 11.5)
        self.diskUnitFontSize = Self.loadDouble(key: Keys.diskUnitFontSize, defaults: defaults, fallback: 8.8)
        self.menuBarLabelFontSize = Self.loadDouble(key: Keys.menuBarLabelFontSize, defaults: defaults, fallback: 7.4)
        self.cpuLabelFontSize = Self.loadDouble(key: Keys.cpuLabelFontSize, defaults: defaults, fallback: 7.5)
        self.memoryLabelFontSize = Self.loadDouble(key: Keys.memoryLabelFontSize, defaults: defaults, fallback: 7.5)
        self.networkLabelFontSize = Self.loadDouble(key: Keys.networkLabelFontSize, defaults: defaults, fallback: 9.8)
        self.diskLabelFontSize = Self.loadDouble(key: Keys.diskLabelFontSize, defaults: defaults, fallback: 8)
        self.cpuHorizontalInset = Self.loadDouble(key: Keys.cpuHorizontalInset, defaults: defaults, fallback: 0)
        self.memoryHorizontalInset = Self.loadDouble(key: Keys.memoryHorizontalInset, defaults: defaults, fallback: 0)
        self.networkHorizontalInset = Self.loadDouble(key: Keys.networkHorizontalInset, defaults: defaults, fallback: 0)
        self.diskHorizontalInset = Self.loadDouble(key: Keys.diskHorizontalInset, defaults: defaults, fallback: 3)
        self.cpuVisualHeight = Self.loadDouble(key: Keys.cpuVisualHeight, defaults: defaults, fallback: 16.5)
        self.cpuGraphDisplaySeconds = Self.loadDouble(key: Keys.cpuGraphDisplaySeconds, defaults: defaults, fallback: 35)
        self.memoryVisualHeight = Self.loadDouble(key: Keys.memoryVisualHeight, defaults: defaults, fallback: 18)
        self.memoryVisualWidth = Self.loadDouble(key: Keys.memoryVisualWidth, defaults: defaults, fallback: 8)
        self.networkGraphHeight = Self.loadDouble(key: Keys.networkGraphHeight, defaults: defaults, fallback: 8)
        self.networkGraphWidth = Self.loadDouble(key: Keys.networkGraphWidth, defaults: defaults, fallback: 16)
        self.temperatureGraphHeight = Self.loadDouble(key: Keys.temperatureGraphHeight, defaults: defaults, fallback: 14)
        self.temperatureGraphWidth = Self.loadDouble(key: Keys.temperatureGraphWidth, defaults: defaults, fallback: 18)
        self.fanGraphHeight = Self.loadDouble(key: Keys.fanGraphHeight, defaults: defaults, fallback: 14)
        self.fanGraphWidth = Self.loadDouble(key: Keys.fanGraphWidth, defaults: defaults, fallback: 18)
        self.cpuLabelVisualSpacing = Self.loadDouble(key: Keys.cpuLabelVisualSpacing, defaults: defaults, fallback: 0)
        self.memoryLabelVisualSpacing = Self.loadDouble(key: Keys.memoryLabelVisualSpacing, defaults: defaults, fallback: 0)
        self.cpuVisualValueSpacing = Self.loadDouble(key: Keys.cpuVisualValueSpacing, defaults: defaults, fallback: 4)
        self.memoryVisualValueSpacing = Self.loadDouble(key: Keys.memoryVisualValueSpacing, defaults: defaults, fallback: 4)
        self.cpuValueUnitSpacing = Self.loadDouble(key: Keys.cpuValueUnitSpacing, defaults: defaults, fallback: Self.loadDouble(key: Keys.percentSymbolSpacing, defaults: defaults, fallback: 1.2))
        self.memoryValueUnitSpacing = Self.loadDouble(key: Keys.memoryValueUnitSpacing, defaults: defaults, fallback: Self.loadDouble(key: Keys.percentSymbolSpacing, defaults: defaults, fallback: 1.2))
        self.networkLabelValueSpacing = Self.loadDouble(key: Keys.networkLabelValueSpacing, defaults: defaults, fallback: 1)
        self.networkGraphValueSpacing = Self.loadDouble(key: Keys.networkGraphValueSpacing, defaults: defaults, fallback: 2)
        self.networkUnitSpacing = Self.loadDouble(key: Keys.networkUnitSpacing, defaults: defaults, fallback: 3)
        self.diskLabelValueSpacing = Self.loadDouble(key: Keys.diskLabelValueSpacing, defaults: defaults, fallback: 3)
        self.diskValueUnitSpacing = Self.loadDouble(key: Keys.diskValueUnitSpacing, defaults: defaults, fallback: 2)
        self.menuBarNetworkFontSize = Self.loadDouble(key: Keys.menuBarNetworkFontSize, defaults: defaults, fallback: 10)
        self.temperatureGraphValueSpacing = Self.loadDouble(key: Keys.temperatureGraphValueSpacing, defaults: defaults, fallback: 3)
        self.fanGraphValueSpacing = Self.loadDouble(key: Keys.fanGraphValueSpacing, defaults: defaults, fallback: 3)
        self.cpuGraphVerticalPadding = Self.loadDouble(key: Keys.cpuGraphVerticalPadding, defaults: defaults, fallback: 0)
        self.memoryGaugeVerticalPadding = Self.loadDouble(key: Keys.memoryGaugeVerticalPadding, defaults: defaults, fallback: 0.5)
        self.cpuItemMargin = Self.loadDouble(key: Keys.cpuItemMargin, defaults: defaults, fallback: 0)
        self.memoryItemMargin = Self.loadDouble(key: Keys.memoryItemMargin, defaults: defaults, fallback: 0)
        self.networkItemMargin = Self.loadDouble(key: Keys.networkItemMargin, defaults: defaults, fallback: 0)
        self.cpuMarginInsets = Self.loadInsets(key: Keys.cpuMarginInsets, defaults: defaults)
            ?? .trailing(Self.loadDouble(key: Keys.cpuItemMargin, defaults: defaults, fallback: 0))
        self.cpuPaddingInsets = Self.loadInsets(key: Keys.cpuPaddingInsets, defaults: defaults)
            ?? .vertical(Self.loadDouble(key: Keys.cpuGraphVerticalPadding, defaults: defaults, fallback: 0))
        self.memoryMarginInsets = Self.loadInsets(key: Keys.memoryMarginInsets, defaults: defaults)
            ?? .trailing(Self.loadDouble(key: Keys.memoryItemMargin, defaults: defaults, fallback: 0))
        self.memoryPaddingInsets = Self.loadInsets(key: Keys.memoryPaddingInsets, defaults: defaults)
            ?? .vertical(Self.loadDouble(key: Keys.memoryGaugeVerticalPadding, defaults: defaults, fallback: 0.5))
        self.networkMarginInsets = Self.loadInsets(key: Keys.networkMarginInsets, defaults: defaults)
            ?? .trailing(Self.loadDouble(key: Keys.networkItemMargin, defaults: defaults, fallback: 0))
        self.networkPaddingInsets = Self.loadInsets(key: Keys.networkPaddingInsets, defaults: defaults) ?? .zero
        self.menuBarBorderColor = Self.loadColor(key: Keys.menuBarBorderColor, defaults: defaults) ?? .black
        self.menuBarBorderOpacity = Self.loadDouble(key: Keys.menuBarBorderOpacity, defaults: defaults, fallback: 0.85)

        LoginItemController.setEnabled(opensAtLogin)
    }

    private static func registerInitialDefaults(on defaults: UserDefaults) {
        var values: [String: Any] = [
            Keys.usesUsageGradient: true,
            Keys.usesTwoDigitPercent: true,
            Keys.opensAtLogin: false,
            Keys.usesDarkAppearance: true,
            Keys.showsCPUInMenuBar: true,
            Keys.showsMemoryInMenuBar: true,
            Keys.showsNetworkInMenuBar: true,
            Keys.showsDiskInMenuBar: true,
            Keys.showsTemperatureInMenuBar: true,
            Keys.showsFanInMenuBar: true,
            Keys.showsAppearanceToggleInMenuBar: true,
            Keys.showsCPULabelInMenuBar: true,
            Keys.showsMemoryLabelInMenuBar: true,
            Keys.showsNetworkLabelInMenuBar: true,
            Keys.showsDiskLabelInMenuBar: true,
            Keys.showsTemperatureLabelInMenuBar: false,
            Keys.showsFanLabelInMenuBar: false,
            Keys.showsCPUGraphInMenuBar: true,
            Keys.showsMemoryGraphInMenuBar: true,
            Keys.showsNetworkGraphInMenuBar: false,
            Keys.showsTemperatureGraphInMenuBar: false,
            Keys.showsFanGraphInMenuBar: false,
            Keys.showsCPUUnitInMenuBar: true,
            Keys.showsMemoryUnitInMenuBar: true,
            Keys.showsNetworkUnitInMenuBar: true,
            Keys.showsDiskUnitInMenuBar: true,
            Keys.showsDiskDecimalCapacity: false,
            Keys.showsTemperatureUnitInMenuBar: true,
            Keys.showsFanUnitInMenuBar: true,
            Keys.isMenuBarOrderModeEnabled: false,
            Keys.showsCPUGraphInPopover: true,
            Keys.showsMemoryGraphInPopover: true,
            Keys.showsNetworkGraphInPopover: true,
            Keys.showsTemperatureGraphInPopover: false,
            Keys.showsFanGraphInPopover: false,
            Keys.temperatureLabelFontSize: 8,
            Keys.temperatureValueFontSize: 14,
            Keys.temperatureUnitFontSize: 13,
            Keys.temperatureLabelValueSpacing: 0,
            Keys.temperatureValueUnitSpacing: 0,
            Keys.temperatureHorizontalInset: 0,
            Keys.fanLabelFontSize: 8,
            Keys.fanValueFontSize: 14,
            Keys.fanUnitFontSize: 12,
            Keys.fanLabelValueSpacing: 3,
            Keys.fanValueUnitSpacing: 1,
            Keys.fanHorizontalInset: 0,
            Keys.percentSymbolSpacing: 1.7,
            Keys.menuBarValueFontSize: 14,
            Keys.cpuValueFontSize: 14,
            Keys.memoryValueFontSize: 14,
            Keys.cpuUnitFontSize: 14,
            Keys.memoryUnitFontSize: 14,
            Keys.networkValueFontSize: 9.8,
            Keys.networkUnitFontSize: 8.6,
            Keys.diskValueFontSize: 11.5,
            Keys.diskUnitFontSize: 8.8,
            Keys.menuBarLabelFontSize: 7.4,
            Keys.cpuLabelFontSize: 7.5,
            Keys.memoryLabelFontSize: 7.5,
            Keys.networkLabelFontSize: 9.8,
            Keys.diskLabelFontSize: 8,
            Keys.cpuHorizontalInset: 0,
            Keys.memoryHorizontalInset: 0,
            Keys.networkHorizontalInset: 0,
            Keys.diskHorizontalInset: 3,
            Keys.cpuVisualHeight: 16.5,
            Keys.cpuGraphDisplaySeconds: 35,
            Keys.memoryVisualHeight: 18,
            Keys.memoryVisualWidth: 8,
            Keys.networkGraphHeight: 8,
            Keys.networkGraphWidth: 16,
            Keys.temperatureGraphHeight: 14,
            Keys.temperatureGraphWidth: 17,
            Keys.fanGraphHeight: 14,
            Keys.fanGraphWidth: 18,
            Keys.cpuLabelVisualSpacing: 0,
            Keys.memoryLabelVisualSpacing: 0,
            Keys.cpuVisualValueSpacing: 4,
            Keys.memoryVisualValueSpacing: 4,
            Keys.cpuValueUnitSpacing: 1.7,
            Keys.memoryValueUnitSpacing: 1.7,
            Keys.networkLabelValueSpacing: 1,
            Keys.networkGraphValueSpacing: 2,
            Keys.networkUnitSpacing: 3,
            Keys.diskLabelValueSpacing: 3,
            Keys.diskValueUnitSpacing: 2,
            Keys.menuBarNetworkFontSize: 10,
            Keys.temperatureGraphValueSpacing: 3,
            Keys.fanGraphValueSpacing: 3,
            Keys.cpuGraphVerticalPadding: 0,
            Keys.memoryGaugeVerticalPadding: 0,
            Keys.cpuItemMargin: 0,
            Keys.memoryItemMargin: 0,
            Keys.networkItemMargin: 0,
            Keys.menuBarBorderOpacity: 0.5,
            Keys.settingsWindowWidth: initialSettingsWindowContentSize.width,
            Keys.settingsWindowHeight: initialSettingsWindowContentSize.height,
            "NSStatusItem Preferred Position dev.local.SystemPulse.cpu": 1055,
            "NSStatusItem Preferred Position dev.local.SystemPulse.memory": 985,
            "NSStatusItem Preferred Position dev.local.SystemPulse.disk": 947,
            "NSStatusItem Preferred Position dev.local.SystemPulse.network": 909,
            "NSStatusItem Preferred Position dev.local.SystemPulse.fan": 835,
            "NSStatusItem Preferred Position dev.local.SystemPulse.temperature": 785,
            "NSStatusItem Preferred Position dev.local.SystemPulse.appearance": 735,
            "NSStatusItem VisibleCC dev.local.SystemPulse.cpu": true,
            "NSStatusItem VisibleCC dev.local.SystemPulse.memory": true,
            "NSStatusItem VisibleCC dev.local.SystemPulse.disk": true,
            "NSStatusItem VisibleCC dev.local.SystemPulse.network": true,
            "NSStatusItem VisibleCC dev.local.SystemPulse.fan": true,
            "NSStatusItem VisibleCC dev.local.SystemPulse.temperature": true,
            "NSStatusItem VisibleCC dev.local.SystemPulse.appearance": true
        ]

        values[Keys.menuBarMetricOrder] = encodedDefaultMenuBarMetricOrder
        values[Keys.cpuGraphLowColor] = Data(#"{"green":0.9768045545,"red":0,"blue":0}"#.utf8)
        values[Keys.cpuGraphMidColor] = Data(#"{"green":0.9855536819,"red":0.9994240403,"blue":0}"#.utf8)
        values[Keys.cpuGraphHighColor] = Data(#"{"green":0.16590115427970886,"blue":0.0178317129611969,"red":1}"#.utf8)
        values[Keys.memoryGraphLowColor] = Data(#"{"green":0.9855536819,"red":0.9994240403,"blue":0}"#.utf8)
        values[Keys.memoryGraphMidColor] = Data(#"{"green":0.9855536819,"red":0.9994240403,"blue":0}"#.utf8)
        values[Keys.memoryGraphHighColor] = Data(#"{"green":0.16590115427970886,"blue":0.0178317129611969,"red":1}"#.utf8)
        values[Keys.networkGraphLowColor] = Data(#"{"red":0,"green":0.5898008943,"blue":1}"#.utf8)
        values[Keys.networkGraphMidColor] = Data(#"{"red":0,"green":0.5898008943,"blue":1}"#.utf8)
        values[Keys.networkGraphHighColor] = Data(#"{"red":0,"green":0.9914394021,"blue":1}"#.utf8)
        values[Keys.temperatureGraphLowColor] = Data(#"{"red":0,"green":0.9768045545,"blue":0,"alpha":1}"#.utf8)
        values[Keys.temperatureGraphMidColor] = Data(#"{"alpha":1,"red":0.9994240403,"blue":0,"green":0.9855536819}"#.utf8)
        values[Keys.temperatureGraphHighColor] = Data(#"{"green":0.16590115427970886,"blue":0.0178317129611969,"red":1,"alpha":1}"#.utf8)
        values[Keys.fanGraphLowColor] = Data(#"{"red":0,"green":0.9768045545,"blue":0,"alpha":1}"#.utf8)
        values[Keys.fanGraphMidColor] = Data(#"{"alpha":1,"green":0.9855536819,"red":0.9994240403,"blue":0}"#.utf8)
        values[Keys.fanGraphHighColor] = Data(#"{"green":0.16590115427970886,"blue":0.0178317129611969,"red":1,"alpha":1}"#.utf8)
        values[Keys.menuBarBorderColor] = Data(#"{"blue":0,"green":0,"red":0,"alpha":0.7168523014863631}"#.utf8)
        values[Keys.cpuMarginInsets] = Data(#"{"bottom":0,"right":-12,"top":0,"left":-12}"#.utf8)
        values[Keys.cpuPaddingInsets] = Data(#"{"top":0,"bottom":0,"right":-6,"left":-6}"#.utf8)
        values[Keys.memoryMarginInsets] = Data(#"{"right":0,"bottom":0,"top":0,"left":0}"#.utf8)
        values[Keys.memoryPaddingInsets] = Data(#"{"right":0,"bottom":0,"top":0,"left":0}"#.utf8)
        values[Keys.networkMarginInsets] = Data(#"{"right":0,"bottom":0,"top":0,"left":0}"#.utf8)
        values[Keys.networkPaddingInsets] = Data(#"{"right":0,"bottom":0,"top":0,"left":0}"#.utf8)

        defaults.register(defaults: values)
    }

    func settingsWindowContentSize() -> NSSize {
        let width = Self.loadDouble(
            key: Keys.settingsWindowWidth,
            defaults: defaults,
            fallback: Self.initialSettingsWindowContentSize.width
        )
        let height = Self.loadDouble(
            key: Keys.settingsWindowHeight,
            defaults: defaults,
            fallback: Self.initialSettingsWindowContentSize.height
        )

        return NSSize(
            width: max(width, Self.minimumSettingsWindowSize.width),
            height: max(height, Self.minimumSettingsWindowSize.height)
        )
    }

    func saveSettingsWindowContentSize(_ size: NSSize) {
        defaults.set(max(size.width, Self.minimumSettingsWindowSize.width), forKey: Keys.settingsWindowWidth)
        defaults.set(max(size.height, Self.minimumSettingsWindowSize.height), forKey: Keys.settingsWindowHeight)
        defaults.synchronize()
    }

    func gradientColors(low: GraphColor, mid: GraphColor, high: GraphColor, intensity: Double) -> [Color] {
        guard usesUsageGradient else {
            return [low.color, low.color]
        }

        return [
            low.color.opacity(0.75),
            mid.color.opacity(0.9),
            adaptiveColor(low: low, mid: mid, high: high, intensity: intensity)
        ]
    }

    func adaptiveColor(low: GraphColor, mid: GraphColor, high: GraphColor, intensity: Double) -> Color {
        guard usesUsageGradient else { return low.color }

        return usageColor(low: low, mid: mid, high: high, intensity: intensity).color
    }

    func usageColor(low: GraphColor, mid: GraphColor, high: GraphColor, intensity: Double) -> GraphColor {
        let intensity = intensity.clampedUnit

        if intensity <= 0.5 {
            return low.blended(with: mid, amount: intensity / 0.5)
        }

        return mid.blended(with: high, amount: (intensity - 0.5) / 0.5)
    }

    func percentText(_ value: Double) -> String {
        MetricFormatter.percent(
            value,
            minimumIntegerDigits: usesTwoDigitPercent ? 2 : 1,
            symbolSpacing: Int(percentSymbolSpacing.rounded())
        )
    }

    func resetLayoutInsets(for metric: StatusMetricKind) {
        switch metric {
        case .cpu:
            cpuPaddingInsets = .zero
            cpuMarginInsets = .zero
        case .memory:
            memoryPaddingInsets = .zero
            memoryMarginInsets = .zero
        case .network:
            networkPaddingInsets = .zero
            networkMarginInsets = .zero
        case .disk:
            break
        }
    }

    static func normalizedMenuBarMetricOrder(_ order: [MenuBarMetricKind]) -> [MenuBarMetricKind] {
        let uniqueOrder = order.reduce(into: [MenuBarMetricKind]()) { result, metric in
            guard !result.contains(metric) else { return }
            result.append(metric)
        }
        let missingMetrics = defaultMenuBarMetricOrder.filter { !uniqueOrder.contains($0) }
        return uniqueOrder + missingMetrics
    }

    private static var defaultMenuBarMetricOrder: [MenuBarMetricKind] {
        [.cpu, .memory, .disk, .network, .fan, .temperature, .appearance]
    }

    private static var encodedDefaultMenuBarMetricOrder: Data {
        (try? JSONEncoder().encode(defaultMenuBarMetricOrder)) ?? Data()
    }

    private func save(_ color: GraphColor, key: String) {
        guard let data = try? JSONEncoder().encode(color) else { return }
        defaults.set(data, forKey: key)
        defaults.synchronize()
    }

    private func save(_ value: Bool, key: String) {
        defaults.set(value, forKey: key)
        defaults.synchronize()
    }

    private func save(_ value: Double, key: String) {
        defaults.set(value, forKey: key)
        defaults.synchronize()
    }

    private func save(_ order: [MenuBarMetricKind], key: String) {
        guard let data = try? JSONEncoder().encode(order) else { return }
        defaults.set(data, forKey: key)
        defaults.synchronize()
    }

    private func save(_ insets: MetricInsets, key: String) {
        guard let data = try? JSONEncoder().encode(insets) else { return }
        defaults.set(data, forKey: key)
        defaults.synchronize()
    }

    private func saveStatusItemPreferredPositions(for order: [MenuBarMetricKind]) {
        let positionSlots: [Double] = [1055, 985, 947, 909, 835, 785, 735]
        for (index, metric) in Self.normalizedMenuBarMetricOrder(order).enumerated() {
            defaults.set(positionSlots[index], forKey: "NSStatusItem Preferred Position \(metric.statusItemAutosaveName)")
        }
        defaults.synchronize()
    }

    private static func loadColor(key: String, defaults: UserDefaults) -> GraphColor? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(GraphColor.self, from: data)
    }

    private static func loadInsets(key: String, defaults: UserDefaults) -> MetricInsets? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(MetricInsets.self, from: data)
    }

    private static func loadDouble(key: String, defaults: UserDefaults, fallback: Double) -> Double {
        defaults.object(forKey: key) == nil ? fallback : defaults.double(forKey: key)
    }

    private static func loadMenuBarMetricOrder(defaults: UserDefaults) -> [MenuBarMetricKind] {
        guard let data = defaults.data(forKey: Keys.menuBarMetricOrder),
              let order = try? JSONDecoder().decode([MenuBarMetricKind].self, from: data)
        else {
            return defaultMenuBarMetricOrder
        }

        return normalizedMenuBarMetricOrder(order)
    }
}

private enum Keys {
    static let cpuGraphLowColor = "cpuGraphLowColor"
    static let cpuGraphMidColor = "cpuGraphMidColor"
    static let cpuGraphHighColor = "cpuGraphHighColor"
    static let memoryGraphLowColor = "memoryGraphLowColor"
    static let memoryGraphMidColor = "memoryGraphMidColor"
    static let memoryGraphHighColor = "memoryGraphHighColor"
    static let networkGraphLowColor = "networkGraphLowColor"
    static let networkGraphMidColor = "networkGraphMidColor"
    static let networkGraphHighColor = "networkGraphHighColor"
    static let temperatureGraphLowColor = "temperatureGraphLowColor"
    static let temperatureGraphMidColor = "temperatureGraphMidColor"
    static let temperatureGraphHighColor = "temperatureGraphHighColor"
    static let fanGraphLowColor = "fanGraphLowColor"
    static let fanGraphMidColor = "fanGraphMidColor"
    static let fanGraphHighColor = "fanGraphHighColor"
    static let cpuGraphColor = "cpuGraphColor"
    static let memoryGraphColor = "memoryGraphColor"
    static let networkGraphColor = "networkGraphColor"
    static let usesUsageGradient = "usesUsageGradient"
    static let usesTwoDigitPercent = "usesTwoDigitPercent"
    static let opensAtLogin = "opensAtLogin"
    static let usesDarkAppearance = "usesDarkAppearance"
    static let showsCPUInMenuBar = "showsCPUInMenuBar"
    static let showsMemoryInMenuBar = "showsMemoryInMenuBar"
    static let showsNetworkInMenuBar = "showsNetworkInMenuBar"
    static let showsDiskInMenuBar = "showsDiskInMenuBar"
    static let showsCPULabelInMenuBar = "showsCPULabelInMenuBar"
    static let showsMemoryLabelInMenuBar = "showsMemoryLabelInMenuBar"
    static let showsNetworkLabelInMenuBar = "showsNetworkLabelInMenuBar"
    static let showsDiskLabelInMenuBar = "showsDiskLabelInMenuBar"
    static let showsNetworkGraphInMenuBar = "showsNetworkGraphInMenuBar"
    static let showsCPUGraphInMenuBar = "showsCPUGraphInMenuBar"
    static let showsMemoryGraphInMenuBar = "showsMemoryGraphInMenuBar"
    static let showsCPUUnitInMenuBar = "showsCPUUnitInMenuBar"
    static let showsMemoryUnitInMenuBar = "showsMemoryUnitInMenuBar"
    static let showsNetworkUnitInMenuBar = "showsNetworkUnitInMenuBar"
    static let showsDiskUnitInMenuBar = "showsDiskUnitInMenuBar"
    static let showsDiskDecimalCapacity = "showsDiskDecimalCapacity"
    static let showsTemperatureInMenuBar = "showsTemperatureInMenuBar"
    static let showsFanInMenuBar = "showsFanInMenuBar"
    static let showsAppearanceToggleInMenuBar = "showsAppearanceToggleInMenuBar"
    static let showsTemperatureLabelInMenuBar = "showsTemperatureLabelInMenuBar"
    static let showsFanLabelInMenuBar = "showsFanLabelInMenuBar"
    static let showsTemperatureGraphInMenuBar = "showsTemperatureGraphInMenuBar"
    static let showsFanGraphInMenuBar = "showsFanGraphInMenuBar"
    static let showsTemperatureUnitInMenuBar = "showsTemperatureUnitInMenuBar"
    static let showsFanUnitInMenuBar = "showsFanUnitInMenuBar"
    static let isMenuBarOrderModeEnabled = "isMenuBarOrderModeEnabled"
    static let menuBarMetricOrder = "menuBarMetricOrder"
    static let showsCPUGraphInPopover = "showsCPUGraphInPopover"
    static let showsMemoryGraphInPopover = "showsMemoryGraphInPopover"
    static let showsNetworkGraphInPopover = "showsNetworkGraphInPopover"
    static let showsTemperatureGraphInPopover = "showsTemperatureGraphInPopover"
    static let showsFanGraphInPopover = "showsFanGraphInPopover"
    static let temperatureLabelFontSize = "temperatureLabelFontSize"
    static let temperatureValueFontSize = "temperatureValueFontSize"
    static let temperatureUnitFontSize = "temperatureUnitFontSize"
    static let temperatureLabelValueSpacing = "temperatureLabelValueSpacing"
    static let temperatureValueUnitSpacing = "temperatureValueUnitSpacing"
    static let temperatureHorizontalInset = "temperatureHorizontalInset"
    static let fanLabelFontSize = "fanLabelFontSize"
    static let fanValueFontSize = "fanValueFontSize"
    static let fanUnitFontSize = "fanUnitFontSize"
    static let fanLabelValueSpacing = "fanLabelValueSpacing"
    static let fanValueUnitSpacing = "fanValueUnitSpacing"
    static let fanHorizontalInset = "fanHorizontalInset"
    static let percentSymbolSpacing = "percentSymbolSpacing"
    static let menuBarValueFontSize = "menuBarValueFontSize"
    static let cpuValueFontSize = "cpuValueFontSize"
    static let memoryValueFontSize = "memoryValueFontSize"
    static let cpuUnitFontSize = "cpuUnitFontSize"
    static let memoryUnitFontSize = "memoryUnitFontSize"
    static let networkValueFontSize = "networkValueFontSize"
    static let networkUnitFontSize = "networkUnitFontSize"
    static let diskValueFontSize = "diskValueFontSize"
    static let diskUnitFontSize = "diskUnitFontSize"
    static let menuBarLabelFontSize = "menuBarLabelFontSize"
    static let cpuLabelFontSize = "cpuLabelFontSize"
    static let memoryLabelFontSize = "memoryLabelFontSize"
    static let networkLabelFontSize = "networkLabelFontSize"
    static let diskLabelFontSize = "diskLabelFontSize"
    static let cpuHorizontalInset = "cpuHorizontalInset"
    static let memoryHorizontalInset = "memoryHorizontalInset"
    static let networkHorizontalInset = "networkHorizontalInset"
    static let diskHorizontalInset = "diskHorizontalInset"
    static let cpuVisualHeight = "cpuVisualHeight"
    static let cpuGraphDisplaySeconds = "cpuGraphDisplaySeconds"
    static let memoryVisualHeight = "memoryVisualHeight"
    static let memoryVisualWidth = "memoryVisualWidth"
    static let networkGraphHeight = "networkGraphHeight"
    static let networkGraphWidth = "networkGraphWidth"
    static let temperatureGraphHeight = "temperatureGraphHeight"
    static let temperatureGraphWidth = "temperatureGraphWidth"
    static let fanGraphHeight = "fanGraphHeight"
    static let fanGraphWidth = "fanGraphWidth"
    static let cpuLabelVisualSpacing = "cpuLabelVisualSpacing"
    static let memoryLabelVisualSpacing = "memoryLabelVisualSpacing"
    static let cpuVisualValueSpacing = "cpuVisualValueSpacing"
    static let memoryVisualValueSpacing = "memoryVisualValueSpacing"
    static let cpuValueUnitSpacing = "cpuValueUnitSpacing"
    static let memoryValueUnitSpacing = "memoryValueUnitSpacing"
    static let networkLabelValueSpacing = "networkLabelValueSpacing"
    static let networkGraphValueSpacing = "networkGraphValueSpacing"
    static let networkUnitSpacing = "networkUnitSpacing"
    static let diskLabelValueSpacing = "diskLabelValueSpacing"
    static let diskValueUnitSpacing = "diskValueUnitSpacing"
    static let menuBarNetworkFontSize = "menuBarNetworkFontSize"
    static let temperatureGraphValueSpacing = "temperatureGraphValueSpacing"
    static let fanGraphValueSpacing = "fanGraphValueSpacing"
    static let cpuGraphVerticalPadding = "cpuGraphVerticalPadding"
    static let memoryGaugeVerticalPadding = "memoryGaugeVerticalPadding"
    static let cpuItemMargin = "cpuItemMargin"
    static let memoryItemMargin = "memoryItemMargin"
    static let networkItemMargin = "networkItemMargin"
    static let cpuMarginInsets = "cpuMarginInsets"
    static let cpuPaddingInsets = "cpuPaddingInsets"
    static let memoryMarginInsets = "memoryMarginInsets"
    static let memoryPaddingInsets = "memoryPaddingInsets"
    static let networkMarginInsets = "networkMarginInsets"
    static let networkPaddingInsets = "networkPaddingInsets"
    static let menuBarBorderColor = "menuBarBorderColor"
    static let menuBarBorderOpacity = "menuBarBorderOpacity"
    static let settingsWindowWidth = "settingsWindowWidth"
    static let settingsWindowHeight = "settingsWindowHeight"
}

private extension GraphColor {
    static let cpuDefault = GraphColor(red: 0, green: 1, blue: 0)
    static let memoryDefault = GraphColor(red: 0.9994240403, green: 0.9855536819, blue: 0)
    static let networkDefault = GraphColor(red: 0.94, green: 0.48, blue: 0.32)
    static let midUsageDefault = GraphColor(red: 1, green: 0.8113318085670471, blue: 0.12447956949472427)
    static let highUsageDefault = GraphColor(red: 1, green: 0.16590115427970886, blue: 0.0178317129611969)
    static let black = GraphColor(red: 0, green: 0, blue: 0)
}
