#!/bin/zsh
# usage: dumppane.sh <output.txt> [hosting view class pattern]
# Dumps the SwiftUI view tree (types, sizes, values) of the first NSHostingView in SF Symbols'
# front window whose class matches the pattern. SF Symbols must run with SWIFTUI_VIEW_DEBUG=27.
S=${0:A:h}; OUT=${1:A}; PAT=${2:-NavigationPaneModifier}
$S/sfx.sh '[[[[NSApp windows] firstObject] contentView] _subtreeDescription]' > $S/tree.txt
P=$(/usr/bin/grep -oE "${PAT}[[:alnum:]_\$]* 0x[0-9a-f]+" $S/tree.txt | head -1 | awk '{print $2}')
[[ -z $P ]] && { echo "no hosting view matching $PAT"; exit 1; }
rm -f $OUT
lldb -n "SF Symbols" --batch -o "command script import $S/viewdebug.py" -o "command script add -f viewdebug.run dumpvd" -o "dumpvd $OUT $P" -o detach 2>&1 | grep -E "written|error" | head -3
