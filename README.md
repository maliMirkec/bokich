# Bokich

A tiny macOS buddy that keeps you on your current Space.

## Why Bokich

macOS has one setting: "When switching to an application, switch to a Space with open windows for the application".

- On: Cmd+Tab takes you to the app's Space. But macOS also jumps when you quit an app, when an app relaunches, or when you swipe to an empty Space.
- Off: no jumps. But Cmd+Tab no longer follows the app.

Bokich gives you both. Turn the setting off. macOS stops jumping, and Bokich follows the apps you pick.

### Why the name

"Bok" means "hi" in Croatian. "Bokić" is a small, friendly "hi". The buddy is called Bokić. The app is Bokich, the same name without the "ć".

## Setup

Bokich needs a few macOS settings. Open the Bokich menu → **Setup**. It shows what is done and what is missing. Click an item to open the right settings page. The menu bar icon shows a "!" badge only while Accessibility access is missing.

### Required

1. **Allow Accessibility access.** System Settings → Privacy & Security → Device Control and Data Access → turn on Bokich. On macOS 26 and earlier, the list is called Accessibility. Bokich asks on first launch.

### Recommended

1. **Turn off switching to the app's Space.** System Settings → Desktop & Dock → Mission Control → turn off "When switching to an application, switch to a Space with open windows for the application". This stops macOS from jumping. Bokich works best with it.
2. **Keep "Move left a space" and "Move right a space" on.** System Settings → Keyboard → Keyboard Shortcuts… → Mission Control. They are on by default (Ctrl+← and Ctrl+→).
3. **Turn on "Switch to Desktop 1", "Switch to Desktop 2", and so on.** System Settings → Keyboard → Keyboard Shortcuts… → Mission Control → expand Mission Control. The default keys are Ctrl+1 to Ctrl+9. Bokich then jumps straight to the right Space, instead of sliding through each one. macOS lists only the desktops you have, so tick new ones after you add Spaces. Bokich only uses Desktop 1 to 9.
4. **Turn on Reduce motion.** System Settings → Accessibility → Motion → Reduce motion. On macOS 26 and earlier, it is under Accessibility → Display. The Space slide becomes a quick fade.

If an app uses Ctrl+1 to Ctrl+9, give the Desktop shortcuts other keys. Bokich reads the keys you set. Quit and reopen Bokich after you change shortcuts.

## How it works

- You pick an app with Cmd+Tab, the Dock, a launcher, or `open -a` in a terminal. If it has no window on screen, Bokich switches to the Space with its last-used window and focuses it.
- An app quits, relaunches, or hides. You stay where you are. Bokich focuses a window on the current Space. If the Space is empty, Bokich takes over and holds it.
- You land on an empty Space. Bokich takes over and holds it, so your typing doesn't go to an app on another Space.
- Bokić greets you when Bokich takes over, and winks when it follows an app.

When Bokich takes over, its Dock icon and menu bar show up. That is expected. They go away when you pick another app.

## Meet Bokić

Bokić is a small blob that lives on your desktop, on every Space.

- Click it to change its shape and color and get a greeting.
- Drag it anywhere. It remembers the spot.
- It blinks, greets you when Bokich takes over, winks when it follows an app, and gets sleepy when left alone.
- It adapts its border to your wallpaper.
- It looks sad while Bokich is off.

## Menu bar

- **Enabled**: turn Bokich on or off. Default shortcut: ⌃⌥⌘0.
- **Show Bokić**: show or hide the buddy. Bokich keeps working.
- **Reset Bokić Position**: move Bokić back to the top-right corner.
- **Change Shortcut…**: pick another shortcut, or turn it off.
- **Launch at Login**
- **Setup**: see which settings are done, and open the missing ones.
- **About Bokich**
- **Quit Bokich**

The menu bar icon smiles when Bokich is on and looks sad when it is off. It shows a "!" badge while Accessibility access is missing.

## Requirements

- macOS 13 or later. Tested on macOS 27 with one screen. Older versions should work, but are not tested.
- The settings in [Setup](#setup).

## Install

With Homebrew:

```sh
brew install --cask maliMirkec/tap/bokich
```

Or download the latest zip from [Releases](https://github.com/maliMirkec/bokich/releases), unzip it, and move `Bokich.app` to Applications.

The app is self-signed, not notarized, so macOS blocks it on first launch:

1. Open Bokich. macOS shows a warning. Click Done.
2. Go to System Settings → Privacy & Security.
3. Scroll down and click Open Anyway next to Bokich.

Or remove the quarantine flag in Terminal:

```sh
xattr -dr com.apple.quarantine /Applications/Bokich.app
```

## Build from source

You need the Xcode Command Line Tools:

```sh
xcode-select --install
```

Build and run:

```sh
./build.sh
open build/Bokich.app
```

`build.sh` signs ad hoc by default. Each rebuild then asks for Accessibility access again. To keep access across rebuilds, create a self-signed code signing certificate in Keychain Access and pass its name:

```sh
SIGN_ID="Bokich Dev" ./build.sh
```

## Release

1. Set the version in `Info.plist` (`CFBundleShortVersionString`) and add it to `CHANGELOG.md`.
2. Run `./release.sh`. It signs with `Bokich Dev`, verifies the signature, and writes `dist/Bokich-<version>.zip`.
3. Upload the zip to a new GitHub release.
4. Copy `dist/bokich.rb` to `Casks/bokich.rb` in the [homebrew-tap](https://github.com/maliMirkec/homebrew-tap) repo and push it.

Always sign releases with the same certificate. Then Accessibility access survives updates.

## Limits

- Bokich follows an app only if you used Cmd+Tab, pressed Return, used another app's global shortcut, or clicked less than a second before it became active. Typing and normal shortcuts like Cmd+C don't count. Apps that activate themselves are not followed.
- Following an app is animated, since macOS has no instant switch. Reduce motion makes it shorter.
- With Ctrl+← and Ctrl+→, Bokich only switches Spaces on the display under the mouse. Turn on Ctrl+1 to Ctrl+9 for two screens.
- Ctrl+1 to Ctrl+9 reach desktops 1 to 9. Full-screen apps and later desktops use Ctrl+← and Ctrl+→.
- Bokich reads Space info with private macOS APIs. A macOS update can break them.
- Bokić uses a fallback style for video wallpapers, folder wallpapers, and missing wallpaper files.

## To do

- [ ] Test with two or more screens. Bokich should work there, but nobody has tried it yet. If you use more than one screen, please [open an issue](https://github.com/maliMirkec/bokich/issues) and tell us how it went.
- [ ] Test on macOS 26 and earlier.

## License

[MIT](LICENSE) © [Silvestar Bistrović](https://www.silvestar.codes)

Made by [Silvestar Bistrović](https://www.silvestar.codes).
