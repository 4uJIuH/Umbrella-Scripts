# Discord script update workflow

The `discord-sync` workflow polls the configured Discord threads and opens a
review-only pull request when a newer `.lua` attachment differs from the copy
in this repository. It never runs downloaded Lua and never merges a PR or
publishes a release automatically.

## Setup

1. Create a Discord bot and enable **Message Content Intent** in the Discord
   Developer Portal. Ask a server administrator to add it to the Umbrella
   server with **View Channel** and **Read Message History** access to the
   relevant forum and its threads. Do not use a user token or self-bot.
2. Add the bot token as the repository Actions secret `DISCORD_BOT_TOKEN`.
   Never put the token in this repository or send it in chat.
3. In repository Settings → Actions → General, allow read and write workflow
   permissions and allow GitHub Actions to create pull requests. Ensure GitHub
   Models is available to the repository.
4. Review `.github/threads.json`. It currently contains only known topic IDs
   for single-file Lua scripts that exist in the repository. Add entries as
   `"catalog_script_id": "discord_thread_id"` only after verifying both values.
   ZIP/multi-file packages, external scripts, and scripts without a repository
   Lua source are intentionally excluded.

## First run and review

1. Run **Actions → discord-sync → Run workflow**, leave `dry_run` enabled, and
   optionally set `only` to one configured script ID. A dry run does not save
   the baseline, so it is safe to repeat while checking the logs.
2. Once the bot can read the topics, run the workflow with `dry_run` disabled.
   This first non-dry run records the newest Lua attachment for each configured
   topic as its baseline; it does not create PRs.
3. Later scheduled runs compare new attachments with the baseline. Run manually
   with `dry_run` enabled to preview the version and generated release notes.
   Normal scheduled runs open a PR containing the Lua diff, bilingual
   changelog, Discord link, and recent topic messages.
4. Review the Lua diff and generated text before merging. After merging, create
   and push the release tag shown in the PR, such as
   `tinker-turret-dodge-v1.1.4`. The existing release workflow then publishes
   the downloadable asset and updates the version manifest.

   The workflow keeps at most one open update PR per script. If another version
   appears before that PR is merged, it waits and retries on the next scan.

GitHub Models receives the source diff and recent non-bot messages from the
thread to draft release notes. Treat its output as untrusted and review it.
Only the latest `.lua` attachment in a configured thread is considered; this
workflow does not handle ZIP or multi-file releases.

To validate the checked-in mapping and run the local tests:

```bash
python .github/discord_sync.py --validate-config
python -m unittest discover -s .github/tests -v
```
