import Foundation

final class ThermalReader {
    func read() -> ThermalSample {
        ThermalSample(cpuTemperatureCelsius: nil, availability: .unavailable)
    }
}
