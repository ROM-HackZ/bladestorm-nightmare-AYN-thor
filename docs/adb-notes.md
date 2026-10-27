# ADB menu-control notes

These notes describe what worked on the tested Thor. They are optional diagnostics instructions, not part of the launch fix. Use a device serial selected from `adb devices -l`; no personal serial is stored in this repository.

## Keys and short presses

Very short `adb shell input keyevent` presses were often missed by the game. A short held key was more reliable:

```powershell
# Example: hold Enter for 200 ms, with no Shift modifier.
& $adb -s $serial shell input keycombination -t 200 66 66
```

The repeated keycode supplies the two arguments required by Android's `keycombination` command while holding the same key. This was tested on the Thor's Android 13 build; behavior can vary on other builds. Wait for the resulting screen and inspect the current selection before sending the next key.

| Android keycode | Key | Use in this game |
| --- | --- | --- |
| 19 / 20 | Up / Down | Select a graphics row |
| 21 / 22 | Left / Right | Change a value or menu selection |
| 66 | Enter | Confirm |
| 62 | Space | Setting Complete; skip the opening movie |
| 111 | Escape | Back / return to battlefield; routing can depend on context |
| 131 | F1 | Game pause menu |
| 4 | Android Back | GameNative Quick Menu |

`input keyevent --longpress 66` and `--longpress 62` also worked, but long presses can repeat. Do not use long repeated directional input when an accidental selection would matter.

**Do not combine Shift with F1.** Shift is the game's Save shortcut on the pause menu, so it can open the save screen immediately after pausing. Earlier exploratory Shift-based key examples were superseded by the unmodified-key approach above.

## Two different pause layers

F1 opens the game's own battle menu. Android Back opens GameNative's Quick Menu. Closing GameNative's menu can leave a large Play icon on screen: tap it to resume the suspended guest. A paused screenshot or a menu FPS value cannot establish live battle performance.

## Inspect without publishing raw logcat

Use [capture-diagnostics.ps1](../scripts/capture-diagnostics.ps1) for a compact read-only snapshot. Full GameNative logs can contain account/session information and device paths. The repo helper records only the PowerMetrics tag and selected device metadata; it does not export full launch logs or credentials.

The release APK did not permit `run-as app.gamenative`. The session used normal ADB inspection and UI controls. No root access, application-data reset, or private-prefix replacement was performed.
