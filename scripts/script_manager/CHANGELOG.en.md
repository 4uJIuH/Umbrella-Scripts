# Update v2.2.0

- Added a pink theme.
- Window settings now include background blur with adjustable strength and transparency.
- Added a font selector for the interface.

# Update v2.1.0

- The scrollbar now responds to clicks and dragging: drag the thumb or click the track to jump to a position. It becomes wider and brighter on hover or while dragging, and stays highlighted while in use. Mouse-wheel scrolling is unchanged.
- Opening a script card now saves the list position. Back and Esc restore it; positions are kept separately for each category, selected hero, and search query. Opening a different category or hero starts at the top.

# Update v2.0.5

- Multi-file installs support `filters/filter_*_cached.txt` filter files and create the `scripts/filters` folder.
- Added BehaviorScoreHelper: auto GG, auto report, and auto like.

# Update v2.0.4

- Multi-file installs support additional JSON files alongside the Lua script without creating subfolders.
- Hero Grid installs with three sample grids.

# Update v2.0.3

- Multi-file package installation now proceeds when the `lib` folder already exists, avoiding shell commands when the Lua runtime blocks them.

# Update v2.0.2

- Added multi-file Lua package installation; Tinker Auto Farm is installed with its `lib` folder using the Install button.
- The catalog retains its ZIP URL for older manager versions while updated managers use direct package file URLs.
- Failed downloads do not install partial packages; files are restored if writing the package fails.

# Update v2.0.1

- Added But3rflys scripts and their latest releases, with author attribution in catalog cards.
- Records the installed version of scripts without an embedded marker so available updates are detected correctly.
- Hero filtering now uses only the explicit `heroes` field; general scripts are no longer matched to heroes from their descriptions.
- Added RAR package downloads for manual installation.
- Visual/UI authors: watahell / papagdetto.

**Update v2.0.0**

- Script Market is now the new Script Manager. The catalog ID, `script_manager.lua` filename, and `script-manager-v*` tag convention are retained so existing installs can update in place.
- Added a searchable catalog with hero, category, and installation-status filters, detailed script cards, and installed-file management.
- Fixed version detection and download validation for scripts declaring `SCRIPT_VERSION`, including Dynamic Island.
- Manager self-updates use `VERSION`, preventing the old Script Manager from replacing the new version.
- Downloads are validated, replaced files are backed up, and `!_qLocalizer.lua` is installed when a script requires it.
- The window and menu are named Script Manager. Remove a separate `script_market.lua` installation to avoid running two catalog windows.
