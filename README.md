# FanTemp

A small menu bar app that shows the CPU temperature with the fan speed under it.

The top line is the average CPU core temperature. The bottom line is the fan speed, in rpm or as a percentage of the fan's maximum. In percentage mode a fan icon spins beside it, faster as the fan speeds up.

Click it for the average and hottest core, the fan's rpm and percentage, and these options:

- **Show Fan As**: RPM or Percentage of Max, and **Spin Fan Icon** to keep the icon still.
- **Open at Login**: start the app automatically.

Built and tested on an M5 MacBook Pro with macOS 26. A Mac without a fan shows `--` for the fan.

## Install

Needs Xcode or the Command Line Tools (`xcode-select --install`).

```bash
./build.sh
ditto build/FanTemp.app /Applications/FanTemp.app
open /Applications/FanTemp.app
```

The app is signed ad hoc. Run it from Applications so **Open at Login** keeps pointing at the same copy.

## Uninstall

Turn off **Open at Login**, choose **Quit FanTemp** from the menu and delete the app.

## How it works

The sensors are read from the System Management Controller through IOKit's `AppleSMC` user client: CPU core temperatures from the `Tp*` (performance) and `Te*` (efficiency) keys, and the fan from `F0Ac` (current rpm) and `F0Mx` (maximum rpm). The app reads them every 2 seconds. Apple doesn't document these keys, so another Mac model or a macOS update may need different ones.

The fan icon turns with a Core Animation rotation that the system renders, so the app only wakes for the 2-second reads and stays around 0.3% CPU.
