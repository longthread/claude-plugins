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

  // A plugin's changelog is optional: present, it becomes its own page and the plugin page links to
  // it; absent, nothing is emitted and nothing links anywhere. Same opt-in shape as FIGURES.
  const clPath = join(ROOT, dir, "CHANGELOG.md");
  const changelog = existsSync(clPath)
    ? read(dir, "CHANGELOG.md").replace(/^#\s+.*\n+/, "")
    : null;

  // The newest entry and plugin.json must name the same version. Nothing on the page would show the
  // disagreement — the install chip says one thing and the top entry says another — so a bump that
  // forgets the changelog, or a changelog that runs ahead of the bump, fails the build instead of
  // shipping quietly.
  if (changelog) {
    const newest = (changelog.match(/^##\s+v?([0-9][\w.+-]*)/m) || [])[1];
    if (newest !== manifest.version)
      throw new Error(
        `${dir}/CHANGELOG.md's newest entry is ${newest ?? "(no version heading found)"}, ` +
          `but ${dir}/.claude-plugin/plugin.json says ${manifest.version}`,
      );
  }

  return {
    name: p.name,
    slug: p.name,
    version: manifest.version,
    changelog,
    blurb: p.description,
    tagline,
    commands,
    readme,
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

/* A Herdr window: this session on the left, the split `pane:` opens on the right, and the
   background tab `tab:` opens in the strip above. Shows where each trigger puts the new session. */
const herdrWindow = () => `<div class="fig" role="img" aria-label="A Herdr window. The left pane is your session, where you typed 'pane: run the tests and fix failures'. A new Claude Code session has opened in a split on the right. In the tab strip above, a second tab named 'docs' was opened in the background by a 'tab:' message. Your cursor stays in the left pane.">
<svg viewBox="0 0 900 300" preserveAspectRatio="xMidYMid meet">
  <rect class="win" x="40" y="20" width="820" height="260" rx="8"/>
  <rect class="tabon" x="56" y="32" width="120" height="26" rx="4"/>
  <text class="tabt on" x="116" y="49" text-anchor="middle">work</text>
  <rect class="taboff" x="184" y="32" width="120" height="26" rx="4"/>
  <text class="tabt" x="244" y="49" text-anchor="middle">docs</text>
  <text class="note" x="316" y="49">← opened by tab: (in the background)</text>
  <line class="div" x1="40" y1="70" x2="860" y2="70"/>
  <line class="div" x1="450" y1="70" x2="450" y2="280"/>
  <text class="ph" x="62" y="100">this session · your cursor stays here</text>
  <text class="you" x="62" y="140">› pane: run the tests and fix failures</text>
  <text class="dim" x="62" y="170">Opened "tests" beside this one.</text>
  <text class="dim" x="62" y="192">Back to what we were doing…</text>
  <text class="ph lit" x="472" y="100">new session · opened by pane:</text>
  <text class="dim" x="472" y="140">› You are in ~/project. Run the test</text>
  <text class="dim" x="472" y="162">  suite, fix what fails, and report</text>
  <text class="dim" x="472" y="184">  what you changed.</text>
</svg>
</div>`;

const FIGURES = {
  programme: () => `
  <section class="band">
    <p class="eyebrow">The idea in one picture</p>
    <h2>The notes outlive every session</h2>
    <p>Each session's memory (top line) ends when the session ends. The notes file (bottom line)
      doesn't. The commands only ever write it or read it.</p>
    ${lifecycle()}
  </section>

  <section class="band">
    <p class="eyebrow">What it adds to your repo</p>
    <h2>A few plain markdown files</h2>
    <p>No database or service, and nothing to run. They're ordinary files you can read, edit and
      review in pull requests.</p>
    ${tree()}
  </section>

  <section class="band">
    <p class="eyebrow">Why the notes stay true</p>
    <h2>Every number comes with the command that checks it</h2>
    <p>A number written last week may be wrong today. So next to each number the notes keep the
      command that produces it, and <code>/programme:resume</code> <strong>runs</strong> that command
      instead of trusting the number.</p>
    ${verify()}
  </section>
`,
  "herdr-sessions": () => `
  <section class="band">
    <p class="eyebrow">The idea in one picture</p>
    <h2>Where each trigger puts the new session</h2>
    <p><code>pane:</code> opens a split beside you. <code>tab:</code> opens a tab you don't switch
      to. Either way your cursor stays where it was.</p>
    ${herdrWindow()}
  </section>
`,
};

/* A README's top half is the plain-language guide and renders as the page; everything from
   `## Reference` down is the detail and folds away. `<!-- site:figures -->` marks where a plugin's
   diagrams go. The README is the only source, so the page and GitHub can't disagree. */
for (const p of plugins) {
  const i = p.md.search(/^## Reference\s*$/m);
  p.guide = (i < 0 ? p.md : p.md.slice(0, i)).replace(/\n---\s*$/, "");
  p.ref = i < 0 ? "" : p.md.slice(i).replace(/^## Reference\s*\n/, "");
  // A command with no mention in the guide is one a newcomer would never learn about.
  for (const c of p.commands)
    if (!p.guide.includes(`/${p.name}:${c}`))
      throw new Error(`${p.slug}/README.md's guide (above ## Reference) never mentions /${p.name}:${c}`);
  // The home page card: the first thing you'd type, and who it's for, both read from the guide.
  p.example = (p.guide.match(/^1\. `([^`]+)`/m) || [])[1];
  p.when = (p.guide.match(/\*\*A good fit:\*\*\s*([\s\S]*?)(?:\n- |\n\n|$)/) || [])[1]?.replace(/\s+/g, " ");
}

const inline = (md) => marked.parseInline(md);
const noLinks = (html) => html.replace(/<\/?a\b[^>]*>/g, "");

const guideBands = (p) => {
  const [before, after = ""] = p.guide.split("<!-- site:figures -->");
  const band = (md) =>
    md.trim()
      ? `
  <section class="band">
    <article class="prose guide">
${marked.parse(md, { renderer })}
    </article>
  </section>
`
      : "";
  return band(before) + (FIGURES[p.slug] ? FIGURES[p.slug]() : "") + band(after);
};

/* ── pages ───────────────────────────────────────────────────────────────────────────────────── */

const index = shell({
  title: "longthread — Claude Code plugins for work that runs long",
  desc: market.description,
  main: `
  <section class="hero">
    <h1>Sessions end.<br>The work <em>doesn't.</em></h1>
    <p class="lede">Free plugins for Claude Code that help with work too big for one session: keeping
      notes the next session can trust, and running several sessions side by side.</p>
    ${thread()}
  </section>

  <section class="band" id="plugins">
    <p class="eyebrow">Plugins</p>
    <h2>Pick the one you need</h2>
    <ul class="plugins">
      ${plugins
        .map(
          (p) => `<li><a href="/${p.slug}/">
        <span class="name">${esc(p.name)}</span>
        <span class="ver">v${esc(p.version)}</span>
        <span class="go" aria-hidden="true">Read more →</span>
        <span class="blurb">${noLinks(inline(p.tagline))}</span>${
          p.when ? `
        <span class="when"><b>Good fit</b> ${noLinks(inline(p.when))}</span>` : ""
        }${
          p.example ? `
        <span class="eg"><b>You type</b> <code>${esc(p.example)}</code></span>` : ""
        }
      </a></li>`,
        )
        .join("\n      ")}
    </ul>
  </section>

  <section class="band">
    <p class="eyebrow">Install</p>
    <h2>Two commands in Claude Code</h2>
    <ol class="steps">
      <li><code class="type">/plugin marketplace add longthread/claude-plugins</code>
        <p>Once. Adds this collection to Claude Code.</p></li>
      <li><code class="type">/plugin install &lt;name&gt;@${esc(market.name)}</code>
        <p>For each plugin you want, for example <code>/plugin install ${esc(plugins[0].name)}@${esc(market.name)}</code>. It takes effect in your next session.</p></li>
    </ol>
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
    <p class="tagline">${inline(p.tagline)}</p>
    <div class="install">
      <code class="cmd">plugin install ${esc(p.name)}@${esc(market.name)}</code>
${p.changelog ? `      <a class="changelog-link" href="/${p.slug}/changelog">Changelog \u2192</a>` : ""}
    </div>
  </header>
${guideBands(p)}
  <section class="band">
${p.ref ? `    <details class="ref">
      <summary>Full reference <span>design notes, configuration and edge cases</span></summary>
      <article class="prose">
${marked.parse(p.ref, { renderer })}
      </article>
    </details>
  </section>` : "  </section>"}
`,
    }),
  );

  if (!p.changelog) continue;
  const cdir = join(dir, "changelog");
  mkdirSync(cdir, { recursive: true });
  writeFileSync(
    join(cdir, "index.html"),
    shell({
      title: `${p.name} changelog — longthread`,
      desc: `What changed in each release of ${p.name}.`,
      main: `
  <header class="detail-head">
    <a class="back" href="/${p.slug}">← ${esc(p.name)}</a>
    <h1>Changelog</h1>
    <p class="tagline">Every release of ${esc(p.name)}, newest first. Currently ${esc(p.version)}.</p>
  </header>
  <div class="brk" aria-hidden="true"></div>

  <section class="band">
    <article class="prose">
${marked.parse(p.changelog, { renderer })}
    </article>
  </section>
`,
    }),
  );
}

// A plugin that HAS a changelog and did not get a page would link to a 404 from its own header.
for (const p of plugins) {
  if (p.changelog && !existsSync(join(OUT, p.slug, "changelog", "index.html")))
    throw new Error(`${p.slug} has a CHANGELOG.md but no changelog page was written`);
}

console.log(`built ${OUT}`);
console.log(
  `  index.html + ${plugins.length} plugin page(s): ${plugins
    .map(
      (p) =>
        `${p.slug} (${p.commands.length} commands${p.changelog ? `, changelog @ ${p.version}` : ""})`,
    )
    .join(", ")}`,
);
if (!existsSync(join(OUT, cssName)))
  throw new Error(`${cssName} missing from output`);
