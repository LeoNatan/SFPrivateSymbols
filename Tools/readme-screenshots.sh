#!/bin/zsh
# usage: Tools/readme-screenshots.sh
# Captures the README screenshots (Supplements/screenshot.png and screenshot-dark.png) from the installed app.
# Needs an unlocked screen: a locked or sleeping display yields no window images and an inactive-looking window.
set -e
ROOT=${0:A:h:h}; T=$ROOT/Tools/AppleAppInspection; OUT=$ROOT/Supplements
[[ -x $T/bin/wid ]] || { mkdir -p $T/bin && swiftc -O $T/wid.swift -o $T/bin/wid; }
X() { lldb -n "SF Private Symbols" --batch -o "expr -l objc -O -- @import AppKit; $1" -o detach >/dev/null 2>&1; }
capture() {
	X "[NSApp setAppearance:[NSAppearance appearanceNamed:$1]]; @1"
	open -a "/Applications/SF Private Symbols.app"; sleep 2
	screencapture -l $($T/bin/wid "SF Private" | head -1) $2
}

caffeinate -u -t 60 &
pkill -x "SF Private Symbols" || true; sleep 0.5
open -n "/Applications/SF Private Symbols.app" --args -DebugCategory multicolor -DebugRendering multicolor -DebugSymbol activity.rings.closed
sleep 4.5
# Hide hex-named (obfuscated) symbols and use a README-friendly window size.
X 'NSMenu *m=[[[NSApp mainMenu] itemWithTitle:@"View"] submenu]; [m performActionForItemAtIndex:[m indexOfItemWithTitle:@"Show Obfuscated Names"]]; [(NSWindow*)[[NSApp windows] firstObject] setFrame:NSMakeRect(200,200,1500,900) display:YES]; @1'
capture NSAppearanceNameAqua $OUT/screenshot.png
capture NSAppearanceNameDarkAqua $OUT/screenshot-dark.png
X '[NSApp setAppearance:nil]; @1'
echo "$OUT/screenshot.png $OUT/screenshot-dark.png"
