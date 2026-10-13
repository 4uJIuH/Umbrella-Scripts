**Update v2.0.0**

- Script Market is now the new Script Manager. The catalog ID, `script_manager.lua` filename, and `script-manager-v*` tag convention are retained so existing installs can update in place.
- Added a searchable catalog with hero, category, and installation-status filters, detailed script cards, and installed-file management.
- Fixed version detection and download validation for scripts declaring `SCRIPT_VERSION`, including Dynamic Island.
- Manager self-updates use `VERSION`, preventing the old Script Manager from replacing the new version.
- Downloads are validated, replaced files are backed up, and `!_qLocalizer.lua` is installed when a script requires it.
- The window and menu are named Script Manager. Remove a separate `script_market.lua` installation to avoid running two catalog windows.
