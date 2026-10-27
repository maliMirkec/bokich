# Bokich: Build Plan

A tiny macOS buddy that keeps you on your current Space when you quit an app.

- App name: **Bokich**
- Character name: **Bokić**

---

## 1. Problem

macOS has one setting:
"When switching to an application, switch to a Space with open windows for the application".

- On: Cmd+Tab works well. But quitting an app can jump you to another Space.
- Off: no jumps. But Cmd+Tab no longer moves you to the app's Space.

You can't have both. Bokich fixes the quit case. Keep the setting **on**.

## 2. How it works

1. Catch Cmd+Q before the app gets it.
2. Find the next real window on the current Space.
3. Focus that window. If there is none, hold the Space with an anchor (see 7.5).
4. Quit the app.
5. macOS has something on this Space to stay with. No jump.
6. Bokić winks.

Bokić lives on all Spaces. It is the visible buddy, not the focus target.

### Lessons from testing

- Focusing Bokić does not stop the jump. macOS ignores desktop-level and all-Spaces windows.
- An `LSUIElement` app never owns the menu bar. When the quitting app was the menu bar owner, macOS hands it to the next regular app and jumps to its Space.
- Fix: briefly turn Bokich into a regular app, with a tiny window on this Space.

---

## 3. Tech stack

- Swift 5.9+
- AppKit and Core Animation (no SwiftUI needed)
- Swift Package Manager (works well in VS Code)
- macOS 13+ (needed for `SMAppService` login item)

### VS Code setup

- Install Xcode Command Line Tools: `xcode-select --install`
- Install the **Swift** extension (by the Swift Server Work Group).
- Optional: **CodeLLDB** for debugging.

---

## 4. Project layout

```
Bokich/
  Package.swift
  Info.plist
  build.sh
  PLAN.md
  Sources/
    Bokich/
      main.swift
      AppDelegate.swift
      Settings.swift
      Permissions.swift
      StatusMenu.swift
      Quit/
        QuitInterceptor.swift
        WindowFinder.swift
        WindowFocuser.swift
      Buddy/
        BuddyWindow.swift
        BuddyView.swift
        BlobShape.swift
        FaceLayer.swift
        Expressions.swift
        Reactions.swift
        GreetingBubble.swift
        Greetings.swift
        Palette.swift
      Contrast/
        WallpaperSampler.swift
        ContrastStyle.swift
```

---

## 5. Build files

### Package.swift

```swift
// swift-tools-version:5.9
import PackageDescription

let package = Package(
  name: "Bokich",
  platforms: [.macOS(.v13)],
  targets: [
    .executableTarget(
      name: "Bokich",
      path: "Sources/Bokich"
    )
  ]
)
```

### Info.plist

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key>
  <string>Bokich</string>
  <key>CFBundleDisplayName</key>
  <string>Bokich</string>
  <key>CFBundleIdentifier</key>
  <string>codes.silvestar.bokich</string>
  <key>CFBundleExecutable</key>
  <string>Bokich</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>LSUIElement</key>
  <true/>
</dict>
</plist>
```

`LSUIElement` hides the app from the Dock and Cmd+Tab.

### build.sh

```bash
#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
SIGN_ID="${SIGN_ID:--}"
APP="build/Bokich.app"
swift build -c release
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/Bokich "$APP/Contents/MacOS/Bokich"
cp Info.plist "$APP/Contents/Info.plist"
codesign --force --sign "$SIGN_ID" "$APP"
echo "Built $APP"
```

Run:

```bash
chmod +x build.sh
SIGN_ID="Bokich Dev" ./build.sh
open build/Bokich.app
```

### Stable signing (important)

Ad-hoc signing (`-`) changes the app's identity on every build. macOS then forgets the Accessibility permission. Fix it once:

1. Open **Keychain Access**.
2. Menu: **Keychain Access → Certificate Assistant → Create a Certificate**.
3. Name: `Bokich Dev`. Type: **Self Signed Root**. Certificate type: **Code Signing**.
4. Build with `SIGN_ID="Bokich Dev" ./build.sh`.

Now the permission survives rebuilds.

---

## 6. Permissions

Only **Accessibility** is needed. It's used to:

- Catch Cmd+Q (event tap).
- Focus another app's window.

No Screen Recording. No network.

### Permissions.swift

- On launch, call `AXIsProcessTrustedWithOptions` with the prompt option.
- Listen for the distributed notification `com.apple.accessibility.api`. It fires when the Accessibility list changes. Check 0.5 s later, since the value updates with a delay.
- Backup timer: every 2 s while waiting for access, every 30 s once trusted. 20% tolerance, so macOS can group wakeups.
- When access is granted, start `QuitInterceptor`.
- When access is revoked, stop the tap right away. A stale tap can block keyboard input.
- On every change, refresh the menu bar icon:
  - No access: a small "!" badge on the icon, and the tooltip "Bokich needs Accessibility access".
- Show state in the menu: "Needs Accessibility access" item that opens:
  `x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility`

---

## 7. Quit flow

### 7.1 QuitInterceptor.swift

Uses a `CGEvent` tap on key down events.

Rules:

- Key code `12` (Q) with **only** Cmd held. Ignore Shift, Option, Control combos.
- Swallow key repeats (`keyboardEventAutorepeat != 0`). Return `nil`.
- Skip if frontmost app is:
  - Finder (`com.apple.finder`). Finder doesn't quit.
  - Bokich itself.
- Otherwise:
  - Return `nil` to swallow the event.
  - Run the quit flow on the main queue (async).

Tap must stay fast. Never do work inside the callback.

The tap runs on its own thread (`Bokich.QuitTap`) with its own run loop. If it ran on the main thread, a busy main thread could make macOS disable the tap. Then Cmd+Q reaches the app. Chromium browsers then show "Hold ⌘Q to quit" and cancel the quit.

After `terminate()`, wait 2 s. If the app still runs, call `terminate()` once more. Apps with a save dialog keep the dialog.

Handle tap shutdown:
- If type is `.tapDisabledByTimeout` or `.tapDisabledByUserInput`, re-enable the tap.

Respect the menu toggle:
- If Bokich is disabled, pass the event through.

### 7.1b CloseQuitters.swift

Some apps quit when their last window closes, like System Settings and Calculator. For them, Cmd+W on the last window is a quit.

- Key code `13` (W) with only Cmd held.
- Handle it like Cmd+Q only when:
  - the app is in `Settings.closeQuitters`, and
  - AX shows exactly one window. The AX timeout is 0.2 s to keep the tap fast.
- Otherwise pass it through and note the pid and time.
- Learning: if an app terminates within 1.5 s of a passed Cmd+W, add its bundle ID to `closeQuitters`.
- Seed list: `com.apple.systempreferences`, `com.apple.calculator`.
- Other apps keep normal Cmd+W. They stay active after closing the last window, so no jump.

### 7.2 Quit flow steps

```
quit(app):
  target = WindowFinder.next(excluding: app.pid, preferScreenOf: app)
  if target != nil:
    WindowFocuser.focus(target)
  else:
    SpaceAnchor.hold()
  wait until target (or Bokich) is frontmost, max 300 ms
  after 50 ms:
    app.terminate()
  Buddy.wink()
```

- `terminate()` is a normal quit. Apps still ask to save unsaved work.
- If the user cancels the save dialog, the app stays open. That's fine.

### 7.3 WindowFinder.swift

Uses `CGWindowListCopyWindowInfo` with `[.optionOnScreenOnly, .excludeDesktopElements]`.

Returns windows front to back, on current Spaces only.

Keep a window if:

- `kCGWindowLayer == 0` (normal windows). This also skips Bokić, which is on a lower layer.
- Owner PID is not the quitting app.
- Owner PID is not Bokich.
- `kCGWindowAlpha > 0`.
- Width and height > 50 px.
- Owner app has `.regular` activation policy.

Multi-display:

- Get the screen of the quitting app's front window.
- Prefer windows on that screen.
- If none, take any match.

Return `(pid, windowID)`.

### 7.4 WindowFocuser.swift

Uses the Accessibility API.

```swift
@_silgen_name("_AXUIElementGetWindow")
func _AXUIElementGetWindow(_ element: AXUIElement, _ id: UnsafeMutablePointer<CGWindowID>) -> AXError
```

Steps:

1. `AXUIElementCreateApplication(pid)`.
2. Read `kAXWindowsAttribute`.
3. Find the window whose ID matches (via `_AXUIElementGetWindow`).
4. Set `kAXMainAttribute` to true.
5. Perform `kAXRaiseAction`.
6. Set app `kAXFrontmostAttribute` to true.

`_AXUIElementGetWindow` is a private API. It's stable and widely used (AltTab, Rectangle). Fine for a personal app. Not allowed on the Mac App Store.

`focusApp(pid)` sets `kAXFrontmostAttribute` on any app, on a background queue. Used for Bokich itself too, since `NSApp.activate` is unreliable from the background.

### 7.4b FullScreen.swift

A full-screen app has its own Space. Quitting it deletes that Space, and macOS lands on the first Space.

Fix:

1. Read the focused window's `AXFullScreen` attribute.
2. If true, set it to false. The window moves back to its original Space.
3. Wait for `activeSpaceDidChangeNotification` (max 2 s), then 0.3 s more.
4. Run the normal quit flow.

### 7.5 SpaceAnchor.swift

Used when no other window is on the Space.

Where: the center of the quitting app's display. `WindowFinder.next` returns that display. If the app had no windows, use the display under the mouse. Never use Bokić's display, since it can be another screen.

`hold(at:)`:

1. Create a 1 × 1 clear borderless `NSWindow`, normal level, no all-Spaces flag, ignores mouse.
2. `NSApp.setActivationPolicy(.regular)`. Bokich now owns the menu bar.
3. Activate Bokich, make the window key, `focusApp(getpid())`.
4. Watch `NSApplication.didResignActiveNotification`.

`release()` (on resign active):

1. Remove the window.
2. `NSApp.setActivationPolicy(.accessory)`.

Side effect: a Bokich Dock icon shows until you switch apps. It uses the static app icon.

---

## 8. Bokić window

### 8.1 BuddyWindow.swift

Subclass `NSPanel`.

Settings:

| Property | Value |
| --- | --- |
| Style | `.borderless`, `.nonactivatingPanel` off |
| Background | `.clear`, `isOpaque = false` |
| Shadow | `hasShadow = false` (we draw our own) |
| Level | `CGWindowLevelForKey(.desktopIconWindow) + 1` |
| Collection behavior | `.canJoinAllSpaces`, `.stationary`, `.ignoresCycle`, `.fullScreenAuxiliary` |
| Size | 44 × 44 pt (28 pt blob plus room for shadow and morph) |
| `canBecomeKey` | override to `true` |
| `canBecomeMain` | override to `false` |
| `hidesOnDeactivate` | `false` |

Why this level:

- Above desktop icons, so it's clickable.
- Below every normal window. Never covers Chrome buttons or anything else.
- You see it only where the corner is clear.

### 8.2 Position

Default: top right of the main screen's `visibleFrame`.
- 12 pt from the right edge.
- 8 pt below the menu bar.

Save position as:

- Screen ID (`NSScreenNumber` from `deviceDescription`).
- Offset from that screen's top-right corner.

Offset from top right keeps Bokić in place when screen size changes.

On launch and on `NSApplication.didChangeScreenParametersNotification`:

1. Find the saved screen. If gone, use main screen.
2. Apply offset.
3. Clamp into `visibleFrame`.

### 8.3 Drag vs click

Handle in `BuddyView`:

- `mouseDown`: store start point.
- `mouseDragged`: if moved > 3 pt, start drag. Move the window with the mouse.
- `mouseUp`:
  - If dragged: save position, resample wallpaper.
  - Else: it's a click. Run a reaction.

Small squish on drag start. Settle bounce on drop.

---

## 9. Blob

### 9.1 BlobShape.swift

A blob is a closed smooth curve through N points around a circle.

Data:

```swift
struct BlobShape: Codable {
  var radii: [CGFloat]
  var angleJitter: [CGFloat]
  var colorIndex: Int
}
```

Generation:

- `N = 7` points. Keep N fixed so morphs are smooth.
- Base angle per point: `i * 2π / N`.
- Angle jitter: random in `±0.25 * (2π / N)`.
- Radius: `baseRadius * random(0.82...1.05)`.
- Avoid the same color twice in a row.

Path:

- Use closed **Catmull-Rom** through the points.
- Convert each segment to a cubic Bézier:
  - `c1 = p1 + (p2 - p0) / 6 * tension`
  - `c2 = p2 - (p3 - p1) / 6 * tension`
- `tension = 1.0`. Lower gives tighter curves.
- Build a `CGPath`.

Same N points and same command order every time. Core Animation can then morph between any two blobs.

### 9.2 Rendering

`BuddyView` layer tree:

```
rootLayer
  shadowLayer   (CAShapeLayer, blob path, shadow only)
  blobLayer     (CAShapeLayer, fill + stroke)
  faceLayer     (CALayer)
    leftEye
    rightEye
    mouth
```

- Vector paths. Crisp on Retina.
- Set `contentsScale` to the screen's `backingScaleFactor`.

### 9.3 Morph on click

- New `BlobShape`.
- Animate `path` on `blobLayer` and `shadowLayer`.
- Animate `fillColor`.
- Use `CASpringAnimation`: damping 12, stiffness 180, about 0.5 s.
- Save the new shape to settings.

### 9.4 Persistence

Save `BlobShape` as JSON in `UserDefaults`. On launch, load it. If missing, generate one.

---

## 10. Palette

### Palette.swift

Each swatch is a blob color plus a face color.

| Blob | Face | Contrast |
| --- | --- | --- |
| `#FFD6A5` peach | `#161616` ink | high |
| `#FDFFB6` lemon | ink | high |
| `#CAFFBF` mint | ink | high |
| `#9BF6FF` sky | ink | high |
| `#A0C4FF` blue | ink | high |
| `#BDB2FF` lavender | ink | high |
| `#FFC6FF` pink | ink | high |
| `#FFADAD` coral | ink | high |
| `#4F4A85` indigo | peach | 5.8 |
| `#355C7D` slate | lemon | 6.8 |
| `#356B55` sage | mint | 5.5 |
| `#7D3F5C` berry | mint | 6.8 |
| `#245E63` teal | peach | 5.4 |
| `#6A3F7E` plum | lemon | 7.7 |
| `#7A4B3A` cocoa | sky | 5.9 |

Rules:

- Dark blobs take a light pastel face from the palette, never white.
- Every face has a contrast of at least 4.5 against its blob.
- New swatches go at the end. Saved shapes store the swatch index.
- A blob is light when its luminance is above 0.3. This picks the shadow.

Add a small `NSColor(hex:)` extension.

---

## 11. Face and expressions

### FaceLayer.swift

- Two eyes: small ovals.
- Mouth: a curve.
- Face centered on the blob's center, not on the path.

### Expressions.swift

```swift
enum Expression {
  case idle
  case blink
  case wink
  case surprised
  case tongueOut
  case happySquint
  case sleepy
  case sad
}
```

Each expression sets eye and mouth paths. Animate between them like the blob.

### Idle

- Blink every 3–7 s (random).
- Blink: scale eyes Y to 0.1 and back, 0.15 s.
- After 10 min with no clicks: `sleepy`. Wake on click.

### Wink

- Triggered after each intercepted Cmd+Q.
- Left eye closes, mouth smiles, 0.6 s.
- If Bokić is hidden behind windows, the wink still runs. No harm.

---

## 12. Reactions on click

### Reactions.swift

Every click:

1. Morph to new blob shape and color (always).
2. Plus one random extra:
   - 50%: greeting bubble.
   - 35%: face (wink, surprised, tongue out, happy squint).
   - 15%: squish and bounce.

Avoid the same greeting or face twice in a row.

### 12.1 Greeting bubble

### GreetingBubble.swift

- Separate small borderless `NSPanel`.
- Same level and behavior as Bokić.
- Rounded rect with a small tail pointing at Bokić.
- Text: system font, 12 pt.
- Placement:
  - Prefer left of Bokić.
  - If not enough room, below.
  - Flip as needed near screen edges.
- Fade in 0.15 s. Stay 1.8 s. Fade out 0.2 s.
- A new click replaces the old bubble.

### Greetings.swift

```swift
enum Greetings {
  static let all: [String] = [
    "Pozdrav 🇭🇷",
    "Bok 🇭🇷",
    "Bokić 🇭🇷",
    "Hallo 🇩🇪",
    "Ciao 🇮🇹",
    "Hola 🇪🇸",
    "Bonjour 🇫🇷",
    "Olá 🇵🇹",
    "Hej 🇸🇪",
    "Ahoj 🇨🇿",
    "Cześć 🇵🇱",
    "Szia 🇭🇺",
    "Merhaba 🇹🇷",
    "Γεια σου 🇬🇷",
    "こんにちは 🇯🇵",
    "안녕하세요 🇰🇷",
    "你好 🇨🇳",
    "Namaste 🇮🇳",
    "Salaam 🇮🇷",
    "Jambo 🇰🇪",
    "Kia ora 🇳🇿",
    "Aloha 🇺🇸",
    "Hello 🇬🇧"
  ]
}
```

---

## 13. Auto contrast

Bokić sits on the bottom layer. Only the wallpaper is behind it.

### 13.1 WallpaperSampler.swift

Inputs:

- `NSWorkspace.shared.desktopImageURL(for: screen)`
- `NSWorkspace.shared.desktopImageOptions(for: screen)`
  - `.imageScaling`
  - `.allowClipping`
  - `.fillColor`
- Bokić's frame in screen coordinates.

Steps:

1. If URL is a folder, a video, or a multi-image HEIC (dynamic), return `nil` (fallback).
   - Check with `CGImageSourceGetCount(source) > 1`.
2. Load the first image with `CGImageSource`. Downscale to max 512 px for speed.
3. Map the screen rect to image pixels, based on scaling mode:
   - `scaleProportionallyUpOrDown` + clipping: **fill** (scale to cover, crop center).
   - `scaleProportionallyUpOrDown`, no clipping: **fit** (letterbox with fill color).
   - `scaleAxesIndependently`: **stretch**.
   - `scaleNone`: **center** (outside area is fill color).
4. Crop that region, expanded by 8 pt.
5. Draw it into a 1 × 1 bitmap. That gives the average color.
6. Return the color.

Cache: URL + options + screen + Bokić frame. Skip work if nothing changed.

### 13.2 ContrastStyle.swift

Relative luminance (WCAG):

```
L = 0.2126 R + 0.7152 G + 0.0722 B   (on linearized RGB)
```

The border follows the wallpaper:

| Background | Border |
| --- | --- |
| Light (L > 0.5) | black, 35% alpha, 1 pt |
| Dark (L ≤ 0.5) | white, 60% alpha, 1 pt |
| Fallback (unknown) | black, 40% alpha, 1 pt |

The shadow follows the blob color:

| Blob | Shadow |
| --- | --- |
| Light (L > 0.3) | black, 35% alpha, radius 4, offset (0, -1) |
| Dark (L ≤ 0.3) | white, 45% alpha, radius 5, offset 0 (glow) |

Extra rule:

- Compute contrast ratio between blob color and background.
- If ratio < 1.5, set border width to 2 pt.

Apply style with a 0.3 s fade.

### 13.3 When to resample

- On launch.
- `NSWorkspace.activeSpaceDidChangeNotification` (each Space can have its own wallpaper).
- `NSApplication.didChangeScreenParametersNotification`.
- After drag ends.
- After light/dark mode changes (`AppleInterfaceThemeChangedNotification` via `DistributedNotificationCenter`).
- Every 5 s, compare wallpaper URL and options. Resample only if changed. macOS has no public "wallpaper changed" notification.

---

## 14. Menu bar

### StatusMenu.swift

- Icon: tiny blob outline with a face, drawn as a template image (black on clear). macOS tints it for light and dark.
  - Enabled: happy face.
  - Disabled: sad face, dimmed. Tooltip says "Bokich (off)".
- Items:
  - **Enabled** (checkmark, shows the current shortcut)
  - **Change Shortcut…**
  - **Show Bokić** (checkmark). Hides the buddy but keeps the quit fix.
  - **Reset Bokić Position**
  - **Launch at Login** (checkmark, `SMAppService.mainApp`)
  - **Needs Accessibility Access…** (only when not trusted)
  - separator
  - **About Bokich**: standard About panel. Icon, version, copyright, MIT License, and a silvestar.codes link.
  - **Made by Silvestar Bistrović**: opens https://www.silvestar.codes.
  - separator
  - **Quit Bokich**

### HotKey.swift and Shortcut.swift

- Global shortcut toggles Enabled. Default ⌃⌥⌘0.
- Uses Carbon `RegisterEventHotKey`. It needs no Accessibility access.
- `Settings.shortcut` stores key code, modifiers, and the key character. `nil` means off.
- `ShortcutController` registers it and re-registers after a change.
- On toggle, Bokić reacts if visible:
  - On: happy squint and a "Bokich on" bubble.
  - Off: a "Bokich off" bubble.
- While off, Bokić keeps a sad face. Clicks still morph and greet, but the face stays sad. It doesn't get sleepy.

### ShortcutRecorder.swift

Menu item **Change Shortcut…** opens a small panel.

- The current shortcut is paused while the panel is open.
- Press a new combo. It must include ⌃ or ⌥.
- Esc or Cancel keeps the old shortcut.
- **Use ⌃⌥⌘0** restores the default. **Turn Off** removes the shortcut.
- If registration fails, show "That shortcut is taken" and keep the panel open.
- The Enabled menu item shows the current shortcut.

---

## 15. Settings

### Settings.swift

`UserDefaults` keys:

| Key | Type |
| --- | --- |
| `enabled` | Bool |
| `showBuddy` | Bool |
| `blobShape` | Data (JSON) |
| `positionScreenID` | Int |
| `positionOffsetX` | Double |
| `positionOffsetY` | Double |

---

## 16. Build phases

Build in this order. Each phase ends with something you can test.

### Phase 1: Skeleton

- Package, Info.plist, build.sh, stable signing.
- Menu bar icon with Quit.
- **Check**: app runs, no Dock icon, menu works.

### Phase 2: Quit fix

- Permissions, QuitInterceptor, WindowFinder, WindowFocuser.
- Port logic from SpaceKeeper.
- **Check**: two Spaces, quit an app with Cmd+Q, you stay.

### Phase 3: Bokić window

- BuddyWindow with a plain circle.
- All Spaces, bottom layer, default position.
- SpaceAnchor fallback.
- **Check**: Bokić on every Space. Hidden behind windows. Quitting the last app on a Space doesn't jump.

### Phase 4: Blob

- BlobShape, rendering, morph on click, persistence.
- Palette.
- **Check**: click morphs smoothly. Shape survives restart.

### Phase 5: Face

- FaceLayer, expressions, blink, wink after quit.
- **Check**: blinks, winks on Cmd+Q.

### Phase 6: Drag

- Drag vs click, save position, clamp on screen change.
- **Check**: drag, restart, same spot. Unplug monitor, Bokić comes back.

### Phase 7: Reactions

- Greeting bubble, faces, squish.
- **Check**: random reactions, no repeats, bubble placement near edges.

### Phase 8: Contrast

- WallpaperSampler, ContrastStyle, resample triggers.
- **Check**: light wallpaper gives dark border. Dark wallpaper gives glow. Dynamic wallpaper uses fallback.

### Phase 9: Polish

- Launch at Login, Show Bokić toggle, Reset Position.
- Final test pass.

---

## 17. Test checklist

Quit flow:

- [ ] Quit with other windows on the Space: you stay, next window focused.
- [ ] Quit last app on a Space: you stay, Bokich active, Dock icon gone after switching apps.
- [ ] Quit app with unsaved work: save dialog appears.
- [ ] Cmd+Shift+Q and Cmd+Option+Q pass through untouched.
- [ ] Holding Cmd+Q quits once, not many times.
- [ ] Cmd+Q in Finder does nothing new.
- [ ] Full-screen app quit returns to a normal Space without a wrong jump.
- [ ] Two displays: focus stays on the same display.
- [ ] Bokich disabled: normal macOS behavior.

Bokić:

- [ ] Visible on every Space and full-screen Spaces.
- [ ] Never above normal windows.
- [ ] Not in Cmd+Tab, Dock, or Mission Control.
- [ ] Click morphs, color changes, reaction shows.
- [ ] Shape, color, and position survive restart.
- [ ] Drag works. Click after drag doesn't trigger a reaction.

Contrast:

- [ ] Light static wallpaper.
- [ ] Dark static wallpaper.
- [ ] Dynamic wallpaper (fallback).
- [ ] Different wallpaper per Space.
- [ ] Solid color wallpaper.

---

## 18. Known limits

- Only Cmd+Q, and Cmd+W in apps that quit on their last window, are covered. Quitting from the Dock or app menu can still jump.
- The first Cmd+W in a new app that quits on its last window can still jump. Bokich learns the app and handles the next one.
- Chrome's "Warn before quitting (⌘Q)" hold is bypassed. One press quits.
- Uses a private API (`_AXUIElementGetWindow`). Fine for personal use. Not App Store safe.
- Dynamic and video wallpapers use the fallback style.
- If the wallpaper file was moved, deleted, or sits in a protected folder (Desktop, Documents, Downloads), the fallback style is used.
- After quitting the last app on a Space, Bokich shows in the Dock until you switch apps.

---

## 19. Open items

- [x] Final color palette. Light and dark pastels.
- [x] Final greetings list.
- [x] Blob size: 28 pt.
- [x] Menu bar icon: template face.
- [x] Static `.icns` app icon. `Tools/MakeIcon.swift` draws it with the same Bean shape and face as the menu bar icon, in peach. `build.sh` redraws `Resources/AppIcon.icns` when it is missing or when the script changes. The Dock uses it too.
