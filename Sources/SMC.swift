import IOKit

/// Read-only client for the AppleSMC driver.
final class SMC {
    private enum Command {
        static let readKey: UInt8 = 5
        static let keyAtIndex: UInt8 = 8
        static let keyInfo: UInt8 = 9
    }

    private static let handleEventSelector: UInt32 = 2

    private var connection: io_connect_t = 0

    init?() {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }

        guard IOServiceOpen(service, mach_task_self_, 0, &connection) == kIOReturnSuccess else { return nil }
    }

    deinit {
        IOServiceClose(connection)
    }

    func keys() -> [String] {
        let count = read("#KEY").map(Int.init) ?? 0
        return (0..<count).compactMap { index in
            var input = SMCParamStruct()
            input.data8 = Command.keyAtIndex
            input.data32 = UInt32(index)
            return call(&input).map { Self.string($0.key) }
        }
    }

    func read(_ key: String) -> Double? {
        var input = SMCParamStruct()
        input.key = Self.fourCC(key)
        input.data8 = Command.keyInfo
        guard let info = call(&input) else { return nil }

        input.keyInfo.dataSize = info.keyInfo.dataSize
        input.data8 = Command.readKey
        guard let output = call(&input) else { return nil }

        let size = Int(info.keyInfo.dataSize)
        let bytes = withUnsafeBytes(of: output.bytes) { Array($0.prefix(size)) }
        return Self.decode(type: Self.string(info.keyInfo.dataType), bytes: bytes)
    }

    private func call(_ input: inout SMCParamStruct) -> SMCParamStruct? {
        var output = SMCParamStruct()
        var outputSize = MemoryLayout<SMCParamStruct>.stride
        let result = IOConnectCallStructMethod(connection, Self.handleEventSelector,
                                               &input, MemoryLayout<SMCParamStruct>.stride,
                                               &output, &outputSize)
        return result == kIOReturnSuccess && output.result == 0 ? output : nil
    }

    // Apple Silicon reports temperatures and fan speeds as little-endian floats; integer keys stay big-endian.
    private static func decode(type: String, bytes: [UInt8]) -> Double? {
        switch (type, bytes.count) {
        case ("flt ", 4): return Double(bytes.withUnsafeBytes { $0.loadUnaligned(as: Float.self) })
        case ("ui8 ", 1): return Double(bytes[0])
        case ("ui32", 4): return Double(bytes.reduce(UInt32(0)) { $0 << 8 | UInt32($1) })
        default: return nil
        }
    }

    private static func fourCC(_ key: String) -> UInt32 {
        key.utf8.reduce(0) { $0 << 8 | UInt32($1) }
    }

    private static func string(_ code: UInt32) -> String {
        String(decoding: [24, 16, 8, 0].map { UInt8(truncatingIfNeeded: code >> $0) }, as: UTF8.self)
    }
}
