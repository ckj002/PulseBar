import Foundation

struct SystemSnapshot {
    var timestamp: Date
    var cpu: CPUMetric
    var memory: MemoryMetric
    var network: NetworkMetric
    var thermal: ThermalMetric
    var fan: FanMetric

    static let empty = SystemSnapshot(
        timestamp: Date(),
        cpu: CPUMetric(usage: 0, history: Array(repeating: 0, count: 60), coreCount: 0, coreUsages: []),
        memory: MemoryMetric(usedBytes: 0, totalBytes: 0, usage: 0, history: Array(repeating: 0, count: 60)),
        network: NetworkMetric(
            uploadBytesPerSecond: 0,
            downloadBytesPerSecond: 0,
            totalUploadBytes: 0,
            totalDownloadBytes: 0,
            measuredDuration: 0,
            uploadHistory: Array(repeating: 0, count: 60),
            downloadHistory: Array(repeating: 0, count: 60)
        ),
        thermal: ThermalMetric(cpuTemperatureCelsius: nil, availability: .unavailable, history: Array(repeating: 0, count: 60)),
        fan: FanMetric(rpm: nil, availability: .unavailable, history: Array(repeating: 0, count: 60))
    )

    var menuBarSystemText: String {
        "CPU \(cpu.percentText) MEM \(memory.percentText)"
    }

    var menuBarCPUGraphText: String {
        MetricFormatter.sparkline(cpu.history, points: 4)
    }
}

struct CPUMetric {
    var usage: Double
    var history: [Double]
    var coreCount: Int
    var coreUsages: [Double]

    var percentText: String {
        MetricFormatter.percent(usage)
    }
}

struct MemoryMetric {
    var usedBytes: UInt64
    var totalBytes: UInt64
    var usage: Double
    var history: [Double]

    var percentText: String {
        MetricFormatter.percent(usage)
    }

    var detailText: String {
        "\(MetricFormatter.bytes(usedBytes)) / \(MetricFormatter.bytes(totalBytes))"
    }

    var menuBarGaugeText: String {
        MetricFormatter.gauge(usage, segments: 4)
    }
}

struct NetworkMetric {
    var uploadBytesPerSecond: Double
    var downloadBytesPerSecond: Double
    var totalUploadBytes: UInt64
    var totalDownloadBytes: UInt64
    var measuredDuration: TimeInterval
    var uploadHistory: [Double]
    var downloadHistory: [Double]

    var uploadText: String {
        MetricFormatter.rate(uploadBytesPerSecond)
    }

    var downloadText: String {
        MetricFormatter.rate(downloadBytesPerSecond)
    }

    var uploadCompactText: String {
        MetricFormatter.compactRate(uploadBytesPerSecond)
    }

    var downloadCompactText: String {
        MetricFormatter.compactRate(downloadBytesPerSecond)
    }

    var totalUploadText: String {
        MetricFormatter.megabytes(totalUploadBytes)
    }

    var totalDownloadText: String {
        MetricFormatter.megabytes(totalDownloadBytes)
    }

    var measuredDurationText: String {
        MetricFormatter.duration(measuredDuration)
    }
}

struct ThermalMetric {
    var cpuTemperatureCelsius: Double?
    var availability: MetricAvailability
    var history: [Double]

    var displayText: String {
        guard let cpuTemperatureCelsius else { return availability.displayText }
        return String(format: "%.0f °C", cpuTemperatureCelsius)
    }
}

struct FanMetric {
    var rpm: Int?
    var availability: MetricAvailability
    var history: [Double]

    var displayText: String {
        guard let rpm else { return availability.displayText }
        return "\(rpm) RPM"
    }
}

enum MetricAvailability {
    case available
    case unavailable

    var displayText: String {
        switch self {
        case .available:
            return "Available"
        case .unavailable:
            return "Unavailable"
        }
    }
}

struct CPUSample {
    var usage: Double
    var coreCount: Int
    var coreUsages: [Double]
}

struct MemorySample {
    var usedBytes: UInt64
    var totalBytes: UInt64
    var usage: Double
}

struct NetworkSample {
    var uploadBytesPerSecond: Double
    var downloadBytesPerSecond: Double
    var totalUploadBytes: UInt64
    var totalDownloadBytes: UInt64
    var measuredDuration: TimeInterval
}

struct ThermalSample {
    var cpuTemperatureCelsius: Double?
    var availability: MetricAvailability
}

struct FanSample {
    var rpm: Int?
    var availability: MetricAvailability
}

enum MetricFormatter {
    static func percent(_ value: Double, minimumIntegerDigits: Int = 2, symbolSpacing: Int = 1) -> String {
        let percent = Int((value.clampedUnit * 100).rounded())
        let digits = max(1, minimumIntegerDigits)
        let spacing = String(repeating: "\u{200A}", count: max(0, symbolSpacing))
        return String(format: "%0\(digits)d", percent) + spacing + "%"
    }

    static func bytes(_ value: UInt64) -> String {
        guard value > 0 else { return "0 B" }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB, .useTB]
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: Int64(value))
    }

    static func megabytes(_ value: UInt64) -> String {
        let megabytes = Double(value) / (1024.0 * 1024.0)
        return String(format: "%.1f MB", megabytes)
    }

    static func rate(_ value: Double) -> String {
        megabyteRate(value)
    }

    static func compactRate(_ value: Double) -> String {
        megabyteRate(value)
    }

    static func duration(_ seconds: TimeInterval) -> String {
        let totalSeconds = max(0, Int(seconds.rounded()))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }

        return String(format: "%02d:%02d", minutes, seconds)
    }

    private static func megabyteRate(_ value: Double) -> String {
        guard value > 0 else { return "- MB/s" }

        let megabytesPerSecond = value / (1024.0 * 1024.0)
        return String(format: "%.1f MB/s", megabytesPerSecond)
    }

    static func sparkline(_ values: [Double], points: Int) -> String {
        let bars = ["▁", "▂", "▃", "▄", "▅", "▆", "▇", "█"]
        let values = Array(values.suffix(points))

        return values.map { value in
            let index = min(Int((value.clampedUnit * Double(bars.count - 1)).rounded()), bars.count - 1)
            return bars[index]
        }.joined()
    }

    static func gauge(_ value: Double, segments: Int) -> String {
        let filledCount = Int((value.clampedUnit * Double(segments)).rounded())

        return (0..<segments).map { index in
            index < filledCount ? "●" : "○"
        }.joined()
    }
}

extension Double {
    var clampedUnit: Double {
        min(max(self, 0), 1)
    }

    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
