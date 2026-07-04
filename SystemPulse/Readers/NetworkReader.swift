import Darwin
import Foundation

final class NetworkReader {
    private struct NetworkTotals {
        var sent: UInt64
        var received: UInt64
    }

    private var previousTotals: NetworkTotals?
    private var previousDate: Date?
    private var measurementStartDate: Date?
    private var totalSent: UInt64 = 0
    private var totalReceived: UInt64 = 0

    func read() -> NetworkSample {
        let totals = currentTotals()
        let now = Date()
        if measurementStartDate == nil {
            measurementStartDate = now
        }

        defer {
            previousTotals = totals
            previousDate = now
        }

        guard let previousTotals, let previousDate else {
            return NetworkSample(
                uploadBytesPerSecond: 0,
                downloadBytesPerSecond: 0,
                totalUploadBytes: totalSent,
                totalDownloadBytes: totalReceived,
                measuredDuration: measuredDuration(now)
            )
        }

        let interval = max(now.timeIntervalSince(previousDate), 0.001)
        let sentDelta = totals.sent >= previousTotals.sent ? totals.sent - previousTotals.sent : 0
        let receivedDelta = totals.received >= previousTotals.received ? totals.received - previousTotals.received : 0
        totalSent = addingCapped(totalSent, sentDelta)
        totalReceived = addingCapped(totalReceived, receivedDelta)

        return NetworkSample(
            uploadBytesPerSecond: Double(sentDelta) / interval,
            downloadBytesPerSecond: Double(receivedDelta) / interval,
            totalUploadBytes: totalSent,
            totalDownloadBytes: totalReceived,
            measuredDuration: measuredDuration(now)
        )
    }

    private func currentTotals() -> NetworkTotals {
        var sent: UInt64 = 0
        var received: UInt64 = 0
        var addresses: UnsafeMutablePointer<ifaddrs>?

        guard getifaddrs(&addresses) == 0, let firstAddress = addresses else {
            return NetworkTotals(sent: sent, received: received)
        }

        defer {
            freeifaddrs(addresses)
        }

        var cursor: UnsafeMutablePointer<ifaddrs>? = firstAddress
        while let pointer = cursor {
            let interface = pointer.pointee
            cursor = interface.ifa_next

            guard let address = interface.ifa_addr else { continue }
            guard address.pointee.sa_family == UInt8(AF_LINK) else { continue }

            let flags = interface.ifa_flags
            guard (flags & UInt32(IFF_UP)) != 0 else { continue }
            guard (flags & UInt32(IFF_LOOPBACK)) == 0 else { continue }

            let name = String(cString: interface.ifa_name)
            guard !name.hasPrefix("awdl"), !name.hasPrefix("llw"), !name.hasPrefix("utun") else { continue }

            guard let data = interface.ifa_data?.assumingMemoryBound(to: if_data.self).pointee else { continue }

            sent += UInt64(data.ifi_obytes)
            received += UInt64(data.ifi_ibytes)
        }

        return NetworkTotals(sent: sent, received: received)
    }

    private func measuredDuration(_ now: Date) -> TimeInterval {
        guard let measurementStartDate else { return 0 }
        return max(0, now.timeIntervalSince(measurementStartDate))
    }

    private func addingCapped(_ value: UInt64, _ delta: UInt64) -> UInt64 {
        let result = value.addingReportingOverflow(delta)
        return result.overflow ? UInt64.max : result.partialValue
    }
}
