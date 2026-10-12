# Script Manager

Script Manager checks the GitHub catalog when asked and offers the selected Dota script update for installation. It creates a `.script-manager.bak` backup before replacing an existing file, installs `!_qLocalizer.lua` only when a selected script requires it and the library is missing, then reloads the Script System.

Tinker Auto Farm is provided as a ZIP and must be extracted manually into the scripts folder.

Place `script_manager.lua` in `umbrella\scripts`, reload Lua scripts, then open `Scripts → Scripts → Script Manager`.
