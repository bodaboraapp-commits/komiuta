// Cloudflare Worker that pings the Render app on a schedule.
//
// Most reliable free option if the domain is already on Cloudflare:
// Cloudflare's scheduler does not suffer the long delays of GitHub Actions.
//
// The default path is "/" - the homepage performs database reads, which also
// keeps a free managed MySQL (Aiven) from going idle. Set PING_PATH to
// "/robots.txt" for a cheap ping that skips the database.
//
// SETUP (Cloudflare dashboard, no CLI needed)
//   1. Cloudflare dashboard -> Workers & Pages -> Create -> Worker.
//   2. Name it e.g. `komiuta-keepalive`, paste this file as the Worker code.
//   3. Settings -> Variables and Secrets -> add:
//        RENDER_URL = https://komiuta-xxxx.onrender.com
//        PING_PATH  = /                       (optional)
//   4. Settings -> Trigger Events -> Cron Triggers -> add `*/10 * * * *`
//      (every 10 minutes; free Workers plans include cron triggers).
//   5. Deploy.
//
// Open the Worker URL manually to run one ping and see the result.

export default {
  async scheduled(_event, env, ctx) {
    ctx.waitUntil(ping(env));
  },

  async fetch(_request, env) {
    const result = await ping(env);
    return new Response(JSON.stringify(result, null, 2), {
      headers: { "content-type": "application/json" },
    });
  },
};

async function ping(env) {
  const base = (env.RENDER_URL || "").replace(/\/+$/, "");
  const path = `/${(env.PING_PATH || "/").replace(/^\/+/, "")}`;

  if (!base) {
    return { ok: false, error: "RENDER_URL is not configured" };
  }

  const url = `${base}${path}?ts=${Date.now()}`;

  try {
    const response = await fetch(url, {
      headers: { "user-agent": "komiuta-keepalive-worker" },
      cf: { cacheTtl: 0 },
    });

    return { ok: response.ok, status: response.status, url };
  } catch (error) {
    return { ok: false, error: String(error), url };
  }
}
