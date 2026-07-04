import Darwin
import Foundation

final class CPUReader {
    private var previousLoad: host_cpu_load_info_data_t?

    func read() -> CPUSample {
        var load = host_cpu_load_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.stride / MemoryLayout<integer_t>.stride)

        let result = withUnsafeMutablePointer(to: &load) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            return CPUSample(usage: 0, coreCount: ProcessInfo.processInfo.activeProcessorCount, coreUsages: [])
        }

        defer {
            previousLoad = load
        }

        guard let previousLoad else {
            return CPUSample(usage: 0, coreCount: ProcessInfo.processInfo.activeProcessorCount, coreUsages: [])
        }

        let user = Double(load.cpu_ticks.0 &- previousLoad.cpu_ticks.0)
        let system = Double(load.cpu_ticks.1 &- previousLoad.cpu_ticks.1)
        let idle = Double(load.cpu_ticks.2 &- previousLoad.cpu_ticks.2)
        let nice = Double(load.cpu_ticks.3 &- previousLoad.cpu_ticks.3)
        let total = user + system + idle + nice
        let usage = total > 0 ? (total - idle) / total : 0

        return CPUSample(
            usage: usage.clampedUnit,
            coreCount: ProcessInfo.processInfo.activeProcessorCount,
            coreUsages: []
        )
    }
}
