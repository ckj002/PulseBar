import Foundation

@MainActor
final class SystemMonitorService: ObservableObject {
    @Published private(set) var snapshot = SystemSnapshot.empty

    private let updateInterval: TimeInterval
    private let cpuReader = CPUReader()
    private let memoryReader = MemoryReader()
    private let networkReader = NetworkReader()
    private let thermalReader = ThermalReader()
    private let fanReader = FanReader()
    private var timer: Timer?

    init(updateInterval: TimeInterval = 1) {
        self.updateInterval = updateInterval
        refresh()
        start()
    }

    deinit {
        timer?.invalidate()
    }

    func start() {
        guard timer == nil else { return }

        let timer = Timer(timeInterval: updateInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }

        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func refresh() {
        let cpuSample = cpuReader.read()
        let memorySample = memoryReader.read()
        let networkSample = networkReader.read()
        let thermalSample = thermalReader.read()
        let fanSample = fanReader.read()

        snapshot = SystemSnapshot(
            timestamp: Date(),
            cpu: CPUMetric(
                usage: cpuSample.usage,
                history: append(cpuSample.usage, to: snapshot.cpu.history, limit: 60),
                coreCount: cpuSample.coreCount,
                coreUsages: cpuSample.coreUsages
            ),
            memory: MemoryMetric(
                usedBytes: memorySample.usedBytes,
                totalBytes: memorySample.totalBytes,
                usage: memorySample.usage,
                history: append(memorySample.usage, to: snapshot.memory.history, limit: 60)
            ),
            network: NetworkMetric(
                uploadBytesPerSecond: networkSample.uploadBytesPerSecond,
                downloadBytesPerSecond: networkSample.downloadBytesPerSecond,
                totalUploadBytes: networkSample.totalUploadBytes,
                totalDownloadBytes: networkSample.totalDownloadBytes,
                measuredDuration: networkSample.measuredDuration,
                uploadHistory: append(normalizedNetworkRate(networkSample.uploadBytesPerSecond), to: snapshot.network.uploadHistory, limit: 60),
                downloadHistory: append(normalizedNetworkRate(networkSample.downloadBytesPerSecond), to: snapshot.network.downloadHistory, limit: 60)
            ),
            thermal: ThermalMetric(
                cpuTemperatureCelsius: thermalSample.cpuTemperatureCelsius,
                availability: thermalSample.availability
            ),
            fan: FanMetric(
                rpm: fanSample.rpm,
                availability: fanSample.availability
            )
        )
    }

    private func append(_ value: Double, to history: [Double], limit: Int) -> [Double] {
        var nextHistory = history
        nextHistory.append(value.clampedUnit)

        if nextHistory.count > limit {
            nextHistory.removeFirst(nextHistory.count - limit)
        }

        return nextHistory
    }

    private func normalizedNetworkRate(_ value: Double) -> Double {
        let oneHundredMegabytes = 100.0 * 1024.0 * 1024.0
        return (value / oneHundredMegabytes).clampedUnit
    }
}
