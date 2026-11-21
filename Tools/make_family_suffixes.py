#!/usr/bin/env python3
# Regenerates SFPrivateSymbols/SymbolFamilies.swift from SF Symbols' base symbol map.
# usage: Tools/make_family_suffixes.py [path to SF Symbols.app]
import json, os, sys
app = sys.argv[1] if len(sys.argv) > 1 else "/Applications/SF Symbols.app"
m = json.load(open(os.path.join(app, "Contents/Resources/Metadata/base_symbols_map.json")))
sufs = sorted({v[len(b) + 1:] for b, vs in m.items() for v in vs if v.startswith(b + ".")})
out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "SFPrivateSymbols", "SymbolFamilies.swift")
lines = ["//", "//  SymbolFamilies.swift", "//  SFPrivateSymbols", "//",
	"//  Suffixes that turn a base symbol into one of its variants, as used by SF Symbols' base symbol map",
	"//  (SF Symbols.app/Contents/Resources/Metadata/base_symbols_map.json, which only covers public symbols).",
	"//  Regenerate with Tools/make_family_suffixes.py.", "//", "",
	"extension SymbolCatalog {", "\tnonisolated static let familySuffixes: Set<String> = ["]
lines += ['\t\t"%s",' % s for s in sufs]
lines += ["\t]", "}", ""]
open(out, "w").write("\n".join(lines))
print(f"{len(sufs)} suffixes written to {os.path.normpath(out)}")
