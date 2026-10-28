# Changelog

## 2.0.0

New approach. Turn off "switch to a Space with open windows" in macOS, and Bokich does the good part.

- Cmd+Tab, Dock clicks, launchers, and `open -a` take you to the app's Space.
- Quitting, relaunching, or hiding an app keeps you on the current Space. Bokich focuses a window here, or takes over an empty Space.
- Landing on an empty Space keeps you there. Bokich takes over the Space.
- Bokić shows a greeting when Bokich takes over.
- Bokich goes back to the window you last used, even when an app has many windows.
- New Setup menu. It shows which macOS settings are missing and opens each one. The menu bar icon still shows a "!" badge only when Accessibility access is missing.
- Removing Accessibility access while Bokich runs no longer freezes keyboard and mouse.
- Removed the Cmd+Q, Cmd+W, and full-screen quit handling. macOS no longer jumps, so it is not needed.

## 1.1.0

- Multiple displays: the Space hold now happens on the quitting app's display.
- The menu bar icon shows a "!" badge when Accessibility access is lost. The quit fix stops and restarts with access.
- Cmd+W on the last window of apps that quit on close, like System Settings and Calculator. Bokich learns more apps.
- Change Shortcut…: pick your own shortcut, or turn it off.
- Cmd+Q is caught more reliably. Brave and other Chromium browsers no longer stay open with "Hold ⌘Q to quit".

## 1.0.0

First release.

- Cmd+Q keeps you on the current Space.
- Full-screen apps leave full screen before they quit.
- Bokić, a blob buddy on every Space. Click, drag, and greetings.
- Light and dark pastel colors with matching faces.
- Border and shadow adapt to the wallpaper and the blob color.
- ⌃⌥⌘0 turns Bokich on and off. Bokić looks sad while it is off.
- Launch at Login.
