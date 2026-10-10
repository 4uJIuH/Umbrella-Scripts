**Version 1.0.0**

- Improved Skill 1 accuracy; visibility checks now use the real distance to the target.
- Made the script standalone: aim.lua, prediction.lua, utils.lua, and ally_manager.lua are no longer required.
- Enemy speed tracking now warms up every tick and is not reset by repeated calls in the same frame.
- Aligned the final Magic Bullet point with the obstacle-bypass search point.
- Fixed Skill 2 cast blocking and target-selection lockups.
- Improved performance and FPS.
- Improved Skill 2 logic and fixed Skill 1 being used automatically while its switch is disabled.
- Added English translation, hold-to-shoot for Skill 1, and correct qLocalization handling for switches, sliders, binds, and target selection.
