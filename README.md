# Remoboard — Remote Input Method

Remoboard (远程输入法) lets you type on your computer and instantly input the text on your phone through a custom keyboard extension, a browser-based UI, and Bluetooth/HTTP bridges. Launch the mobile app, note the URL that appears on the device, visit that address from your desktop browser, and whatever you type is delivered to the phone for fast, seamless input.

Project website: https://xnu.app/remoboard

## Badges
[![Platform](https://img.shields.io/badge/platform-iOS%20%26%20Android-blue.svg)](#installation)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Xcode](https://img.shields.io/badge/Xcode-12%2B-informational.svg)](#development)

## Table of Contents
- [Features](#features)
- [Quick Start](#quick-start)
- [Installation](#installation)
- [Usage](#usage)
- [Configuration](#configuration)
- [Examples](#examples)
- [Development](#development)
- [Roadmap / Project Status](#roadmap--project-status)
- [Contributing](#contributing)
- [License](#license)
- [Acknowledgements](#acknowledgements)
- [Star History](#star-history)

## Features
- **Remote desktop typing**: Use any computer browser to access the on-device URL (e.g., `http://<device-ip>:7777`) that the Remoboard app shows and mirror your typing straight into the phone.
- **Multiple connection modes**: Choose between the built-in HTTP server (recommended), Bluetooth Low Energy peripheral mode, or the legacy IP connection code depending on your network constraints.
- **Custom keyboard extension**: Remoboard ships with the `RemoKeyboard` extension so typed content can be inserted inside any app after you enable the keyboard in iOS settings and grant Full Access.
- **Quick Words and templates**: Maintain a list of reusable phrases, edit them from the host app, and trigger them quickly from the keyboard.
- **Test input experience**: The host app includes a dedicated testing view for validating remote input without switching apps.
- **Bilingual interface**: Localizations for English and Simplified Chinese are included out of the box.
- **Free mobile apps**: Both the iOS and Android releases remain free to download for end users.

## Quick Start
1. Install the Remoboard mobile app from the [App Store](https://apps.apple.com/us/app/id1474458879) (Android builds are distributed for free as well via the official channels).
2. On iOS, go to Settings → General → Keyboard → Keyboards → Add New Keyboard… → select **Remoboard**, then tap it again and enable **Allow Full Access** so the keyboard can communicate over the network.
3. Open the Remoboard app, pick the stable Web (HTTP) connection mode, and wait for the device to display an address such as `http://192.168.x.x:7777`.
4. From your computer, visit the displayed URL in a browser, start typing, and watch the text arrive on the phone in real time.

## Installation
### From official stores
- iOS: Install directly from the [App Store listing](https://apps.apple.com/us/app/id1474458879). The app is free and already satisfies the initial product goals.
- Android: The Android build is also free of charge. Follow the official distribution channels linked from https://xnu.app/remoboard.

### From source
1. Clone the repository and install dependencies:
   ```bash
   git clone https://github.com/everettjf/Remoboard.git
   cd Remoboard
   sudo gem install cocoapods   # if CocoaPods is not installed
   pod install
   ```
2. Open `Remoboard.xcworkspace` in Xcode (the workspace wires the `Remoboard` host app with the `RemoKeyboard` extension and CocoaPods).
3. Select the desired scheme (`Remoboard` or `RemoKeyboard`) and run on an iOS 12+ device. Remote input requires a real device because keyboard extensions are not fully supported in the simulator.

## Usage
- **Enable the keyboard**: After installation, add Remoboard as a system keyboard and allow Full Access. Without this permission the keyboard cannot open the embedded HTTP server or Bluetooth peripheral.
- **Choose a connection mode**: The app’s “More → Connection Mode” item lets you pick HTTP (web), Bluetooth, or the IP connection code. Due to differences in networks and firewalls, the HTTP web connection mode is generally the most stable and is recommended in almost every environment.
- **Start typing from the desktop**: Remoboard exposes a lightweight website from `site.bundle` inside the app on port `7777`. Type inside the browser, and the text is relayed to the phone keyboard immediately.
- **Bluetooth peripheral mode**: Advertise the phone as a BLE peripheral and pair from the desktop helper (when implemented) to push text messages. Status indicators in the app show when the peripheral is ready and connected.
- **Quick Words**: Use the “Quick Words” manager to edit your frequently typed phrases. They sync to the keyboard extension via `KBSetting` so you can insert them with one tap.
- **Test Input**: Open the “Test Input” screen to validate connectivity before switching to another app.

## Configuration
These are the user-facing knobs surfaced through `KBSetting` and the host app:
- **Connection mode** (`HTTP`, `Bluetooth`, or legacy `IP connection code`): defines how text is transported. The setting persists across launches.
- **HTTP server port**: Fixed at `7777`. The app lists all detected IP addresses (Wi-Fi, cellular, tethering) and copies the primary URL for convenience.
- **Quick words list**: Stored on device and editable through the host app. Use the reset option if you want to restore the default phrases shipped with the app.
- **Full Access requirement**: iOS requires Full Access for keyboards that use the network. If you disable it, remote typing and synchronization features stop working.
- **Experimental Lab features**: Some older lab features remain in the UI but are not maintained and are no longer recommended for day-to-day use.

## Examples
- **HTTP mode over Wi-Fi**
  1. Launch the Remoboard app on your phone, make sure it is on the same Wi-Fi network as your computer, and select HTTP mode.
  2. Copy the shown address (e.g., `http://10.0.0.8:7777`).
  3. Enter the address in your desktop browser, type text into the page, and confirm it arrives in the text field on the phone.
- **Editing Quick Words**
  1. In the app, navigate to **Manage → Quick Words**.
  2. Tap `+` to add a new phrase or select an existing one to edit it.
  3. Switch to the Remoboard keyboard inside any app and insert the saved phrases with one tap.

## Development
- **Prerequisites**: macOS with Xcode 12+, CocoaPods, and a connected iOS device running iOS 12 or newer.
- **Dependencies**: Managed through the `Podfile` (`Masonry`, `Toast`, `SCLAlertView-Objective-C`, `NSAttributedString-DDHTML`). `third_party/boost_1_70_0` and `tokamak` provide shared logic for the HTTP/BLE bridges.
- **Workspace layout**:
  - `remoboard/` contains the host app source (controllers, utilities, quick word manager).
  - `keyboard/` holds the custom keyboard extension (views, channel services, localized strings).
  - `shared/` stores settings helpers shared between targets.
  - `tokamak/` includes cross-platform networking logic (Bifrost HTTP server, BLE definitions).
- **Running**: Use `pod install`, open `Remoboard.xcworkspace`, choose the `Remoboard` scheme, and run on device. To debug the keyboard extension, select `RemoKeyboard` and attach it to the keyboard host process following Xcode’s extension debugging workflow.
- **Testing & QA**: No automated test targets are defined. Manually verify both the host app screens and the keyboard extension, especially connection stability and quick word synchronization.
- **Lint/format**: Stick to the Objective-C/Objective-C++ style that Xcode generates (spaces, pragma marks, etc.). There is no dedicated linting script, so run `clang-format` locally if you make large stylistic changes.

## Roadmap / Project Status
1. The software already satisfies its original design goals, and there are currently no plans to continue optimizing or expanding it.
2. The iOS and Android editions are fully available as free downloads. Thank you for the continued support!
3. Because every network is different, a minority of environments cannot establish a connection. The Web/HTTP connection mode is comparatively more stable. Experimental “Lab” functions are not scheduled for further updates and are not recommended for use.

## Contributing
Contributions are welcome even though the core roadmap is stable. Please:
- Discuss major ideas in issues first so expectations stay aligned.
- Keep pull requests small, focused, and well-described. Avoid unrelated refactors.
- Update documentation (README.md, AGENT.md, localized strings) whenever UI or behavior changes.
- Verify the host app and keyboard extension manually before submitting.

## License
Remoboard is released under the [MIT License](LICENSE).

## Acknowledgements
- Featured in [「最美应用」 (Chinese)](https://mp.weixin.qq.com/s/PLWkVuEdJCk6cLGEQVZDbw) and [「少数派」 (Chinese)](https://sspai.com/post/57008).
- Follow the WeChat subscription account “首先很有趣” (translates to “Fun First”) to keep up with future experiments and ideas from the author.
- Thank you to everyone who has supported the project since its launch.


## Star History

[![Star History Chart](https://api.star-history.com/svg?repos=everettjf/Remoboard&type=Date)](https://star-history.com/#everettjf/Remoboard&Date)
