# Bokich

A tiny macOS buddy that keeps you on your current Space when you quit an app.

## Why Bokich

macOS has one setting: "When switching to an application, switch to a Space with open windows for the application".

- On: Cmd+Tab takes you to the app's Space. But quitting an app can throw you to another Space.
- Off: no jumps. But Cmd+Tab no longer follows the app.

You can't have both. Bokich fixes the quit case, so you can keep the setting on.

### Why the name

"Bok" means "hi" in Croatian. "Bokić" is a small, friendly "hi". The buddy is called Bokić. The app is Bokich, the same name without the "ć".

## How it works

1. Bokich catches Cmd+Q before the app gets it.
2. It focuses the next window on the current Space.
3. If there is no window, it holds the Space for a moment.
4. It quits the app. You stay where you are.
5. Bokić winks.

Full-screen apps leave full screen first, then quit.

## Meet Bokić

Bokić is a small blob that lives on your desktop, on every Space.

- Click it to change its shape and color and get a greeting.
- Drag it anywhere. It remembers the spot.
- It blinks, winks after a quit, and gets sleepy when left alone.
- It adapts its border to your wallpaper.
- It looks sad while Bokich is off.

## Menu bar

- **Enabled**: turn the quit fix on or off. Shortcut: ⌃⌥⌘0.
- **Show Bokić**: show or hide the buddy. The quit fix keeps working.
- **Reset Bokić Position**: move Bokić back to the top-right corner.
- **Launch at Login**
- **Quit Bokich**

The menu bar icon smiles when Bokich is on and looks sad when it is off.

## Requirements

- macOS 13 or later.
- Accessibility access. Bokich asks on first launch. You can also allow it in System Settings → Privacy & Security → Accessibility.

## Install

Download the zip from GitHub Releases and move `Bokich.app` to Applications.

The app is self-signed, so macOS warns on first launch. Right-click the app, choose Open, then confirm. If that doesn't work, run:

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

## Limits

- Only Cmd+Q is covered. Quitting from the Dock or the app menu can still jump.
- Finder is skipped, since it never really quits.
- After quitting the last app on a Space, Bokich shows in the Dock until you switch apps.
- Bokić uses a fallback style for video wallpapers, folder wallpapers, and missing wallpaper files.

## License

[MIT](LICENSE) © [Silvestar Bistrović](https://www.silvestar.codes)

Made by [Silvestar Bistrović](https://www.silvestar.codes).
