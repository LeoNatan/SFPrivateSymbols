# SF Private Symbols

A macOS 26+ recreation of Apple's **SF Symbols** app (`/Applications/SF Symbols.app`) that browses the
**private** SF Symbols shipped in `CoreGlyphsPrivate.bundle`, with their names, categories, search terms,
availability and variants, plus Apple's rendering, animation, copy and export features.

Builds install directly into `/Applications`; see [`CLAUDE.md`](CLAUDE.md) for why and how.

This README is mainly for agents continuing the work: it records where the data comes from, how Apple's app
was inspected, and what each conclusion is based on, so nobody has to rediscover it.

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
- UIKit: `+[UIImage _systemImageNamed:]` appears in the copied UIKit code. **Not verified**: a plain macOS
  process can't load UIKit's classes; check it in a Catalyst or simulator process before relying on it.

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
- In Apple's "All" grid, variants such as `.fill` are hidden behind the stacked card; View > Show Symbol
  Variants (⌘O) reveals them. **Not replicated yet**: this app lists every variant as its own tile.

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
