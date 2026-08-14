import {
  readFileSync,
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
  return {
    name: p.name,
    slug: p.name,
    version: manifest.version,
    blurb: p.description,
    tagline,
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

const figure = (n, accent, k) =>
  `<li><div class="n">${n}<span>${accent}</span></div><span class="k">${k}</span></li>`;

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

  <div class="brk" aria-hidden="true"></div>

  <section class="band" id="plugins">
    <p class="eyebrow">Plugins</p>
    <h2>What's here</h2>
    <ul class="plugins">
      ${plugins
        .map(
          (p) => `<li><a href="/${p.slug}/">
        <span class="name">${esc(p.name)}</span>
        <span class="ver">v${esc(p.version)}</span>
        <span class="go" aria-hidden="true">→</span>
        <span class="blurb">${esc(p.blurb)}</span>
      </a></li>`,
        )
        .join("\n      ")}
    </ul>
  </section>

  <div class="brk" aria-hidden="true"></div>

  <section class="band">
    <p class="eyebrow">Why a file, not a hook</p>
    <h2>The record did the work before any of this existed</h2>
    <p>These plugins were extracted from a project that had already solved session continuity by
      hand, over about fifteen sessions. Before there was a plugin, its ledger was rewritten
      <strong>58 times in seven days</strong> — with nothing automating it.</p>
    <ul class="figures">
      ${figure(58, "", "ledger commits in 7 days")}
      ${figure("~4", "", "writes per session, at phase boundaries")}
      ${figure(0, "", "hooks, skills or commands that triggered one")}
    </ul>
    <p style="margin-top:2rem">What drove those writes was two pieces of prose that were always
      loaded: a ledger whose own header states how to maintain it, and a <code>CLAUDE.md</code>
      pointer saying when to write and which document wins. <strong>So that is what these plugins
      install first.</strong> The commands are conveniences on top — useful, but not the mechanism.</p>
  </section>

  <div class="brk" aria-hidden="true"></div>

  <section class="band">
    <p class="eyebrow">Getting started</p>
    <h2>Two commands, then it's yours</h2>
    <div class="install" style="margin-bottom:1.25rem">
      <code class="cmd">plugin marketplace add longthread/claude-plugins</code>
    </div>
    <div class="install" style="margin-bottom:1.25rem">
      <code class="cmd">plugin install programme@longthread</code>
    </div>
    <p>Then <code>/programme:init &lt;name&gt;</code> in the repo you want to track. It interviews you
      for the starting position and refuses to bootstrap a repo that is really a series of unrelated
      tickets — a ledger nobody needs goes stale, and a stale record is worse than none.</p>
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
  <article class="prose">
${marked.parse(p.md, { renderer })}
  </article>
`,
    }),
  );
}

console.log(`built ${OUT}`);
console.log(
  `  index.html + ${plugins.length} plugin page(s): ${plugins.map((p) => p.slug).join(", ")}`,
);
if (!existsSync(join(OUT, cssName)))
  throw new Error(`${cssName} missing from output`);
