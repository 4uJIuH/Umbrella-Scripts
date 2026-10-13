# Script releases

The release workflow creates a GitHub release from the matching tag and changelogs.
For Lua entries, it also writes or updates the Script Manager version manifest,
including on the first release. If that manifest already matches the release,
the workflow skips the empty commit.
Tinker Auto Farm is packaged from `scripts/tinker_auto_farm/package` as
`Tinker-Auto-Farm.zip`. Self Play is packaged from
`scripts/self_play_bot/package` as `Self-Play.zip`; this bundle is extracted
manually into the scripts folder. Package directories are zipped as-is. Packages
with a `lib/*.lua` directory also receive the Script Manager install manifest
used by Tinker Auto Farm. Other scripts attach their Lua file directly.

1. Update the matching script sources and both changelogs.
2. Commit the changes.
3. Tag and push the version (for example):

```bash
git tag rem-assistant-v1.0.0
git push origin rem-assistant-v1.0.0
```

Tag prefixes, package files, script categories (`dota`, `deadlock`, or `auxiliary`), and descriptions are
configured in `catalog.json`.
`readme.yml` updates the script pages and download statistics; `site.yml` builds and publishes
the GitHub Pages site.
