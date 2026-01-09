# AGENT.md

Guidance for AI agents and contributors working in this repository. Follow these steps to keep Remoboard stable while improving documentation or code.

## Project Overview
Remoboard (远程输入法) is an iOS keyboard extension plus host app that lets users type on their computer and forward the text to their phone through a lightweight web interface or Bluetooth Low Energy bridge. The repository contains the Objective-C/Objective-C++ sources for the host app, the `RemoKeyboard` extension, and the shared C++ networking layer (`tokamak`). The released mobile apps for iOS and Android are free, and no large-scale new feature development is planned, but maintenance and doc improvements are welcome.

## Repository Map
- `Remoboard.xcworkspace` / `Remoboard.xcodeproj`: Xcode workspace that ties together the host app, keyboard extension, and CocoaPods.
- `remoboard/`: Host app (view controllers, quick word manager, onboarding helpers, localized assets).
  - `app/`: UIKit view controllers such as `ViewController`, `QuickWordsListViewController`, and test views.
  - `logic/`, `util/`: Shared Objective-C utilities (`AppMemoryData`, `AppUtil`, alerts, etc.).
- `keyboard/`: Custom keyboard extension target.
  - `channel/`: Channel abstractions with BLE (`BluetoothPeripheralManager`) and HTTP (`HttpServerManager`) implementations.
  - `view/`: Keyboard UI (`TinyKeyboardView`, `WordListView`).
  - `util/`, `en.lproj`, `zh-Hans.lproj`: Helpers and localized strings.
- `shared/KBSetting.*`: Shared app-group settings singleton (quick words, connection mode, app version).
- `tokamak/`: C++ networking core (Bifrost HTTP server, BLE definitions, token parsing) used by both targets.
- `third_party/boost_1_70_0`: Vendored Boost subset for the networking stack.
- `Pods/`, `Podfile`, `Podfile.lock`: CocoaPods dependencies (`Masonry`, `Toast`, `SCLAlertView-Objective-C`, etc.).

## Running the Project Locally
1. Install Xcode 12+ and CocoaPods (`sudo gem install cocoapods` if needed).
2. Clone and bootstrap:
   ```bash
   git clone https://github.com/everettjf/Remoboard.git
   cd Remoboard
   pod install
   ```
3. Open `Remoboard.xcworkspace` in Xcode. Always use the workspace so the pods load.
4. Select the `Remoboard` scheme and a physical iOS device running iOS 12+. Keyboard extensions are limited in the simulator, so a device is strongly recommended.
5. Run (`⌘R`). The host app launches; from there you can open the test input, manage quick words, and configure connection modes.
6. To debug the keyboard extension, switch the scheme to `RemoKeyboard`, set a hosting app (Settings or Remoboard), and follow Apple's extension debugging workflow (Xcode prompts you to choose the host when you run).
7. Enable the Remoboard keyboard in iOS Settings and grant **Allow Full Access** so HTTP/BLE communication works.

## Testing
- There are no automated unit/UI tests checked into the repo.
- Perform manual verification for every change:
  - Build both the `Remoboard` and `RemoKeyboard` schemes without warnings.
  - Open the host app, ensure the HTTP mode displays a valid URL (default port 7777), and confirm typing from the browser injects text into the phone.
  - Toggle the connection mode sheet (HTTP vs. Bluetooth) to ensure `KBSetting` persists the selection.
  - Edit quick words (add, edit, reset) and confirm they show up inside the keyboard extension.
  - Use the “Test Input” page to validate remote input without switching apps.
  - For BLE changes, watch the console logs inside `BluetoothPeripheralManager` to ensure advertising starts and status callbacks fire.

## Linting & Formatting
- No repository-wide formatter is configured. Default recommendation: follow Xcode’s Objective-C/Objective-C++ formatting (2-space indents in Interface Builder–generated files, spaces around operators, etc.).
- Run `clang-format` manually if you touch large `.mm` files to keep style consistent.
- Keep imports grouped (frameworks first, then local headers) and respect the existing `#pragma mark` regions where present.
- New localized strings must appear in both `en.lproj` and `zh-Hans.lproj` to keep the bilingual UI consistent.

## Build & Release
- Use the workspace (`Remoboard.xcworkspace`) with CocoaPods installed. Avoid editing the `.xcodeproj` directly.
- Command-line build example:
  ```bash
  xcodebuild -workspace Remoboard.xcworkspace \
    -scheme Remoboard \
    -configuration Release \
    -sdk iphoneos \
    build
  ```
- For releases, archive the `Remoboard` scheme via Xcode (`Product → Archive`) and export or upload as needed. Ensure the App Group (`group.everettjf.remoboard`) remains configured for both the app and extension so quick words synchronize.
- `tokamak/bifrost/bifrost/http/site.bundle` contains the static web UI served to desktops. Update it when changing the on-device website and add it to the Copy Bundle Resources build phase.
- `third_party/boost_1_70_0` is vendored; do not upgrade it without confirming Bifrost compiles on the targeted iOS SDK.

## Coding Style & Conventions
- Objective-C/Objective-C++ with camel-case class names and properties. Prefer `.mm` for files that bridge into the C++ networking layer.
- Use the localization helper macros (`ttt`, `ttt_zhcn`) for strings. Add new keys to both language files and keep keys descriptive (`title.quickwords`, etc.).
- Settings shared between the app and keyboard must go through `KBSetting` (App Group suite `group.everettjf.remoboard`). Do not bypass it with separate `NSUserDefaults`.
- Keep the HTTP server on port 7777 unless there is a compelling reason to change it; the browser UI and help text assume that value.
- Avoid expanding “Lab” or experimental sections unless explicitly requested; they are intentionally dormant.

## Debugging Tips
- HTTP issues: Set breakpoints or add logs inside `keyboard/channel/impl/HttpServerManager.mm` and `tokamak/bifrost/bifrost/http/httpserver.hpp`. Confirm the device reports valid IP addresses (watch the console output for `all ipv4 addresses`).
- BLE issues: Inspect `BluetoothPeripheralManager.mm`. Ensure Bluetooth is powered on and check the status callbacks (`onStatus`, `onReady`).
- Shared state: When quick words or connection modes do not persist, inspect `shared/KBSetting.mm` to ensure the App Group identifier matches your provisioning profile.
- Keyboard extension: Use Xcode’s “Attach to Process” to monitor the `RemoKeyboard` extension, and use the in-app “Test Input” to exercise text insertion without leaving Xcode.
- Static site: The served HTML/JS lives in `tokamak/bifrost/bifrost/http/site.bundle`. Use Safari dev tools when loading the on-device URL to troubleshoot UI issues.

## Rules for Making Changes
- Keep pull requests narrowly scoped (single feature/fix) and describe end-user impact plus manual test steps.
- Update documentation (README.md, AGENT.md, localized guides) whenever behavior changes.
- Preserve existing functionality: remote typing must continue to work over HTTP and BLE, quick words must sync, and the keyboard extension must remain stable.
- Do not remove localized strings or App Group identifiers. Add English and Simplified Chinese entries for all new user-facing text.
- Avoid upgrading third-party dependencies or Boost unless you validate the full build on current Xcode/iOS SDKs.

## PR Checklist
- [ ] `pod install` has been run and `Podfile.lock` is updated only if dependencies changed intentionally.
- [ ] `Remoboard` and `RemoKeyboard` schemes build and run on a physical iOS device without new warnings.
- [ ] Manual tests cover HTTP mode, connection switcher, Quick Words CRUD, and the Test Input view.
- [ ] Localized strings are updated in both `en.lproj` and `zh-Hans.lproj` when user-facing text changes.
- [ ] Documentation (README.md, AGENT.md, or additional guides) reflects new behavior or limitations.
- [ ] `git status` shows only the intended changes (no stray build artifacts or personal provisioning files).
