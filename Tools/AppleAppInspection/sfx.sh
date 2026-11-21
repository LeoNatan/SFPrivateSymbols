#!/bin/zsh
# usage: sfx.sh '<Objective-C expression>'
# Evaluates the expression inside the running SF Symbols app (lldb attach, then detach) and prints the result.
lldb -n "SF Symbols" --batch -o "expr -l objc -O -- @import AppKit; $1" -o detach 2>&1 | sed -n '/^(lldb) expr/,/^(lldb) detach/p' | sed '1d;$d'
