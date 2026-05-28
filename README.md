# FClash Plus

> [中文说明 / Chinese README](./README_zh_CN.md)

A macOS-only modification of [FlClash](https://github.com/chen08209/FlClash) with quality-of-life improvements to the system tray menu.

---

## Credits & Base

This project is built on top of **[FlClash](https://github.com/chen08209/FlClash)** by [chen08209](https://github.com/chen08209) — a multi-platform proxy client based on ClashMeta. All credit for the core functionality goes to the original author.

- **Base version**: FlClash `v0.8.92`
- **Core (`FlClashCore`)**: unmodified — the prebuilt macOS binary from upstream is reused as-is
- **Scope**: macOS only. Android / Windows / Linux / iOS sources have been removed. Personal-use fork.

---

## What's Changed

All changes are confined to the macOS system tray menu (`lib/common/tray.dart`, `lib/manager/tray_manager.dart`, and the embedded `plugins/tray_manager` plugin's macOS side).

### New
- **Delay badges** — proxy items now show a colored badge for the last measured delay:
  - 🟢 **Green** for `< 200ms`
  - 🟠 **Orange** for `200–499ms`
  - 🔴 **Red** for `≥ 500ms` or failed tests
- **Selected checkmark** — the currently selected proxy in each group shows a `✓` next to its name.
- **Group submenu label** — group submenus show the currently selected proxy on the right side of the group name (`GroupName       SelectedProxy`).
- **In-progress indicator** — clicking "Delay Test" on a group immediately replaces every proxy's badge with `...` until results come back, so you can tell the test has started.

### Renamed
- `timeout` is now displayed as **`fail`** — shorter, fits a small badge better.

### Fixed
- **Proxy items with delay labels were unclickable.** The custom right-aligned `NSView` used to render `name\tdelay` swallowed mouse events. Now `mouseUp` is forwarded and selection works.
- **Tray menu closed itself after a delay test completed.** The old refresh path did `cancelContextMenu` → rebuild → `popUpContextMenu`, but the re-pop was unreliable on macOS. Now the menu stays open.
- **Clicks on already-displayed menu items broke after a background refresh.** Rebuilding the menu used to allocate fresh `MenuItem` ids, so the displayed `NSMenu`'s tags no longer matched. Now both layers preserve identity:
  - The plugin's Dart side **merges new menu data into the existing `_menu`** when the shape matches, keeping ids stable.
  - The macOS side **mutates existing `NSMenuItem` views in place** instead of recreating the menu, so badges visibly update on the open menu.

### Behavior
- The tray menu refreshes after every **user-initiated** delay test (from the tray or the dashboard). Background health-check emissions from the core are intentionally **not** listened to, so a good user-test result isn't overwritten seconds later by a transient core failure.

---

## Build

Requires Flutter (matching the `environment.sdk` in `pubspec.yaml`) and Xcode.

```bash
flutter build macos --release
```

Output: `build/macos/Build/Products/Release/FClash Plus.app`

A prebuilt DMG is attached to each [GitHub Release](https://github.com/zhangbaoshengrio/fclash-plus/releases).

The macOS core binary `libclash/macos/FlClashCore` ships in the repo — no Go toolchain needed for building the macOS app.

---

## TUN Mode Note

The first time you toggle TUN mode on, macOS will prompt for an admin password — it sets `setuid` on `FlClashCore` so the core can configure the `utun` interface. Same as upstream FlClash.

The bundle id was deliberately changed (`com.zhangbaosheng.fclash-plus`) so FClash Plus and the original FlClash can be installed side-by-side without conflicting over `LaunchServices` routing, preferences, or the `utun` device.

---

## License

Inherits from upstream FlClash — see [chen08209/FlClash](https://github.com/chen08209/FlClash) for the original license terms.

---

## Acknowledgements

Massive thanks to [chen08209](https://github.com/chen08209) for the excellent original work. This repo is just a small set of personal tweaks on top.
