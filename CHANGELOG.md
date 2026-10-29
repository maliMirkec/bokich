# Changelog

## 2.1.0

Fixes for focus, app switching, and two screens.

Focus:

- Bokich no longer takes focus from dialogs, like admin password prompts and app update dialogs.
- Picking a menu item that opens another app, like Open With, no longer makes Bokich take focus.
- Landing on a Space with only a menu bar app's window no longer makes Bokich take focus.
- Clicking Bokić no longer takes focus from your app.
- Closing a Bokich window gives focus back to your app.

Following apps:

- Only Cmd+Tab, Return, clicks, and other apps' global shortcuts count as switching apps. Typing, Option keys like @ on the Croatian keyboard, and shortcuts like Cmd+C or Ctrl+C don't.
- Bokich still follows apps when iTerm's Secure Keyboard Entry or a password field hides keys from it.
- Bokich ignores its own Space switch keys.
- Clicking the Dock right after Cmd+W, Cmd+M, Cmd+H, or Cmd+Q follows the app.
- A helper app quitting in the background no longer stops a follow.
- A second app switch no longer starts while Bokich is still switching Spaces.
- Bokich skips minimized windows.

Holding a Space:

- Bokich lets go of a held Space as soon as another app is in front, or if macOS doesn't make Bokich active.
- Turning Bokich off lets go of a held Space and stops a follow or takeover that is about to run.
- Moving between empty Spaces no longer makes the Dock icon flicker.
- An app quitting during a switch no longer triggers two takeovers.

Two screens:

- Bokich acts on the screen whose Space changed, not the screen under the mouse.
- Bokich no longer takes over the other screen right after it follows an app.
- After an app quits, Bokich focuses a window on the same screen first.
- With shared Spaces across screens, Bokich checks every screen before it holds a Space.

Other:

- A frozen app no longer freezes Bokich.
- Fewer Accessibility calls on each app switch, so slow apps delay Bokich less.
- The shortcut picker rejects the shortcuts macOS uses to switch Spaces. A saved shortcut that clashes goes back to ⌃⌥⌘0.

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
