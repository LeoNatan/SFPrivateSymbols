#!/bin/zsh
# usage: shot.sh <out.png> [launch arguments…]
# Relaunches the installed SF Private Symbols and captures its window (full size, plus a 1600 px copy *s.png).
S=${0:A:h}; OUT=${1:A}; shift
[[ -x $S/bin/wid ]] || { mkdir -p $S/bin && swiftc -O $S/wid.swift -o $S/bin/wid; }
pkill -x "SF Private Symbols"; sleep 0.5
open -n "/Applications/SF Private Symbols.app" --args "$@"
sleep 4.5
W=$($S/bin/wid "SF Private" | head -1)
screencapture -o -l $W $OUT && sips -Z 1600 $OUT --out ${OUT:r}s.png >/dev/null && echo $OUT
