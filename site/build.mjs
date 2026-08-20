import {
  readFileSync,
  readdirSync,
  writeFileSync,
  mkdirSync,
  rmSync,
  existsSync,
} from "node:fs";
import { createHash } from "node:crypto";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { marked } from "marked";

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..");
const OUT = join(ROOT, "docs");
const DOMAIN = "plugins.longthread.dev";

const read = (...p) => readFileSync(join(ROOT, ...p), "utf8");
const json = (...p) => JSON.parse(read(...p));

// The stylesheet carries a content hash so it can be cached for a year without a deploy serving
// anyone a stale one. Without the hash the filename is stable, so a browser that cached it keeps
// the old styles after a deploy — Cloudflare purges its own edge, not the visitor's disk.
const css = read("site", "style.css");
const cssName = `style.${createHash("sha256").update(css).digest("hex").slice(0, 8)}.css`;

const market = json(".claude-plugin", "marketplace.json");

const plugins = market.plugins.map((p) => {
  const dir = p.source.replace(/^\.\//, "");
  const manifest = json(dir, ".claude-plugin", "plugin.json");
  const readme = read(dir, "README.md");
  // The README opens with `# name` then its own one-line summary. Both are re-set by the page
  // header, so strip them rather than rendering the title twice.
  const body = readme.replace(/^#\s+.*\n+/, "");
  const tagline = (body.match(/^([\s\S]*?)\n\n/) || [, ""])[1]
    .replace(/\n/g, " ")
    .trim();

  // The command set comes from disk so it can never omit one; the order comes from the README,
  // which lists them in lifecycle order rather than alphabetically. A command the README stops
  // mentioning still appears, just last.
  const cmdDir = join(ROOT, dir, "commands");
  // Only the README's command list defines order — a passing mention earlier in the prose would
  // otherwise put whichever command the intro happens to name first at the head of the chips.
  const order = [
    ...readme.matchAll(/^- \*\*`\/[a-z][\w-]*:([a-z][\w-]*)/gm),
  ].map((m) => m[1]);
  const rank = (c) => (order.indexOf(c) < 0 ? 99 : order.indexOf(c));
  const commands = (existsSync(cmdDir) ? readdirSync(cmdDir) : [])
    .filter((f) => f.endsWith(".md"))
    .map((f) => f.replace(/\.md$/, ""))
    .sort((a, b) => rank(a) - rank(b) || a.localeCompare(b));

  return {
    name: p.name,
    slug: p.name,
    version: manifest.version,
    blurb: p.description,
    tagline,
    commands,
    md: body.replace(/^[\s\S]*?\n\n/, ""),
  };
});

const esc = (s) =>
  s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");

marked.setOptions({ gfm: true, breaks: false });
// Wide tables must scroll inside their own box; the page body must never scroll sideways.
const renderer = new marked.Renderer();
const baseTable = renderer.table.bind(renderer);
renderer.table = (...a) => `<div class="tablewrap">${baseTable(...a)}</div>`;

const shell = ({ title, desc, main, cls = "" }) => `<!doctype html>
<html lang="en" class="${cls}">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${esc(title)}</title>
<meta name="description" content="${esc(desc)}">
<meta property="og:title" content="${esc(title)}">
<meta property="og:description" content="${esc(desc)}">
<meta property="og:type" content="website">
<meta name="theme-color" content="#0e1426">
<link rel="icon" href="data:image/svg+xml,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 32 32'><rect width='32' height='32' rx='6' fill='%230e1426'/><path d='M5 16h8M19 16h8' stroke='%23c8964a' stroke-width='2.5' stroke-linecap='round'/><circle cx='16' cy='16' r='1.6' fill='%23c8964a'/></svg>">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=IBM+Plex+Mono:wght@400;500;600&family=IBM+Plex+Sans:wght@400;500;600&family=Newsreader:ital,opsz,wght@0,6..72,300;0,6..72,400;1,6..72,400&display=swap" rel="stylesheet">
<link rel="stylesheet" href="/${cssName}">
</head>
<body>
<div class="wrap">
  <header class="masthead">
    <a class="wordmark" href="/"><b>long</b><span>—</span>thread</a>
    <nav>
      <a href="/#plugins">Plugins</a>
      <a href="https://github.com/longthread/claude-plugins">GitHub</a>
    </nav>
  </header>
${main}
  <footer class="foot">
    <span>${DOMAIN}</span>
    <span>MIT · <a href="https://github.com/longthread/claude-plugins">longthread/claude-plugins</a></span>
  </footer>
</div>
</body>
</html>
`;

/* The signature: a thread crossing session boundaries. Solid where a session runs, dashed across
   the gap where context dies, unbroken end to end. It is the product's argument as one mark. */
const thread = () => {
  const y = 46;
  const seg = (x1, x2, delay) =>
    `<line class="run draw" x1="${x1}" y1="${y}" x2="${x2}" y2="${y}" style="--len:${x2 - x1}px;animation-delay:${delay}s"/>`;
  const gap = (x1, x2, delay) =>
    `<line class="gap draw" x1="${x1}" y1="${y}" x2="${x2}" y2="${y}" style="animation-delay:${delay}s"/>`;
  const node = (x, delay) =>
    `<circle class="node" cx="${x}" cy="${y}" r="4.5" style="animation-delay:${delay}s"/>`;
  const tick = (x, t, delay) =>
    `<text class="tick" x="${x}" y="${y + 26}" text-anchor="middle" style="animation-delay:${delay}s">${t}</text>`;

  return `<div class="thread" role="img" aria-label="A thread across three sessions. Each session is a solid run; between them the line goes dashed where the context ends, but never breaks.">
<svg viewBox="0 0 720 92" preserveAspectRatio="xMidYMid meet">
  ${seg(10, 190, 0)}${gap(190, 250, 0.45)}${seg(250, 430, 0.6)}${gap(430, 490, 1.05)}${seg(490, 706, 1.2)}
  ${node(10, 0)}${node(250, 0.6)}${node(490, 1.2)}
  <text class="under" x="220" y="${y - 16}" text-anchor="middle" style="animation-delay:.45s">context ends</text>
  ${tick(100, "session 1", 0.3)}${tick(340, "session 2", 0.9)}${tick(598, "session 3", 1.5)}
</svg>
</div>`;
};

/* ── figures, per plugin ─────────────────────────────────────────────────────────────────────
   A plugin with no entry here simply renders its README, so this is opt-in rather than a shape
   every future plugin has to satisfy. */

/* Where each command fires, and the claim the whole plugin rests on: the dashed row is context,
   which dies at every boundary; the solid row is the file, which does not. */
const lifecycle = () => {
  const X0 = 130,
    X1 = 872,
    S = 210,
    G = 56;
  const s1 = [X0, X0 + S];
  const g1 = [s1[1], s1[1] + G];
  const s2 = [g1[1], g1[1] + S];
  const g2 = [s2[1], s2[1] + G];
  const s3 = [g2[1], X1];
  const yCtx = 62,
    yLed = 152;

  const run = (a, b) =>
    `<line class="run" x1="${a}" y1="${yCtx}" x2="${b}" y2="${yCtx}"/>`;
  const brk = (a, b) =>
    `<line class="gap" x1="${a}" y1="${yCtx}" x2="${b}" y2="${yCtx}"/>`;
  const dot = (x) => `<circle class="node" cx="${x}" cy="${yCtx}" r="3.5"/>`;
  const key = (y, t) =>
    `<text class="key" x="118" y="${y + 4}" text-anchor="end">${t}</text>`;
  const tick = (a, b, t) =>
    `<text class="tick" x="${(a + b) / 2}" y="32" text-anchor="middle">${t}</text>`;

  // Commands attach to the ledger line, not to the sessions — writing and reading that file is the
  // whole of what they do, and the diagram says so by where the tick lands.
  const op = (x, y, t, anchor) =>
    `<line class="stem" x1="${x}" y1="${y + 8}" x2="${x}" y2="${yLed - 6}"/>
  <circle class="mark" cx="${x}" cy="${yLed}" r="3"/>
  <text class="op" x="${anchor === "end" ? x - 8 : anchor === "start" ? x + 8 : x}" y="${y}" text-anchor="${anchor}">${t}</text>`;

  return `<div class="fig" role="img" aria-label="Across three sessions: /programme:init runs once at the start, /programme:handoff at the end of each session, /programme:resume at the start of the next. The upper context line breaks between sessions; the ledger.md line beneath it runs unbroken, and every command attaches to it.">
<svg viewBox="0 0 900 186" preserveAspectRatio="xMidYMid meet">
  ${tick(...s1, "session 1")}${tick(...s2, "session 2")}${tick(...s3, "session 3")}

  ${key(yCtx, "context")}
  ${run(...s1)}${brk(...g1)}${run(...s2)}${brk(...g2)}${run(...s3)}
  ${dot(s1[0])}${dot(s2[0])}${dot(s3[0])}

  ${op(s1[0], 104, "/programme:init", "middle")}
  ${op(s1[1], 104, "/programme:handoff", "end")}
  ${op(s2[1], 104, "/programme:handoff", "end")}
  ${op(s2[0], 130, "/programme:resume", "start")}
  ${op(s3[0], 130, "/programme:resume", "start")}

  ${key(yLed, "ledger.md")}
  <line class="ledger" x1="${X0}" y1="${yLed}" x2="${X1}" y2="${yLed}"/>
</svg>
</div>`;
};

/* What lands in the repo. The question anyone asks before installing anything is what it will do
   to their tree, and a tree answers it faster than a paragraph. */
const TREE = [
  ["", "your-repo/", ""],
  ["├── ", "CLAUDE.md", "the pointer — when to write, and what outranks what"],
  ["├── ", ".claude/session-continuity.json", "docsRoot · compareBranch"],
  ["└── ", "docs/", ""],
  ["    ├── ", "deferred-work.md", "repo-wide — outlives any one programme"],
  ["    └── ", "programmes/", ""],
  [
    "        ├── ",
    "INDEX.md",
    "which programme is active, and on which branch",
  ],
  ["        └── ", "&lt;slug&gt;/", ""],
  [
    "            ├── ",
    "ledger.md",
    "the arc · position · decisions · gates · open forks",
  ],
  [
    "            ├── ",
    "NEXT-SESSION.md",
    "the next terminal condition, replaced wholesale",
  ],
  ["            ├── ", "deferred.md", "blocks closure while any row is open"],
  [
    "            └── ",
    "archive/",
    "closed phases, moved out when the ledger runs long",
  ],
];

const tree = () =>
  `<div class="fig tree">
${TREE.map(
  ([stem, path, note]) =>
    `    <span class="p"><i>${stem}</i>${path}</span><span class="n">${note}</span>`,
).join("\n")}
</div>`;

/* The idea that separates this from keeping notes: a figure is stored next to the command that
   re-derives it, and resume runs the command instead of believing the number. */
const VERIFY = [
  ["ahead of main", "0", "git rev-list --count origin/main..main"],
  ["tests", "412 passing", "npm test"],
  ["version", "1.4.0", "jq -r .version package.json"],
];

const verify = () =>
  `<div class="fig verify">
  <p class="file">NEXT-SESSION.md</p>
  <div class="vtable">
    <div class="vrow vhead"><span>claim</span><span>value</span><span>verify with</span></div>
${VERIFY.map(
  ([c, v, q]) =>
    `    <div class="vrow"><span>${c}</span><span class="val">${v}</span><code>${esc(q)}</code></div>`,
).join("\n")}
  </div>
  <p class="vflow"><span class="arm"></span>resume runs the third column, then compares<span class="arm"></span></p>
  <p class="pills"><span class="ok">ok</span><span class="drift">DRIFTED</span></p>
</div>`;

const FIGURES = {
  programme: () => `
  <div class="brk" aria-hidden="true"></div>

  <section class="band">
    <p class="eyebrow">How it works</p>
    <h2>One file crosses the boundary the context can't</h2>
    <p><code>/programme:handoff</code> interviews you and writes the ledger at the end of a thread.
      <code>/programme:resume</code> reads it at the start of the next one. Neither depends on
      anything surviving in the window.</p>
    ${lifecycle()}
    <p class="cap"><code>/programme:status</code> reads the same files any time and writes nothing —
      a status that quietly repairs the record can't tell you whether the record is honest.</p>
  </section>

  <div class="brk" aria-hidden="true"></div>

  <section class="band">
    <p class="eyebrow">What it creates</p>
    <h2>Six markdown files and one pointer</h2>
    <p>No database, no service, nothing to run. Plain files in your repo, reviewed in pull requests
      and read by anyone — the model included.</p>
    ${tree()}
  </section>

  <div class="brk" aria-hidden="true"></div>

  <section class="band">
    <p class="eyebrow">Why it doesn't just go stale</p>
    <h2>Every figure carries the command that re-derives it</h2>
    <p>A number that was true when it was written is not evidence. So the record stores the check
      beside the claim, and resuming <strong>runs</strong> it rather than believing it.</p>
    ${verify()}
    <p class="cap">In the repo this was extracted from, one commit is titled
      <em>“correct the ahead-of-origin claim, which went stale as it was written.”</em> That figure
      is now recorded as a range, because no document can state its own push state truthfully.</p>
  </section>
`,
};

/* ── pages ───────────────────────────────────────────────────────────────────────────────────── */

const index = shell({
  title: "longthread — Claude Code plugins for work that runs long",
  desc: market.description,
  main: `
  <section class="hero">
    <h1>Sessions end.<br>The work <em>doesn't.</em></h1>
    <p class="lede">Claude Code plugins for projects that outlast a single context window — so the
      next session reads where you were instead of working it out again from the code.</p>
    ${thread()}
    <div class="install">
      <code class="cmd">plugin marketplace add longthread/claude-plugins</code>
    </div>
  </section>

  <section class="band" id="plugins">
    <p class="eyebrow">Plugins</p>
    <ul class="plugins">
      ${plugins
        .map(
          (p) => `<li><a href="/${p.slug}/">
        <span class="name">${esc(p.name)}</span>
        <span class="ver">v${esc(p.version)}</span>
        <span class="go" aria-hidden="true">→</span>
        <span class="blurb">${esc(p.blurb)}</span>
        <span class="cmds">${p.commands
          .map((c) => `<em>/${esc(p.name)}:${esc(c)}</em>`)
          .join("")}</span>
      </a></li>`,
        )
        .join("\n      ")}
    </ul>
  </section>
`,
});

// Rebuild from empty: a hashed stylesheet name means stale ones would otherwise pile up forever.
rmSync(OUT, { recursive: true, force: true });
mkdirSync(OUT, { recursive: true });
writeFileSync(join(OUT, "index.html"), index);
writeFileSync(join(OUT, cssName), css);

// Cloudflare Pages reads _headers at deploy time. No script runs on this site at all, so the
// policy can forbid scripts outright; inline styles stay allowed because the hero thread carries
// its animation delays as style attributes.
writeFileSync(
  join(OUT, "_headers"),
  `/*
  X-Content-Type-Options: nosniff
  Referrer-Policy: strict-origin-when-cross-origin
  X-Frame-Options: DENY
  Content-Security-Policy: default-src 'self'; script-src 'none'; style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; font-src https://fonts.gstatic.com; img-src 'self' data:; base-uri 'none'; form-action 'none'; frame-ancestors 'none'

/*.css
  Cache-Control: public, max-age=31536000, immutable
`,
);

for (const p of plugins) {
  const dir = join(OUT, p.slug);
  mkdirSync(dir, { recursive: true });
  writeFileSync(
    join(dir, "index.html"),
    shell({
      title: `${p.name} — longthread`,
      desc: p.blurb,
      main: `
  <header class="detail-head">
    <a class="back" href="/">← all plugins</a>
    <h1>${esc(p.name)}</h1>
    <p class="tagline">${esc(p.tagline)}</p>
    <div class="install">
      <code class="cmd">plugin install ${esc(p.name)}@${esc(market.name)}</code>
    </div>
  </header>
${FIGURES[p.slug] ? FIGURES[p.slug]() : ""}
  <div class="brk" aria-hidden="true"></div>

  <section class="band">
    <p class="eyebrow">Reference</p>
    <article class="prose">
${marked.parse(p.md, { renderer })}
    </article>
  </section>
`,
    }),
  );
}

console.log(`built ${OUT}`);
console.log(
  `  index.html + ${plugins.length} plugin page(s): ${plugins
    .map((p) => `${p.slug} (${p.commands.length} commands)`)
    .join(", ")}`,
);
if (!existsSync(join(OUT, cssName)))
  throw new Error(`${cssName} missing from output`);
