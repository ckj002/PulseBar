import Darwin
import Foundation

final class MemoryReader {
    func read() -> MemorySample {
        var pageSize: vm_size_t = 0
        host_page_size(mach_host_self(), &pageSize)

        var stats = vm_statistics64_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride)

        let result = withUnsafeMutablePointer(to: &stats) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }

        let totalBytes = ProcessInfo.processInfo.physicalMemory

        guard result == KERN_SUCCESS else {
            return MemorySample(usedBytes: 0, totalBytes: totalBytes, usage: 0)
        }

        let usedPages = UInt64(stats.active_count) + UInt64(stats.wire_count) + UInt64(stats.compressor_page_count)
        let usedBytes = min(usedPages * UInt64(pageSize), totalBytes)
        let usage = totalBytes > 0 ? Double(usedBytes) / Double(totalBytes) : 0

        return MemorySample(usedBytes: usedBytes, totalBytes: totalBytes, usage: usage.clampedUnit)
    }
}
