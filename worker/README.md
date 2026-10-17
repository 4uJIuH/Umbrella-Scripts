# umbrella-ratings

Cloudflare Worker + D1 for the 👍/👎 script ratings. One vote per Steam ID per script; pressing the other thumb switches the vote, pressing the same one removes it.

## Deploy

```
cd worker
npm i -g wrangler
wrangler login
wrangler d1 create umbrella-ratings
```

Put the printed `database_id` into `wrangler.toml`, then:

```
wrangler d1 execute umbrella-ratings --remote --file=schema.sql
wrangler deploy
```

Set the printed `https://umbrella-ratings.<account>.workers.dev` as `ratings_url` in `.github/catalog.json` and push. The site and Script Manager read the address from there; while it is empty the ratings are hidden.

## API

- `GET /ratings[?user=<steamid>]` returns `{ratings: {id: {up, down}}, mine: {id: 1|-1}}` (`mine` only with `user`).
- `POST /vote` with `{script, user, vote}` where vote is `1`, `-1` or `0` returns the new `{up, down, mine}` for that script.
