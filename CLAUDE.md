# Notes for agents

## Building installs the app into /Applications

Every build (Debug and Release, from Xcode or `xcodebuild`) writes the app straight to
**`/Applications/SF Private Symbols.app`**. It's set in the target's build settings:

```
DEPLOYMENT_LOCATION = YES
DSTROOT = /Applications
INSTALL_PATH = /
SKIP_INSTALL = NO
```

- There is no second copy. `Build/Products/<Configuration>/SF Private Symbols.app` in DerivedData is only
  a symlink to the installed app, and running from Xcode launches the installed app.
- `DSTROOT = /` with `INSTALL_PATH = /Applications` fails with "Cycle inside a single target", because `/`
  contains the build folders. An empty `INSTALL_PATH` makes Xcode treat the product as uninstalled. Keep the
  values above; the resulting `/Applications//…` double slash is harmless.
- To launch what you just built: `open "/Applications/SF Private Symbols.app"`. Quit the running copy first
  (`pkill -x "SF Private Symbols"`), or `open` only brings the old process to the front.
- `/Applications/Private Symbols.app` is a different, older app. Don't touch it.

Typical command-line build:

```sh
xcodebuild -project SFPrivateSymbols.xcodeproj -scheme SFPrivateSymbols -configuration Debug \
	-derivedDataPath build/DerivedData build
```

## Project conventions

- Folder-based Xcode project (synchronized groups): new files in `SFPrivateSymbols/` are picked up
  automatically. Don't add XcodeGen.
- Tabs for indentation (`usesTabs = 1`). Swift 6, default actor isolation `MainActor`.
- macOS 26 or later only. No sandbox, no hardened runtime. Private API is used on purpose.

## Read before changing UI

`README.md` explains how Apple's SF Symbols app was inspected and what was learned from it (metrics, colors,
behaviors, private APIs). Match Apple's app with the same techniques (view-tree dumps, lldb), not by guessing
from screenshots. The helper scripts are in `Tools/AppleAppInspection/`.
