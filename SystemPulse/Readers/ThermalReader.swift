import Foundation
import IOKit

final class ThermalReader {
    private let smc = SMCReader.shared
    private var cachedTemperatureKeys: [String]?

    func read() -> ThermalSample {
        guard let temperature = cpuTemperature() else {
            return ThermalSample(cpuTemperatureCelsius: nil, availability: .unavailable)
        }

        return ThermalSample(cpuTemperatureCelsius: temperature, availability: .available)
    }

    private func cpuTemperature() -> Double? {
        let knownCPUKeys = [
            "TC0P", "TC0F", "TC0D", "TC0H", "TC0E", "TC0C", "TCXC",
            "TC1C", "TC2C", "TC3C", "TC4C", "TC1P", "TC2P", "TC3P", "TC4P",
            "Tp09", "Tp0T", "Tp0P", "Tm0P", "Ts0P"
        ]

        let knownValues = knownCPUKeys.compactMap { smc.readNumericValue($0) }.filter(isPlausibleTemperature)
        if let value = knownValues.max() {
            return value
        }

        let keys = cachedTemperatureKeys ?? smc.temperatureKeys()
        cachedTemperatureKeys = keys

        if let value = keys
            .filter(isLikelyCPUTemperatureKey)
            .compactMap({ smc.readNumericValue($0) })
            .filter(isPlausibleTemperature)
            .max() {
            return value
        }

        return keys
            .compactMap { smc.readNumericValue($0) }
            .filter(isPlausibleTemperature)
            .max()
    }

    private func isLikelyCPUTemperatureKey(_ key: String) -> Bool {
        key.hasPrefix("TC") || key == "Tp09" || key == "Tp0T"
    }

    private func isPlausibleTemperature(_ value: Double) -> Bool {
        (5...130).contains(value)
    }
}

final class SMCReader {
    static let shared = SMCReader()

    private let connection: io_connect_t?
    private var keyInfoCache: [String: SMCKeyInfo] = [:]

    private init() {
        connection = SMCReader.openConnection()
    }

    deinit {
        if let connection {
            IOServiceClose(connection)
        }
    }

    func readNumericValue(_ key: String) -> Double? {
        guard let value = readKey(key) else { return nil }

        switch value.type {
        case "sp78":
            guard value.bytes.count >= 2 else { return nil }
            let raw = Int16(bitPattern: UInt16(value.bytes[0]) << 8 | UInt16(value.bytes[1]))
            return Double(raw) / 256.0
        case "fpe2":
            guard value.bytes.count >= 2 else { return nil }
            let raw = UInt16(value.bytes[0]) << 8 | UInt16(value.bytes[1])
            return Double(raw) / 4.0
        case "fp88":
            guard value.bytes.count >= 2 else { return nil }
            let raw = UInt16(value.bytes[0]) << 8 | UInt16(value.bytes[1])
            return Double(raw) / 256.0
        case "flt ":
            guard value.bytes.count >= 4 else { return nil }
            let raw = UInt32(value.bytes[0])
                | UInt32(value.bytes[1]) << 8
                | UInt32(value.bytes[2]) << 16
                | UInt32(value.bytes[3]) << 24
            return Double(Float32(bitPattern: raw))
        case "ui8 ":
            guard let first = value.bytes.first else { return nil }
            return Double(first)
        case "ui16":
            guard value.bytes.count >= 2 else { return nil }
            return Double(UInt16(value.bytes[0]) << 8 | UInt16(value.bytes[1]))
        case "ui32":
            guard value.bytes.count >= 4 else { return nil }
            return Double(UInt32(value.bytes[0]) << 24
                | UInt32(value.bytes[1]) << 16
                | UInt32(value.bytes[2]) << 8
                | UInt32(value.bytes[3]))
        default:
            return nil
        }
    }

    func temperatureKeys() -> [String] {
        allKeys().filter { key in
            guard key.hasPrefix("T"), let value = readKey(key) else { return false }
            return value.type == "sp78" || value.type == "flt " || value.type == "fp88"
        }
    }

    func allKeys() -> [String] {
        guard let keyCount = readNumericValue("#KEY") else { return [] }

        return (0..<Int(keyCount)).compactMap { keyAtIndex($0) }
    }

    private func readKey(_ key: String) -> SMCValue? {
        guard let keyInfo = keyInfo(key), keyInfo.dataSize > 0 else { return nil }

        var input = SMCKeyData()
        input.key = SMCReader.fourCharCode(key)
        input.keyInfo = keyInfo.raw
        input.data8 = SMCCommand.readBytes.rawValue

        guard let output = call(input) else { return nil }
        let bytes = SMCReader.bytes(from: output.bytes, count: Int(keyInfo.dataSize))

        return SMCValue(key: key, type: SMCReader.string(from: keyInfo.dataType), bytes: bytes)
    }

    private func keyInfo(_ key: String) -> SMCKeyInfo? {
        if let cached = keyInfoCache[key] {
            return cached
        }

        var input = SMCKeyData()
        input.key = SMCReader.fourCharCode(key)
        input.data8 = SMCCommand.readKeyInfo.rawValue

        guard let output = call(input), output.result == SMCResult.success.rawValue else { return nil }
        let info = SMCKeyInfo(raw: output.keyInfo)
        keyInfoCache[key] = info
        return info
    }

    private func keyAtIndex(_ index: Int) -> String? {
        var input = SMCKeyData()
        input.data8 = SMCCommand.readIndex.rawValue
        input.data32 = UInt32(index)

        guard let output = call(input), output.key != 0 else { return nil }
        return SMCReader.string(from: output.key)
    }

    private func call(_ input: SMCKeyData) -> SMCKeyData? {
        guard let connection else { return nil }

        var input = input
        var output = SMCKeyData()
        let inputSize = MemoryLayout<SMCKeyData>.stride
        var outputSize = MemoryLayout<SMCKeyData>.stride
        let result = withUnsafePointer(to: &input) { inputPointer in
            inputPointer.withMemoryRebound(to: UInt8.self, capacity: inputSize) { inputBytes in
                withUnsafeMutablePointer(to: &output) { outputPointer in
                    outputPointer.withMemoryRebound(to: UInt8.self, capacity: outputSize) { outputBytes in
                        IOConnectCallStructMethod(
                            connection,
                            UInt32(SMCSelector.kernelIndex.rawValue),
                            inputBytes,
                            inputSize,
                            outputBytes,
                            &outputSize
                        )
                    }
                }
            }
        }

        return result == kIOReturnSuccess ? output : nil
    }

    private static func openConnection() -> io_connect_t? {
        let matchingNames = ["AppleSMC", "AppleSMCKeysEndpoint"]

        for name in matchingNames {
            let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching(name))
            guard service != IO_OBJECT_NULL else { continue }
            defer { IOObjectRelease(service) }

            var connection = io_connect_t()
            let result = IOServiceOpen(service, mach_task_self_, 0, &connection)
            if result == kIOReturnSuccess {
                return connection
            }
        }

        return nil
    }

    private static func fourCharCode(_ string: String) -> UInt32 {
        string.utf8.prefix(4).reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
    }

    private static func string(from code: UInt32) -> String {
        let bytes = [
            UInt8((code >> 24) & 0xff),
            UInt8((code >> 16) & 0xff),
            UInt8((code >> 8) & 0xff),
            UInt8(code & 0xff)
        ]
        return String(bytes: bytes, encoding: .ascii) ?? ""
    }

    private static func bytes(from tuple: SMCBytes, count: Int) -> [UInt8] {
        withUnsafeBytes(of: tuple) { rawBuffer in
            Array(rawBuffer.prefix(max(0, min(count, rawBuffer.count))))
        }
    }
}

private struct SMCValue {
    var key: String
    var type: String
    var bytes: [UInt8]
}

private struct SMCKeyInfo {
    var dataSize: UInt32
    var dataType: UInt32
    var dataAttributes: UInt8

    var raw: SMCKeyInfoData {
        SMCKeyInfoData(dataSize: dataSize, dataType: dataType, dataAttributes: dataAttributes)
    }

    init(raw: SMCKeyInfoData) {
        dataSize = raw.dataSize
        dataType = raw.dataType
        dataAttributes = raw.dataAttributes
    }
}

private enum SMCSelector: Int {
    case kernelIndex = 2
}

private enum SMCCommand: UInt8 {
    case readBytes = 5
    case readIndex = 8
    case readKeyInfo = 9
}

private enum SMCResult: UInt8 {
    case success = 0
}

private struct SMCVersion {
    var major: UInt8 = 0
    var minor: UInt8 = 0
    var build: UInt8 = 0
    var reserved: UInt8 = 0
    var release: UInt16 = 0
}

private struct SMCPowerLimitData {
    var version: UInt16 = 0
    var length: UInt16 = 0
    var cpuPLimit: UInt32 = 0
    var gpuPLimit: UInt32 = 0
    var memPLimit: UInt32 = 0
}

private struct SMCKeyInfoData {
    var dataSize: UInt32 = 0
    var dataType: UInt32 = 0
    var dataAttributes: UInt8 = 0
}

private typealias SMCBytes = (
    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8
)

private struct SMCKeyData {
    var key: UInt32 = 0
    var vers = SMCVersion()
    var pLimitData = SMCPowerLimitData()
    var keyInfo = SMCKeyInfoData()
    var padding: UInt16 = 0
    var result: UInt8 = 0
    var status: UInt8 = 0
    var data8: UInt8 = 0
    var data32: UInt32 = 0
    var bytes: SMCBytes = (
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0
    )
}
