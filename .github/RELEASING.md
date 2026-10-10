# Script releases

The release workflow creates a GitHub release from the matching tag and changelogs.
Tinker Auto Farm is packaged from `scripts/tinker_auto_farm/package` as
`Tinker-Auto-Farm.zip`; the other scripts attach their Lua file directly.

1. Update the matching script sources and both changelogs.
2. Commit the changes.
3. Tag and push the version (for example):

```bash
git tag auto-spark-v1.0.1
git push origin auto-spark-v1.0.1
```

Tag prefixes, package files, and script descriptions are configured in `catalog.json`.
`readme.yml` updates the script pages and download statistics; `site.yml` builds and publishes
the GitHub Pages site.
