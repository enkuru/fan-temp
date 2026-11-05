import AppKit
import ServiceManagement

private enum FanUnit: String {
    case rpm
    case percent
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private static let fanUnitKey = "fanUnit"
    private static let spinFanKey = "spinFan"

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let fanOverlay = FanOverlay()
    private let sensors = Sensors()
    private let averageItem = NSMenuItem()
    private let hottestItem = NSMenuItem()
    private let fanItem = NSMenuItem()
    private let rpmItem = NSMenuItem(title: "RPM", action: #selector(selectFanUnit), keyEquivalent: "")
    private let percentItem = NSMenuItem(title: "Percentage of Max", action: #selector(selectFanUnit), keyEquivalent: "")
    private let spinItem = NSMenuItem(title: "Spin Fan Icon", action: #selector(toggleSpin), keyEquivalent: "")
    private let loginItem = NSMenuItem(title: "Open at Login", action: #selector(toggleOpenAtLogin), keyEquivalent: "")

    private var reading: Reading?

    private var fanUnit = FanUnit(rawValue: UserDefaults.standard.string(forKey: AppDelegate.fanUnitKey) ?? "") ?? .rpm {
        didSet {
            UserDefaults.standard.set(fanUnit.rawValue, forKey: Self.fanUnitKey)
            showReading()
        }
    }

    private var spinsFan = UserDefaults.standard.object(forKey: AppDelegate.spinFanKey) as? Bool ?? true {
        didSet {
            UserDefaults.standard.set(spinsFan, forKey: Self.spinFanKey)
            showReading()
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let fanUnitMenu = NSMenu()
        for (item, unit) in [(rpmItem, FanUnit.rpm), (percentItem, FanUnit.percent)] {
            item.target = self
            item.representedObject = unit.rawValue
            fanUnitMenu.addItem(item)
        }
        fanUnitMenu.addItem(.separator())
        spinItem.target = self
        fanUnitMenu.addItem(spinItem)
        let fanUnitItem = NSMenuItem(title: "Show Fan As", action: nil, keyEquivalent: "")
        fanUnitItem.submenu = fanUnitMenu

        let menu = NSMenu()
        menu.delegate = self
        [averageItem, hottestItem, fanItem].forEach(menu.addItem)
        menu.addItem(.separator())
        menu.addItem(fanUnitItem)
        loginItem.target = self
        menu.addItem(loginItem)
        menu.addItem(NSMenuItem(title: "Quit FanTemp", action: #selector(NSApplication.terminate), keyEquivalent: "q"))
        statusItem.menu = menu

        if let button = statusItem.button {
            fanOverlay.frame = button.bounds
            button.addSubview(fanOverlay)
        }

        refresh()
        // Common mode keeps the values updating while the menu is open.
        let timer = Timer(timeInterval: 2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        RunLoop.main.add(timer, forMode: .common)
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        rpmItem.state = fanUnit == .rpm ? .on : .off
        percentItem.state = fanUnit == .percent ? .on : .off
        spinItem.state = spinsFan ? .on : .off
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
    }

    private func refresh() {
        reading = sensors?.read()
        showReading()
    }

    private func showReading() {
        let average = Self.celsius(reading?.cpuAverage)
        averageItem.title = "CPU average  \(average)"
        hottestItem.title = "CPU hottest core  \(Self.celsius(reading?.cpuHottest))"
        fanItem.title = "Fan  \(Self.rpm(reading?.fan))  (\(Self.percent(reading?.fan)) of max)"

        let status = switch fanUnit {
        case .rpm: StatusImage.make(top: average, bottom: Self.rpm(reading?.fan))
        case .percent: StatusImage.make(top: average, bottom: Self.percent(reading?.fan), reservesFan: true)
        }
        statusItem.button?.image = status.image
        fanOverlay.place(status.fanFrame, inImageOf: status.image.size)
        fanOverlay.spin(turnsPerSecond: spinTurnsPerSecond())
    }

    /// Up to 1.5 turns a second at full fan speed, in 10% steps so small rpm changes don't restart the animation.
    private func spinTurnsPerSecond() -> Double? {
        guard fanUnit == .percent, spinsFan, let fan = reading?.fan else { return nil }

        let turns = (min(fan.percentOfMax, 100) / 10).rounded() / 10 * 1.5
        return turns > 0 ? turns : nil
    }

    @objc private func selectFanUnit(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String, let unit = FanUnit(rawValue: rawValue) else { return }
        fanUnit = unit
    }

    @objc private func toggleSpin() {
        spinsFan.toggle()
    }

    @objc private func toggleOpenAtLogin() {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled {
                try service.unregister()
            } else {
                try service.register()
            }
        } catch {
            NSAlert(error: error).runModal()
        }
    }

    private static func celsius(_ value: Double?) -> String {
        value.map { "\(Int($0.rounded()))°C" } ?? "--°C"
    }

    private static func rpm(_ fan: Fan?) -> String {
        fan.map { "\(Int($0.rpm.rounded())) rpm" } ?? "-- rpm"
    }

    private static func percent(_ fan: Fan?) -> String {
        fan.map { "\(Int($0.percentOfMax.rounded()))%" } ?? "--%"
    }
}
