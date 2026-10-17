# Update v2.10.3

- If an install or update fails, the button becomes "Retry", and the reason is shown in red on the card and on the script page.
- While updating all scripts, the banner shows progress ("Updating N of M"), and "Update all" stays disabled until it finishes.
- The script page shows the changelog of the new version while an update is pending or running.
- Arrow keys move through the list, and Enter opens the selected script.
- Search ignores letter case for Cyrillic text too.
- Installs show per-file progress ("Installing 2/3").
- Removing a script deletes its files and backups; files shared with other installed scripts are kept.

# Update v2.10.1

- Added sorting by rating (net votes) to the sort menu.

# Update v2.10.0

- Added script ratings: 👍/👎 counts are shown in the list, and you can vote on a script's page. Pressing the same thumb again removes the vote; pressing the other one switches it.
- Votes are tied to your Steam ID; if it cannot be read, voting is disabled with a notice.

# Update v2.9.0

- Improved performance with large catalogs by caching lists and update counts and skipping cards outside the viewport.
- Refined scrolling with smoother movement, acceleration on rapid wheel input, and a separately scrollable settings page.
- Added hover feedback and scroll-position indicators.

# Update v2.8.0

- Choose whether the window opens automatically after script reloads or only from its assigned key.
- Assign the opening key directly in Script Manager settings; the selected key is displayed, Escape cancels, and Backspace clears it.

# Update v2.7.1

- Fixed downloads for manually installed Lua files: Gank Threat, Achievements, and Counter Items are no longer rejected by ZIP/RAR validation.

# Update v2.7.0

- Package installation now supports nested folders and up to 200 Lua/JSON files. Self Play and LuaLingo can be installed with the Install button instead of manually extracting their archives.
- Packages are validated against their manifest paths, trusted URLs, and JSON size limit; ZIP/RAR downloads without a file manifest still require manual installation.

# Update v2.6.0

- Each script's menu location is now shown in a dedicated, easy-to-find section on its details card.
- Localized menu paths and multiple paths per script are supported.

# Update v2.5.0

- Scripts that install together with a folder (`lib` for Tinker Auto Farm, `filters` for BehaviorScoreHelper) now show a bright notice on their page: which empty folder to create in the scripts folder before installing.
- If Script Manager cannot create that folder by itself, a window with the folder name and a Continue button opens instead of a quiet error; once the folder exists, the install carries on.

# Update v2.4.0

- Added an Authors section with search and filtering by author.
- Hero-independent scripts are now grouped under Universal; improved catalog classification for tools and heroes.

# Update v2.3.0

- Added a close button in the top-right corner of the manager window.
- Added a "By update date" sort: newest versions first, with the date shown next to each script in the list while this sort is active.
- A script's card now shows, front and center, when it was last updated.
- Added an auto-update setting (off by default): after the catalog is checked, installed scripts update on their own. Pre-release versions are installed only when beta versions are enabled.
- The automatic script restart now waits for all running downloads to finish.

# Update v2.2.1

- Downloads and updates now use GitHub Release assets when available; scripts without release assets keep using their existing URL.

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
