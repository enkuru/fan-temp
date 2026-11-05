struct Fan {
    let rpm: Double
    let maxRPM: Double

    var percentOfMax: Double {
        rpm / maxRPM * 100
    }
}

struct Reading {
    let cpuAverage: Double
    let cpuHottest: Double
    let fan: Fan?
}

final class Sensors {
    private let smc: SMC
    private let cpuKeys: [String]
    private let fans: [(speedKey: String, maxRPM: Double)]

    init?() {
        guard let smc = SMC() else { return nil }
        self.smc = smc

        // Apple Silicon names CPU core sensors Tp* (performance) and Te* (efficiency); some slots report no real value.
        cpuKeys = smc.keys().filter { key in
            (key.hasPrefix("Tp") || key.hasPrefix("Te")) && smc.read(key).map(Self.isPlausible) == true
        }
        let fanCount = smc.read("FNum").map(Int.init) ?? 0
        fans = (0..<fanCount).compactMap { index in
            guard let maxRPM = smc.read("F\(index)Mx"), maxRPM > 0 else { return nil }
            return ("F\(index)Ac", maxRPM)
        }
    }

    func read() -> Reading? {
        let temperatures = cpuKeys.compactMap { smc.read($0) }.filter(Self.isPlausible)
        guard let hottest = temperatures.max() else { return nil }

        let fastestFan = fans.compactMap { fan in smc.read(fan.speedKey).map { Fan(rpm: $0, maxRPM: fan.maxRPM) } }
            .max { $0.rpm < $1.rpm }
        return Reading(cpuAverage: temperatures.reduce(0, +) / Double(temperatures.count),
                       cpuHottest: hottest,
                       fan: fastestFan)
    }

    private static func isPlausible(_ celsius: Double) -> Bool {
        (5...130).contains(celsius)
    }
}
