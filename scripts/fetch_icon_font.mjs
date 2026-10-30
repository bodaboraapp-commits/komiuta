// Downloads a self-hosted, subsetted Material Symbols font containing only the
// icons the app actually uses. Run this whenever an icon is added/removed:
//
//   node scripts/fetch_icon_font.mjs
//
// The script extracts icon names from lib/**/*.{ex,heex}, requests the subsetted
// font from the Google Fonts API, and writes:
//   priv/static/fonts/material-symbols-subset.woff2
//   scripts/material-symbols-icons.txt   (the icon list actually included)
//
// It also prints the full-font fallback URL, which is used in app.css as a
// per-glyph fallback so a newly added icon can never render as a blank box.
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const lib = path.join(root, "lib");
const UA =
  "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36";
// The app only uses the default icon style (outlined, weight 400, fill 0,
// grade 0, optical size 24), so request a static subset rather than the full
// variable font. That cuts the download from ~108 KB to ~20 KB.
const AXES = "opsz,wght,FILL,GRAD@24,400,0,0";

// Icons produced dynamically (component props / helper functions) that a plain
// source scan cannot resolve to a literal.
const EXTRA = [
  "account_balance_wallet",
  "chevron_right",
  "credit_card",
  "directions_car",
  "explore",
  "hotel",
  "local_activity",
  "login",
  "menu",
  "payments",
  "travel_explore",
];

function walk(dir) {
  return fs.readdirSync(dir, { withFileTypes: true }).flatMap((entry) => {
    const full = path.join(dir, entry.name);
    return entry.isDirectory() ? walk(full) : [full];
  });
}

const names = new Set(EXTRA);
const spanRe = /material-symbols-outlined[^>]*>([\s\S]*?)</g;
const staticRe = /^[a-z0-9_]+$/;

for (const file of walk(lib)) {
  if (!/\.(ex|heex)$/.test(file)) continue;
  const text = fs.readFileSync(file, "utf8");

  for (const match of text.matchAll(spanRe)) {
    const inner = match[1].trim();
    if (staticRe.test(inner)) names.add(inner);
  }

  for (const match of text.matchAll(/icon:\s*"([a-z0-9_]+)"/g)) names.add(match[1]);
  for (const match of text.matchAll(/icon="([a-z0-9_]+)"/g)) names.add(match[1]);
}

const icons = [...names].filter((name) => staticRe.test(name)).sort();
if (icons.length < 100) {
  throw new Error(`Only found ${icons.length} icons — extraction looks wrong.`);
}

async function fetchText(url) {
  const response = await fetch(url, { headers: { "User-Agent": UA } });
  if (!response.ok) throw new Error(`HTTP ${response.status} for ${url}`);
  return response.text();
}

const subsetUrl =
  "https://fonts.googleapis.com/css2" +
  "?family=Material+Symbols+Outlined:" +
  AXES +
  "&icon_names=" +
  icons.join(",") +
  "&display=block";

const subsetCss = await fetchText(subsetUrl);
const subsetFontUrl = subsetCss.match(
  /src:\s*url\((https:[^)]+)\)\s*format\('woff2'\)/
)?.[1];

if (!subsetFontUrl) throw new Error("Could not find the subset font URL in the Google CSS.");

const fontResponse = await fetch(subsetFontUrl, { headers: { "User-Agent": UA } });
if (!fontResponse.ok) throw new Error(`Could not download the font: HTTP ${fontResponse.status}`);

const font = Buffer.from(await fontResponse.arrayBuffer());
const fontDir = path.join(root, "priv", "static", "fonts");
fs.mkdirSync(fontDir, { recursive: true });
fs.writeFileSync(path.join(fontDir, "material-symbols-subset.woff2"), font);
fs.writeFileSync(
  path.join(root, "scripts", "material-symbols-icons.txt"),
  icons.join("\n") + "\n",
);

const fullCss = await fetchText(
  "https://fonts.googleapis.com/css2?family=Material+Symbols+Outlined:" + AXES,
);
const fullFontUrl = fullCss.match(
  /src:\s*url\((https:[^)]+)\)\s*format\('woff2'\)/,
)?.[1];

console.log(
  JSON.stringify(
    {
      icons: icons.length,
      subsetBytes: font.length,
      subsetFile: "priv/static/fonts/material-symbols-subset.woff2",
      fullFontUrl,
    },
    null,
    2,
  ),
);
