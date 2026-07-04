import AppKit
import Combine
import SwiftUI

struct GraphColor: Codable, Equatable {
    var red: Double
    var green: Double
    var blue: Double

    var color: Color {
        Color(red: red, green: green, blue: blue)
    }

    var nsColor: NSColor {
        NSColor(srgbRed: CGFloat(red), green: CGFloat(green), blue: CGFloat(blue), alpha: 1)
    }

    init(red: Double, green: Double, blue: Double) {
        self.red = red.clampedUnit
        self.green = green.clampedUnit
        self.blue = blue.clampedUnit
    }

    init(_ color: Color) {
        let nsColor = NSColor(color).usingColorSpace(.sRGB)
            ?? NSColor(color).usingColorSpace(.deviceRGB)
            ?? .controlAccentColor
        self.red = Double(nsColor.redComponent).clampedUnit
        self.green = Double(nsColor.greenComponent).clampedUnit
        self.blue = Double(nsColor.blueComponent).clampedUnit
    }

    init(_ color: NSColor) {
        let nsColor = color.usingColorSpace(.sRGB)
            ?? color.usingColorSpace(.deviceRGB)
            ?? .controlAccentColor
        self.red = Double(nsColor.redComponent).clampedUnit
        self.green = Double(nsColor.greenComponent).clampedUnit
        self.blue = Double(nsColor.blueComponent).clampedUnit
    }

    func blended(with other: GraphColor, amount: Double) -> GraphColor {
        let amount = amount.clampedUnit
        return GraphColor(
            red: red + (other.red - red) * amount,
            green: green + (other.green - green) * amount,
            blue: blue + (other.blue - blue) * amount
        )
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
}

@MainActor
final class SettingsStore: ObservableObject {
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

    @Published var networkValueFontSize: Double {
        didSet {
            save(networkValueFontSize, key: Keys.networkValueFontSize)
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

    @Published var networkLabelValueSpacing: Double {
        didSet {
            save(networkLabelValueSpacing, key: Keys.networkLabelValueSpacing)
            didChange.send()
        }
    }

    @Published var networkUnitSpacing: Double {
        didSet {
            save(networkUnitSpacing, key: Keys.networkUnitSpacing)
            didChange.send()
        }
    }

    @Published var menuBarNetworkFontSize: Double {
        didSet {
            save(menuBarNetworkFontSize, key: Keys.menuBarNetworkFontSize)
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

    let didChange = PassthroughSubject<Void, Never>()

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
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
        self.usesUsageGradient = defaults.object(forKey: Keys.usesUsageGradient) as? Bool ?? true
        self.usesTwoDigitPercent = defaults.object(forKey: Keys.usesTwoDigitPercent) as? Bool ?? true
        self.percentSymbolSpacing = Self.loadDouble(key: Keys.percentSymbolSpacing, defaults: defaults, fallback: 1)
        self.menuBarValueFontSize = Self.loadDouble(key: Keys.menuBarValueFontSize, defaults: defaults, fallback: 11.5)
        self.cpuValueFontSize = Self.loadDouble(key: Keys.cpuValueFontSize, defaults: defaults, fallback: Self.loadDouble(key: Keys.menuBarValueFontSize, defaults: defaults, fallback: 11.5))
        self.memoryValueFontSize = Self.loadDouble(key: Keys.memoryValueFontSize, defaults: defaults, fallback: Self.loadDouble(key: Keys.menuBarValueFontSize, defaults: defaults, fallback: 11.5))
        self.networkValueFontSize = Self.loadDouble(key: Keys.networkValueFontSize, defaults: defaults, fallback: Self.loadDouble(key: Keys.menuBarNetworkFontSize, defaults: defaults, fallback: 8.9))
        self.menuBarLabelFontSize = Self.loadDouble(key: Keys.menuBarLabelFontSize, defaults: defaults, fallback: 7.2)
        self.cpuLabelFontSize = Self.loadDouble(key: Keys.cpuLabelFontSize, defaults: defaults, fallback: Self.loadDouble(key: Keys.menuBarLabelFontSize, defaults: defaults, fallback: 7.2))
        self.memoryLabelFontSize = Self.loadDouble(key: Keys.memoryLabelFontSize, defaults: defaults, fallback: Self.loadDouble(key: Keys.menuBarLabelFontSize, defaults: defaults, fallback: 7.2))
        self.networkLabelFontSize = Self.loadDouble(key: Keys.networkLabelFontSize, defaults: defaults, fallback: Self.loadDouble(key: Keys.menuBarNetworkFontSize, defaults: defaults, fallback: 8.9))
        self.cpuHorizontalInset = Self.loadDouble(key: Keys.cpuHorizontalInset, defaults: defaults, fallback: 1)
        self.memoryHorizontalInset = Self.loadDouble(key: Keys.memoryHorizontalInset, defaults: defaults, fallback: 1)
        self.networkHorizontalInset = Self.loadDouble(key: Keys.networkHorizontalInset, defaults: defaults, fallback: 1)
        self.cpuVisualHeight = Self.loadDouble(key: Keys.cpuVisualHeight, defaults: defaults, fallback: 19)
        self.cpuGraphDisplaySeconds = Self.loadDouble(key: Keys.cpuGraphDisplaySeconds, defaults: defaults, fallback: 20)
        self.memoryVisualHeight = Self.loadDouble(key: Keys.memoryVisualHeight, defaults: defaults, fallback: 19)
        self.cpuLabelVisualSpacing = Self.loadDouble(key: Keys.cpuLabelVisualSpacing, defaults: defaults, fallback: 4)
        self.memoryLabelVisualSpacing = Self.loadDouble(key: Keys.memoryLabelVisualSpacing, defaults: defaults, fallback: 4)
        self.cpuVisualValueSpacing = Self.loadDouble(key: Keys.cpuVisualValueSpacing, defaults: defaults, fallback: 5)
        self.memoryVisualValueSpacing = Self.loadDouble(key: Keys.memoryVisualValueSpacing, defaults: defaults, fallback: 5)
        self.networkLabelValueSpacing = Self.loadDouble(key: Keys.networkLabelValueSpacing, defaults: defaults, fallback: 3)
        self.networkUnitSpacing = Self.loadDouble(key: Keys.networkUnitSpacing, defaults: defaults, fallback: 3)
        self.menuBarNetworkFontSize = Self.loadDouble(key: Keys.menuBarNetworkFontSize, defaults: defaults, fallback: 8.9)
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
        }
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

    private func save(_ insets: MetricInsets, key: String) {
        guard let data = try? JSONEncoder().encode(insets) else { return }
        defaults.set(data, forKey: key)
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
    static let cpuGraphColor = "cpuGraphColor"
    static let memoryGraphColor = "memoryGraphColor"
    static let networkGraphColor = "networkGraphColor"
    static let usesUsageGradient = "usesUsageGradient"
    static let usesTwoDigitPercent = "usesTwoDigitPercent"
    static let percentSymbolSpacing = "percentSymbolSpacing"
    static let menuBarValueFontSize = "menuBarValueFontSize"
    static let cpuValueFontSize = "cpuValueFontSize"
    static let memoryValueFontSize = "memoryValueFontSize"
    static let networkValueFontSize = "networkValueFontSize"
    static let menuBarLabelFontSize = "menuBarLabelFontSize"
    static let cpuLabelFontSize = "cpuLabelFontSize"
    static let memoryLabelFontSize = "memoryLabelFontSize"
    static let networkLabelFontSize = "networkLabelFontSize"
    static let cpuHorizontalInset = "cpuHorizontalInset"
    static let memoryHorizontalInset = "memoryHorizontalInset"
    static let networkHorizontalInset = "networkHorizontalInset"
    static let cpuVisualHeight = "cpuVisualHeight"
    static let cpuGraphDisplaySeconds = "cpuGraphDisplaySeconds"
    static let memoryVisualHeight = "memoryVisualHeight"
    static let cpuLabelVisualSpacing = "cpuLabelVisualSpacing"
    static let memoryLabelVisualSpacing = "memoryLabelVisualSpacing"
    static let cpuVisualValueSpacing = "cpuVisualValueSpacing"
    static let memoryVisualValueSpacing = "memoryVisualValueSpacing"
    static let networkLabelValueSpacing = "networkLabelValueSpacing"
    static let networkUnitSpacing = "networkUnitSpacing"
    static let menuBarNetworkFontSize = "menuBarNetworkFontSize"
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
}

private extension GraphColor {
    static let cpuDefault = GraphColor(red: 0.25, green: 0.62, blue: 1.0)
    static let memoryDefault = GraphColor(red: 0.28, green: 0.78, blue: 0.54)
    static let networkDefault = GraphColor(red: 0.94, green: 0.48, blue: 0.32)
    static let midUsageDefault = GraphColor(red: 1.0, green: 0.78, blue: 0.10)
    static let highUsageDefault = GraphColor(red: 1.0, green: 0.24, blue: 0.20)
    static let black = GraphColor(red: 0, green: 0, blue: 0)
}
