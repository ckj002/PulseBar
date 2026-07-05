import Foundation

final class FanReader {
    private let smc = SMCReader.shared

    func read() -> FanSample {
        guard let rpm = fanSpeedRPM() else {
            return FanSample(rpm: nil, availability: .unavailable)
        }

        return FanSample(rpm: rpm, availability: .available)
    }

    private func fanSpeedRPM() -> Int? {
        let fanCount = Int(smc.readNumericValue("FNum") ?? 0)
        let keys: [String]

        if fanCount > 0 {
            keys = (0..<fanCount).map { "F\($0)Ac" }
        } else {
            keys = ["F0Ac", "F1Ac", "F2Ac", "F3Ac"]
        }

        let values = keys
            .compactMap { smc.readNumericValue($0) }
            .filter { (100...15000).contains($0) }

        guard !values.isEmpty else { return nil }
        return Int((values.max() ?? 0).rounded())
    }
}
