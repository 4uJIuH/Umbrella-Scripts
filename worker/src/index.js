const CATALOG = "https://raw.githubusercontent.com/4uJIuH/umbrella-scripts/main/.github/catalog.json";
const STEAM_ID = /^\d{15,20}$/;
const RATINGS_TTL = 30;
const CATALOG_TTL = 3600;

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type",
};

function json(body, status = 200, extra = {}) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json; charset=utf-8", ...CORS, ...extra },
  });
}

async function cached(ctx, url, ttl, load) {
  const key = new Request(url);
  const hit = await caches.default.match(key);
  if (hit) return hit.json();
  const value = await load();
  const res = new Response(JSON.stringify(value), {
    headers: { "Content-Type": "application/json", "Cache-Control": "public, max-age=" + ttl },
  });
  ctx.waitUntil(caches.default.put(key, res));
  return value;
}

async function knownScripts(ctx) {
  const ids = await cached(ctx, "https://cache.local/catalog-ids", CATALOG_TTL, async () => {
    const res = await fetch(CATALOG);
    if (!res.ok) throw new Error("catalog " + res.status);
    const data = await res.json();
    return data.scripts.map((s) => s.id);
  });
  return new Set(ids);
}

async function totals(env, ctx) {
  return cached(ctx, "https://cache.local/ratings", RATINGS_TTL, async () => {
    const { results } = await env.DB.prepare(
      "SELECT script_id, SUM(vote = 1) AS up, SUM(vote = -1) AS down FROM votes GROUP BY script_id"
    ).all();
    const out = {};
    for (const r of results) out[r.script_id] = { up: r.up, down: r.down };
    return out;
  });
}

async function mine(env, user) {
  const { results } = await env.DB.prepare("SELECT script_id, vote FROM votes WHERE steam_id = ?").bind(user).all();
  const out = {};
  for (const r of results) out[r.script_id] = r.vote;
  return out;
}

async function handleGet(request, env, ctx) {
  const user = new URL(request.url).searchParams.get("user");
  const body = { ratings: await totals(env, ctx) };
  if (user) {
    if (!STEAM_ID.test(user)) return json({ error: "bad user" }, 400);
    body.mine = await mine(env, user);
  }
  return json(body);
}

async function handleVote(request, env, ctx) {
  let data;
  try {
    data = await request.json();
  } catch {
    return json({ error: "bad json" }, 400);
  }
  const { script, user, vote } = data || {};
  if (typeof user !== "string" || !STEAM_ID.test(user)) return json({ error: "bad user" }, 400);
  if (![-1, 0, 1].includes(vote)) return json({ error: "bad vote" }, 400);
  if (typeof script !== "string" || !(await knownScripts(ctx)).has(script)) return json({ error: "unknown script" }, 404);

  if (vote === 0) {
    await env.DB.prepare("DELETE FROM votes WHERE steam_id = ? AND script_id = ?").bind(user, script).run();
  } else {
    await env.DB.prepare(
      "INSERT INTO votes (steam_id, script_id, vote, updated) VALUES (?1, ?2, ?3, ?4) " +
        "ON CONFLICT (steam_id, script_id) DO UPDATE SET vote = excluded.vote, updated = excluded.updated"
    ).bind(user, script, vote, Math.floor(Date.now() / 1000)).run();
  }

  const row = await env.DB.prepare(
    "SELECT SUM(vote = 1) AS up, SUM(vote = -1) AS down FROM votes WHERE script_id = ?"
  ).bind(script).first();
  await caches.default.delete(new Request("https://cache.local/ratings"));
  return json({ script, up: row.up || 0, down: row.down || 0, mine: vote });
}

export default {
  async fetch(request, env, ctx) {
    if (request.method === "OPTIONS") return new Response(null, { status: 204, headers: CORS });
    const path = new URL(request.url).pathname;
    try {
      if (request.method === "GET" && path === "/ratings") return await handleGet(request, env, ctx);
      if (request.method === "POST" && path === "/vote") return await handleVote(request, env, ctx);
      return json({ error: "not found" }, 404);
    } catch (e) {
      return json({ error: "server" }, 500);
    }
  },
};
