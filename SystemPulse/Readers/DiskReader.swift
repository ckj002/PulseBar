import Foundation

final class DiskReader {
    func read() -> DiskSample {
        let rootURL = URL(fileURLWithPath: "/")
        let keys: Set<URLResourceKey> = [
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeAvailableCapacityKey,
            .volumeTotalCapacityKey,
            .volumeNameKey
        ]

        if let values = try? rootURL.resourceValues(forKeys: keys),
           let total = values.volumeTotalCapacity,
           total > 0 {
            let available = values.volumeAvailableCapacityForImportantUsage
                ?? values.volumeAvailableCapacity.map(Int64.init)
                ?? 0
            return sample(
                availableBytes: UInt64(max(0, available)),
                totalBytes: UInt64(max(0, Int64(total))),
                volumeName: values.volumeName
            )
        }

        guard let attributes = try? FileManager.default.attributesOfFileSystem(forPath: "/"),
              let total = attributes[.systemSize] as? NSNumber,
              let available = attributes[.systemFreeSize] as? NSNumber,
              total.uint64Value > 0
        else {
            return DiskSample(availableBytes: 0, totalBytes: 0, usage: 0, availability: .unavailable, volumeName: nil)
        }

        return sample(
            availableBytes: available.uint64Value,
            totalBytes: total.uint64Value,
            volumeName: nil
        )
    }

    private func sample(availableBytes: UInt64, totalBytes: UInt64, volumeName: String?) -> DiskSample {
        let usedBytes = totalBytes > availableBytes ? totalBytes - availableBytes : 0
        let usage = totalBytes > 0 ? Double(usedBytes) / Double(totalBytes) : 0
        return DiskSample(
            availableBytes: availableBytes,
            totalBytes: totalBytes,
            usage: usage.clampedUnit,
            availability: .available,
            volumeName: volumeName
        )
    }
}
