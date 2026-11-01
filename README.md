# nxnative Games Launcher

A native macOS app for launching games compiled with [nxnative](https://github.com/search?q=nxnative&type=repositories). It gives your games a single console-style home screen that you can browse from the couch with a DualSense controller.

The launcher only starts games. Each one runs as an independent macOS app, and the launcher comes back to the front when a game it opened quits.

## Features

- Game library defined in a single JSON file
- Full-screen, console-style home screen
- Cover art taken automatically from each game's `.app` icon
- DualSense controller and keyboard navigation
- Optional custom launch command per game, for options such as language or full screen
- Works offline: no accounts, no downloads

## Requirements

- macOS 14 or later
- Xcode with Swift 6
- One or more games compiled with nxnative

## Getting started

Clone the repository and build the app:

```bash
git clone https://github.com/juansecalvinio/nxnative-games-launcher.git
cd nxnative-games-launcher
bash scripts/bundle.sh
```

This creates `build/GamesLauncher.app`. Add your games as described below, then open it:

```bash
open build/GamesLauncher.app
```

You can also drag the app into your Applications folder.

If your games are in a protected folder such as Documents, macOS asks for permission on first launch, and the window appears after you answer. The app has an ad-hoc signature, so macOS may ask again after each rebuild. If you denied access, enable it in **System Settings > Privacy & Security > Files and Folders**.

## Adding your games

The launcher reads this file:

```text
~/Library/Application Support/GamesLauncher/games.json
```

Create it with one entry per game. Games appear in the same order as the file:

```json
{
  "games": [
    {
      "name": "My Game",
      "path": "~/Games/MyGame"
    },
    {
      "name": "Another Game",
      "path": "~/Games/AnotherGame",
      "command": "open --env DM_LANG=es-419 --env DM_FULLSCREEN=1 \"Another Game.app\""
    }
  ]
}
```

| Field | Required | Description |
| --- | --- | --- |
| `name` | Yes | Name shown on the home screen. |
| `path` | Yes | Folder that contains the `.app`, or the path to the `.app` itself. `~` is supported. |
| `command` | No | Shell command used instead of opening the `.app` directly. It runs from the game's folder through `/bin/zsh -c`. |

Changes to the file are picked up whenever you switch back to the launcher.

### nxnative options

nxnative games read these environment variables, which you can set from `command`:

| Variable | Description |
| --- | --- |
| `DM_LANG` | Game language, such as `es-419`. |
| `DM_FULLSCREEN` | Starts the game in full screen when set to any value. |

These only apply when the game starts. If it is already running, the launcher just brings it to the front.

## Controls

| Action | DualSense | Keyboard |
| --- | --- | --- |
| Move selection | D-pad or left stick | Left and right arrows |
| Play or dismiss a message | ✕ | Return |
| Switch to another app | | `Cmd+Tab` |
| Quit the launcher | | `Cmd+Q` |

## Development

Run the tests:

```bash
swift test
```

The project is a Swift package with no external dependencies:

- `Sources/LauncherCore`: configuration, game resolution, launching and selection logic
- `Sources/GamesLauncher`: SwiftUI interface and controller input
- `Tests/LauncherCoreTests`: unit tests
- `scripts/bundle.sh`: builds and signs the `.app`
- `scripts/make-icon.swift`: regenerates `Resources/AppIcon.icns`
