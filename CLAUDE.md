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
xcodebuild -project SFPrivateSymbols.xcodeproj -scheme SFPrivateSymbols -configuration Debug build
```

Don't pass `-derivedDataPath` (or set a custom build location): build in the default
`~/Library/Developer/Xcode/DerivedData`. Léo has Spotlight ignore that folder; a build folder inside the repo
gets indexed, and its copies of the app show up when searching for it.

## Project conventions

- Folder-based Xcode project (synchronized groups): new files in `SFPrivateSymbols/` are picked up
  automatically. Don't add XcodeGen.
- Tabs for indentation (`usesTabs = 1`). Swift 6, default actor isolation `MainActor`.
- macOS 26 or later only. No sandbox, no hardened runtime. Private API is used on purpose.

## Read before changing UI

The sections below record where the data comes from, how Apple's SF Symbols app was inspected, and what
each conclusion is based on, so nobody has to rediscover it. Match Apple's app with the same techniques
(view-tree dumps, lldb), not by guessing from screenshots. The helper scripts are in
`Tools/AppleAppInspection/`.

## Where the data comes from

| What | Source |
| --- | --- |
| Glyphs (1,729 vector glyphs) | `/System/Library/CoreServices/CoreGlyphsPrivate.bundle/Contents/Resources/Assets.car` |
| Order, categories, search terms | `symbol_order.plist`, `symbol_categories.plist`, `symbol_search.plist` in the same bundle |
| Availability | `name_availability.plist` (`symbols` → release key, `year_to_release` → per-platform OS versions) |
| Aliases, fill/outline pairs, descriptive names | `name_aliases.strings`, `nofill_to_fill.strings`, `semantic_to_descriptive_name.strings` |
| Container shapes | `container_recipes.plist` |
| Category titles, icons and order | the public `/System/Library/CoreServices/CoreGlyphs.bundle` `categories.plist` |

SF Symbols version from release year: 2019 → 1.0 … 2025 → 7.0, then 2026 → 27.0 (minor versions kept, so
2020.1 → 2.1). See `SymbolCatalog.sfSymbolsVersion(forRelease:)`.

### Drawing private symbols

- SwiftUI: `Image(_internalSystemName:)` and `Image(_internalSystemName:variableValue:)` (underscored, declared
  in the SwiftUICore interface). Used for every symbol in the app.
- AppKit: `+[NSImage imageWithPrivateSystemSymbolName:]`. Verified to load private symbols.
- UIKit: `+[UIImage _systemImageNamed:]` (confirmed by Léo).
- The copied code is written as Swift imports these methods once a header declares them, as users of
  private API normally do: `NSImage(privateSystemSymbolName:)` (the `imageWith…` factory becomes a
  failable initializer) and `UIImage._systemImageNamed(_:)` (the leading underscore keeps it a class method).

### Vector outlines (templates, SVG, proof sheets)

CoreUI, called at runtime (`GlyphOutline.swift`):

- `+[CUICatalog defaultUICatalogForBundle:]` (plain `alloc`/`init` runs into ARC problems), then
  `namedVectorGlyphWithName:scaleFactor:deviceIdiom:layoutDirection:glyphSize:glyphWeight:glyphPointSize:appearanceName:`
  with weight 1–9 (ultralight…black) and size 1–3 (small…large).
- `CUINamedVectorGlyph`: `CGPath` is **y-down**, origin at the top-left of the alignment rect (exporting it
  as-is flipped every template). Metrics: `alignmentRectUnrounded`, `contentBoundsUnrounded`,
  `baselineOffsetUnrounded`.
- Layers: `monochromeLayers`, `hierarchicalLayers`, `multicolorLayers`; each has `shape`, `name`
  (`hierarchical-1:secondary`, `multicolor-0:custom`), `hierarchyLevel`, `opacity`, `isEraserLayer`, `fillColor`.

Exported templates were checked by compiling them with `actool`: all 27 variants in 7.0 and 2.0 templates
compile without errors, and renders match the system's for monochrome, ultralight, black, hierarchical and
multicolor. Template 2.0 must contain all 27 variants ("must have a glyph for Regular weight Medium size"),
so it is always exported static.

## How Apple's app was inspected

Rule of thumb: **read the real structure and values; use screenshots only to confirm the result.** Guessing
from screenshots, or screenshotting every menu state, wasted rounds early on.

SF Symbols mixes AppKit and SwiftUI: an `NSSplitView` window with an AppKit `NSToolbar`, an
`NSCollectionView` grid whose cells host SwiftUI (`GridItemSymbolView`), and a SwiftUI inspector
(`RightSidebarView`). Each technique below fits one of those layers.

### 1. AppKit views and objects: lldb expressions

`Tools/AppleAppInspection/sfx.sh '<Objective-C>'` attaches lldb to SF Symbols, evaluates the expression and
detaches. Examples used:

- `[[[[NSApp windows] firstObject] contentView] _subtreeDescription]`: the whole view tree with classes,
  frames and addresses.
- Toolbar items: identifiers, `view` class, `bezelStyle`, `controlSize`, `font`, segment images, widths.
- Collection view layout: `itemSize`, `sectionInset`, `minimumInteritemSpacing`, `backgroundColors`, and the
  scroll view's `contentInsets`.
- Colors: resolve catalog/dynamic colors under each appearance with
  `[[NSAppearance appearanceNamed:…] performAsCurrentDrawingAppearance:^{ … }]`.
- Menus: walk `[[NSApp mainMenu] itemWithTitle:@"View"].submenu.itemArray` for titles, shortcuts, actions.
- Preferences: `defaults read com.apple.SFSymbols` (e.g. the `CopyImage*` keys, which this app reuses).

Gotchas: expressions must be one line; cast `NSApp`/`id` results to typed variables; use unique variable
names across runs; macros such as `MIN` aren't available.

### 2. SwiftUI views: view debug data

1. Launch SF Symbols with `SWIFTUI_VIEW_DEBUG=27` (bit mask: type 1, value 2, position 8, size 16):
   `open -a "SF Symbols" --env SWIFTUI_VIEW_DEBUG=27`.
2. Find the `NSHostingView` in `_subtreeDescription`.
3. `Tools/AppleAppInspection/dumppane.sh out.txt <HostingViewClassPattern>` calls `-makeViewDebugData`. JSON
   encoding fails for some views (non-encodable values), so `viewdebug.py` breaks on
   `static SwiftUI._ViewDebug.serializedData(_:)` in SwiftUICore, takes `$x0` as `[SwiftUI._ViewDebug.Data]`
   in an lldb Swift expression, and walks it with `Mirror`. The output has view types, sizes, paddings,
   spacings, corner radii, line widths, fonts and `Color` values.
4. `sem.py` (text dumps) and `vd.py` (JSON dumps) reduce the tree to the meaningful views.

### 3. Picker and menu options: enum metadata

Options aren't in the view tree until a menu opens. `fieldmd.py <binary>` parses the `__swift5_fieldmd`
section and prints every enum with its case names, in declaration order. That gave the rendering modes,
color names (`ColorNamePickerSelection`), animation effects and their options. (`swift-reflection-dump`
doesn't ship with Xcode.)

### 4. Live controls: accessibility walk in-process

SwiftUI only builds its accessibility tree after
`[NSApp accessibilitySetValue:@YES forAttribute:@"AXEnhancedUserInterface"]`. A walk over
`accessibilityChildren` (role, value, frame) then dumps a whole inspector tab in one call. Posting key events
drives open menus. Watch out: keys can land on a different pop-up than intended (this once switched Apple's
Rendering Mode, which isn't persisted, so relaunching restored it).

### 5. Private framework behavior: disassembly

To learn *why* AppKit does something, disassemble the method in lldb and resolve the selectors its
`objc_msgSend` stubs load. `stubs.py` adds an lldb command that prints a function's instructions with those
selector names. `meth.swift` lists a class's methods filtered by a regex (`PAT=… ./meth Class`), and
`proto.swift` prints a protocol's methods and which classes conform.

### 6. Pixels: only to confirm

`Tools/AppleAppInspection/shot.sh out.png [launch args]` relaunches the installed app and captures its window
(`wid.swift` finds the window id). `px.swift` samples sRGB pixels; `bounds.swift` measures a glyph's bright
bounds in a screenshot and compares it with `NSImage` symbol sizes at a given point size (how the 32 pt grid
glyph size was derived). Debug builds accept launch arguments such as `-DebugSymbol <name>`,
`-DebugInspectorTab rendering`, `-DebugViewMode list`, `-DebugBackground light`, `-DebugExport template`,
`-DebugAnimation wiggle` (see `AppModel.applyDebugLaunchArguments()` and `ContentView`).

## What was learned

### Grid

From the collection view layout and the `GridItemSymbolView` debug data:

- Flow layout with 100 × 140 pt items, 20 pt left/right/bottom section insets, 20 pt minimum spacing between
  items, 0 line spacing. Leftover width is spread between columns.
- Background: the collection view's dynamic color, white in light mode and #1E1E1E (0.118) in dark mode,
  the same as `NSColor.textBackgroundColor`. The scroll view spans the whole window, with content insets for
  the sidebar and toolbar.
- Tile: 100 × 80 rounded rectangle, radius 20, continuous corners, 8 pt from the top of the item. It's filled
  with the symbol background (`defaultSymbolBackground`, the same color as the grid) and stroked with 1 pt
  `separatorColor`.
- Symbols that have variants get a second card behind the tile: scaled 0.9 horizontally, offset 4 pt up,
  filled with 60% of a dynamic color and stroked with `separatorColor`.
- Selection: both cards' strokes become a 2 pt accent color. The name label doesn't change.
- Glyph about 32 pt (measured), centered in the tile. Name: `NSTextField`, 13 pt system font, `labelColor`,
  centered, at most 2 lines, 104 pt wide, 4 pt below the tile.
- No zoom (the View menu has none). This app keeps ⌘+ / ⌘− and defaults to Apple's size.
- Variants (from `SF Symbols.app/Contents/Resources/Metadata/base_symbols_map.json`, a hand-made base →
  variants map for public symbols only): browsing shows base symbols only, with the stacked card on bases
  that have variants (3,221 tiles for 7,205 symbols). Search flattens them (`.fill`, `.circle`… get their own
  tiles). Localized variants (`.ar`, `.rtl`…) never get tiles, not even in search; they only appear in the
  inspector. View > Show Symbol Variants (⌘O) shows only the selected base's variants, titled with the base
  name behind a `chevron.left` back button and with the selection cleared; View > Show All Symbols leaves it.
  Search results are titled "Search <category>".
- The map doesn't cover private symbols, so `SymbolCatalog` derives families: `base.<suffix>` is a variant of
  the shortest existing `base` when the suffix is one the map uses (`SymbolFamilies.swift`, regenerated by
  `Tools/make_family_suffixes.py`). On public symbols this rule matches Apple's map with 97% precision and
  99% recall; the misses are curation quirks (e.g. `.compact` bases).

### Toolbar

From the `NSToolbar` items:

- Items: New Collection (`folder.badge.plus`, not replicated), sidebar toggle (`sidebar.leading`), font
  family pop-up (169 pt, not replicated), weight pop-up (`FontWeightPopUpButton`), view mode segmented
  control (`square.grid.2x2`, `list.bullet`, `squares.below.rectangle`), inspector toggle
  (`sidebar.trailing`), search.
- Pop-ups are `NSPopUpButton`s with `bezelStyle` toolbar (11), `controlSize` extra large (4), 13 pt system
  font, sized to the selected title (94 pt for "Regular").
- SwiftUI's `Picker` can't produce this (its font and padding ignore `.font` and `.controlSize`), so
  `ToolbarPopUp.swift` hosts a real `NSPopUpButton`.
- **Glass grouping.** AppKit decides per item whether it gets its own glass capsule:
  `-[NSToolbarItem glassBehavior]` returns 1 (own capsule) for selectable items or prominent tinted items,
  otherwise it asks the item view's `preferredGlassBehavior` (private `NSGlassAwareView` protocol), and
  returns 2 (shared capsule) when the view doesn't conform. `NSPopUpButton`, `NSButton` and
  `NSSegmentedControl` conform and answer 1. SwiftUI's `ToolbarItemHostingView` answers from a
  `ToolbarPreferredGlassBehaviorKey` preference that only SwiftUI's own menu, picker and segmented styles
  set, so a hosted AppKit view answers 2 and adjacent ones merge into one capsule.
- What didn't work: `ToolbarSpacer(.fixed)` (SwiftUI moved the spacers to the far left),
  `.sharedBackgroundVisibility(.hidden)` (removes the bezel entirely), a clear or nearly clear
  `backgroundTintColor` (only counts for `.prominent` items), and swapping the host's class at runtime
  (breaks AppKit's KVO on that property and crashes).
- What works (`OwnGlassPlatter` in `ToolbarPopUp.swift`): replace `preferredGlassBehavior` on the hosting
  view's class (below any KVO subclass) so hosts flagged by the pop-up answer 1, then send KVO change
  notifications so the toolbar re-reads it.

### Inspector

- Tabs: `info`, `paintbrush`, and a custom `animation` symbol from
  `SF Symbols.app/Contents/Frameworks/SFSymbolsShared.framework`.
- Layout, spacing, sections and options were taken from the debug data and enum metadata. See the comments
  in `InspectorView.swift` and `AnimationInspectorView.swift`.
- Only Info needs a selection ("No Selection"). Rendering and Animation always show their settings.
- Rendering Mode defaults to Automatic and isn't persisted.
- Background: it applies to every tile and preview. Label colors such as Primary resolve against it (Light →
  black symbols). For Custom, light or dark is decided by relative luminance > 0.5. The color well sits to
  the right of the menu.

### Copy and export

- File: Export Template… ⌘E, Export Symbol… ⇧⌘E: a 9 × 3 proof sheet, then an SVG in SF Symbols' template
  format: a 3300 × 2200 artboard; weight columns centered at 559.711, 856.422, 1153.13, 1449.84, 1746.56,
  2043.27, 2339.98, 2636.69, 2933.4; S/M/L baselines at 696, 1126, 1556; cap height 70.459; margin lines from
  baseline − 95.215 to baseline + 24.121. Groups are named like `Regular-S`, and layers carry classes
  `monochrome-i multicolor-i:name hierarchical-i:level`.
- Edit: Copy Symbol ⌘C (SVG plus an RTF font character in Apple's app; SVG only here, since private
  symbols have no font character), Copy as Text ⌃⌘C (not replicated, same reason), Copy Name ⇧⌘C, Copy
  Image ⌥⌘C (PNG plus a temporary file URL), Copy Image As… (PNG or SVG; point size 550, pixel scale 1,
  symbol scale; same `CopyImage*` preference keys as Apple's app). This app adds Copy SwiftUI Code.

### Patching Apple's app instead

This was checked and rejected. The app's symbol list comes only from `FontSymbolStore` (CoreGlyphsLib),
which reads the SF Symbols font. The `*_private` metadata files load, but only for symbols already in the
font, so adding CoreGlyphsPrivate data left the count at 7,205. There's no user setting for private symbols,
and `COREGLYPHS_INTERNAL=1` changes nothing. `imageWithPrivateSystemSymbolName:` is used only for toolbar
and menu icons.

## App icon

`AppIcon.icon` is an Icon Composer document derived from SF Symbols' icon, with the symbols tinted orange.
`Tools/make_icon.py <source .icon Assets folder> <output .icon>` regenerates it: hue 30°, saturation × 1.35,
lightness × 0.88; grays stay neutral. When the Dock or Finder shows an old icon, it's the icon cache:
relaunch, and run `lsregister -f` on the app.

## Source map

| File | Contents |
| --- | --- |
| `SymbolCatalog.swift` | Loads the bundle plists and CoreUI names; `PrivateSymbol`, categories, availability |
| `SymbolStyle.swift` | Weight, scale, rendering mode, colors, background |
| `SymbolImage.swift` | Symbol view, plus `SymbolExport` (copy and code strings, PNG/SVG) |
| `GlyphOutline.swift` | CoreUI vector glyph access |
| `SymbolTemplate.swift` | Template and plain SVG writers |
| `ExportSheets.swift` | Export proof sheet, Copy Image As sheet |
| `SymbolGridView.swift`, `SymbolListView.swift`, `SymbolGalleryView.swift` | The three view modes |
| `InspectorView.swift`, `AnimationInspectorView.swift` | Inspector tabs |
| `ToolbarPopUp.swift` | AppKit toolbar pop-up with its own glass capsule |
| `ContentView.swift`, `SidebarView.swift`, `AppModel.swift`, `SFPrivateSymbolsApp.swift` | Window, toolbar, sidebar, state, menu commands |
