# Tinker Turret Dodge releases

The release workflow creates a GitHub release and attaches
`scripts/tinker_turret_dodge/tinker_turret_dodge.lua`.

1. Update the script version and both changelogs.
2. Commit the changes.
3. Tag and push the version:

```bash
git tag tinker-turret-dodge-v1.1.4
git push origin tinker-turret-dodge-v1.1.4
```

The tag prefix and script descriptions are configured in `catalog.json`.
`readme.yml` updates the script page and download statistics; `site.yml` builds
and publishes the GitHub Pages site.
