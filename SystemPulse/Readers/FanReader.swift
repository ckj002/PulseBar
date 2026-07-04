import Foundation

final class FanReader {
    func read() -> FanSample {
        FanSample(rpm: nil, availability: .unavailable)
    }
}
