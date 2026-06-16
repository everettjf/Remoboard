# Repository Guidelines

## Project Structure & Module Organization
Remoboard is an iOS host app plus a keyboard extension with a shared C++ networking core.
- `remoboard/`: Host app UI, logic, and assets.
- `keyboard/`: Keyboard extension UI, channel implementations (HTTP/BLE), and localized strings.
- `shared/`: App-group shared settings (`KBSetting.*`).
- `tokamak/`: C++ networking stack and bundled web UI (`tokamak/bifrost/bifrost/http/site.bundle`).
- `Pods/`, `Podfile`: CocoaPods dependencies.
- `Remoboard.xcworkspace`: Primary Xcode workspace (use this, not the `.xcodeproj`).

## Build, Test, and Development Commands
- `pod install`: Install CocoaPods dependencies after cloning or when `Podfile` changes.
- `open Remoboard.xcworkspace`: Launch the workspace in Xcode.
- `xcodebuild -workspace Remoboard.xcworkspace -scheme Remoboard -sdk iphoneos build`: Command-line build for the host app.
- `xcodebuild -workspace Remoboard.xcworkspace -scheme RemoKeyboard -sdk iphoneos build`: Command-line build for the keyboard extension.

## Coding Style & Naming Conventions
- Objective-C/Objective-C++; use `.mm` when bridging into C++ (`tokamak/`).
- Follow existing Xcode formatting; keep imports grouped (frameworks first, then locals).
- Use the localization helpers (`ttt`, `ttt_zhcn`) and update both `keyboard/en.lproj` and `keyboard/zh-Hans.lproj`.
- Shared settings must go through `shared/KBSetting.*` (App Group `group.everettjf.remoboard`).

## Testing Guidelines
There are no automated tests in the repo. Manual checks are required:
- Build and run both `Remoboard` and `RemoKeyboard` on a physical device.
- Verify HTTP mode shows a URL (port 7777) and browser input injects text.
- Switch HTTP/BLE modes and confirm the selection persists.
- Add/edit quick words and confirm they appear in the keyboard.

## Commit & Pull Request Guidelines
- Commit messages in history are short, lowercase summaries (e.g., “update readme”, “deprecate bluetooth mode”). Follow that style.
- Keep PRs narrowly scoped; describe user impact and manual test steps.
- Update docs (`README.md`, `AGENT.md`, or this file) when behavior changes.
- Avoid dependency upgrades unless the full build is verified on current Xcode/iOS SDKs.

## Configuration Notes
- Keyboard extensions are limited in the simulator; use a real device.
- Enable “Allow Full Access” for HTTP/BLE communication to work.

## More Apps
- See https://xnu.app for other apps.
