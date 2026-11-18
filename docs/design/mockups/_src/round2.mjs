// Builds the Round 2 mockups (Spec #186, Work Item #190) in the direction the
// owner chose in Round 1: Slate and sage, with Lucide icons (ledger L22).
//
//   node docs/design/mockups/_src/round2.mjs          # HTML only
//   node docs/design/mockups/_src/round2.mjs --png    # HTML and PNG (headless Chrome)
//
// Nine phone screens (390 px) plus an Event home without a cover photo, and two
// laptop screens (1280 px), each in light and dark. Every file carries the same
// `:root` token block as Round 1.

import { mkdirSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { exportPng, here, iconFn, interFont, tokensCss } from './kit.mjs';

const direction = 'slate-sage';
const outDir = join(here, '..', 'round-2');
const i = iconFn('lucide');
const phone = 390;

// ---------------------------------------------------------------- styles

const css = `
* { box-sizing: border-box; margin: 0; padding: 0; }
body {
  background: var(--cp-background); color: var(--cp-text); position: relative; overflow: hidden;
  font-family: var(--cp-font-text); font-size: var(--cp-type-body); line-height: 1.4;
  -webkit-font-smoothing: antialiased;
}
h1, h2, h3 { font-variation-settings: 'opsz' var(--cp-font-heading-opsz); letter-spacing: -0.01em; }
h1 { font-size: var(--cp-type-title); font-weight: 650; line-height: 1.2; }
h2 { font-size: var(--cp-type-section); font-weight: 620; }
h3 { font-size: 15px; font-weight: 620; }
.icon { display: inline-flex; align-items: center; justify-content: center; line-height: 1; flex: none; }
.icon svg { display: block; }
.muted { color: var(--cp-text-muted); }
.grow { flex: 1; min-width: 0; }
.tnum { font-feature-settings: 'tnum'; }

/* Phone chrome */
.status-bar { height: 44px; display: flex; align-items: center; justify-content: space-between;
  padding: 0 24px; font-size: 15px; font-weight: 600; }
.status-bar .dots { display: flex; gap: 5px; }
.status-bar .dots i { width: 17px; height: 10px; border-radius: 3px; background: var(--cp-text); opacity: .85; display: block; }
.top-bar { height: 52px; display: flex; align-items: center; padding: 0 4px; gap: 4px; }
.top-bar .btn { width: var(--cp-tap-min); height: var(--cp-tap-min); display: flex; align-items: center; justify-content: center; position: relative; }
.top-bar .title { flex: 1; font-size: var(--cp-type-section); font-weight: 620; font-variation-settings: 'opsz' 32; padding-left: 4px; }
.btn-add { width: 36px; height: 36px; border-radius: 50%; background: var(--cp-accent); color: var(--cp-on-accent);
  display: flex; align-items: center; justify-content: center; margin: 0 8px; }
.large-title { padding: 4px var(--cp-space-lg) 0; display: flex; align-items: center; justify-content: space-between; }
.nav { position: absolute; left: 0; right: 0; bottom: 0; height: 84px; padding-bottom: 20px;
  background: var(--cp-surface); border-top: 1px solid var(--cp-border); display: grid; grid-template-columns: repeat(5, 1fr); }
.nav div { display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 3px;
  font-size: 11px; font-weight: 600; color: var(--cp-text-muted); }
.nav .on { color: var(--cp-accent); }
.nav .on .pill { background: var(--cp-accent-soft); }
.nav .pill { width: 56px; height: 30px; border-radius: 15px; display: flex; align-items: center; justify-content: center; }
.save-bar { position: absolute; left: 0; right: 0; bottom: 0; padding: 12px var(--cp-space-lg) 32px;
  background: var(--cp-surface); border-top: 1px solid var(--cp-border); display: flex; align-items: center; gap: var(--cp-space-md); }
.save-bar .note { flex: 1; font-size: 13px; font-weight: 600; color: var(--cp-status-overdue); display: flex; align-items: center; gap: 6px; }

/* Layout */
.page { padding: 0 var(--cp-space-lg); display: flex; flex-direction: column; gap: var(--cp-space-xl); }
.stack-sm { display: flex; flex-direction: column; gap: var(--cp-space-sm); }
.stack-md { display: flex; flex-direction: column; gap: var(--cp-space-md); }
.stack-lg { display: flex; flex-direction: column; gap: var(--cp-space-lg); }
.hrow { display: flex; align-items: center; gap: var(--cp-space-sm); }
.wrap { flex-wrap: wrap; }
.section-head { display: flex; align-items: center; justify-content: space-between; min-height: 32px; gap: 8px; }
.section-head a { color: var(--cp-accent); font-size: 14px; font-weight: 600; text-decoration: none; display: flex; align-items: center; }
.section-head .count { font-size: 13px; color: var(--cp-text-muted); font-weight: 500; }
.overline { font-size: 12px; font-weight: 650; letter-spacing: .04em; text-transform: uppercase; color: var(--cp-text-muted); }

/* Surfaces */
.card { background: var(--cp-surface); border: 1px solid var(--cp-border); border-radius: var(--cp-radius-md); box-shadow: var(--cp-shadow-card); }
.card-pad { padding: var(--cp-space-lg); }
.list > .row + .row, .list > .row + .sub-head, .list > .sub-head + .row { border-top: 1px solid var(--cp-border); }
.row { display: flex; align-items: center; gap: var(--cp-space-md); padding: 12px var(--cp-space-lg); min-height: 60px; }
.row > .icon.trail { color: var(--cp-text-muted); }
.row.sel { background: var(--cp-accent-soft); }
.row-title { font-weight: 560; }
.row-sub { font-size: 13px; color: var(--cp-text-muted); display: flex; align-items: center; gap: 4px; margin-top: 2px; }
.amount { font-weight: 620; font-feature-settings: 'tnum'; white-space: nowrap; text-align: right; }
.amount small { display: block; font-size: 12px; font-weight: 500; color: var(--cp-text-muted); }

/* Chips and badges */
.chip { display: inline-flex; align-items: center; gap: 4px; height: 28px; padding: 0 10px;
  border-radius: var(--cp-radius-pill); font-size: var(--cp-type-label); font-weight: 600; white-space: nowrap; }
.chip-neutral { background: var(--cp-accent-soft); color: var(--cp-accent); }
.chip-quiet { background: transparent; border: 1px solid var(--cp-border); color: var(--cp-text-muted); }
.chip-done { background: var(--cp-status-done-soft); color: var(--cp-status-done); }
.chip-due { background: var(--cp-status-due-soft); color: var(--cp-status-due); }
.chip-overdue { background: var(--cp-status-overdue-soft); color: var(--cp-status-overdue); }
.chip .dot { width: 7px; height: 7px; border-radius: 50%; background: currentColor; }
.badge { min-width: 22px; height: 22px; padding: 0 6px; border-radius: 11px; background: var(--cp-accent);
  color: var(--cp-on-accent); font-size: 12px; font-weight: 700; display: inline-flex; align-items: center; justify-content: center; }
.filters { display: flex; gap: var(--cp-space-sm); overflow: hidden; }
.filter { height: 34px; padding: 0 12px; border-radius: var(--cp-radius-pill); border: 1px solid var(--cp-border);
  background: var(--cp-surface); font-size: 14px; font-weight: 550; display: inline-flex; align-items: center; gap: 4px; white-space: nowrap; }
.filter.on { background: var(--cp-accent-soft); border-color: transparent; color: var(--cp-accent); }

/* Avatars */
.avatar { width: 40px; height: 40px; border-radius: 50%; background: var(--cp-accent-soft); color: var(--cp-accent);
  font-size: 14px; font-weight: 700; display: flex; align-items: center; justify-content: center; flex: none; }
.avatar.sm { width: 32px; height: 32px; font-size: 11px; }
.avatar.lg { width: 64px; height: 64px; font-size: 22px; }
.avatar.blank { background: var(--cp-border); color: var(--cp-text-muted); }
.stack-av { display: flex; }
.stack-av .avatar { border: 2px solid var(--cp-background); margin-left: -6px; }
.stack-av .avatar:first-child { margin-left: 0; }
.tile-icon { width: 40px; height: 40px; border-radius: var(--cp-radius-sm); background: var(--cp-accent-soft);
  color: var(--cp-accent); display: flex; align-items: center; justify-content: center; flex: none; }
.thumb { width: 64px; height: 64px; border-radius: var(--cp-radius-md); overflow: hidden; flex: none;
  background: var(--cp-accent-soft); color: var(--cp-accent); display: flex; align-items: center; justify-content: center; }
.thumb svg.photo { width: 100%; height: 100%; display: block; }

/* Buttons */
.btn-primary, .btn-secondary, .btn-text { height: 48px; border-radius: var(--cp-radius-md); font-weight: 620; font-size: 15px;
  display: inline-flex; align-items: center; justify-content: center; gap: 8px; padding: 0 18px; white-space: nowrap; }
.btn-primary { background: var(--cp-accent); color: var(--cp-on-accent); }
.btn-secondary { background: var(--cp-surface); color: var(--cp-accent); border: 1px solid var(--cp-border); }
.btn-text { color: var(--cp-accent); padding: 0 8px; }
.btn-sm { height: 36px; font-size: 14px; padding: 0 12px; border-radius: var(--cp-radius-sm); }
.btn-dashed { height: 52px; border-radius: var(--cp-radius-md); border: 1.5px dashed var(--cp-border); color: var(--cp-accent);
  font-weight: 620; display: flex; align-items: center; justify-content: center; gap: 8px; }
.full { width: 100%; }

/* Form fields */
.field { display: flex; flex-direction: column; gap: 6px; }
.field > label, .q-label { font-size: 13px; font-weight: 620; display: flex; align-items: center; gap: 6px; }
.req { color: var(--cp-status-overdue); }
.input { height: 48px; border: 1px solid var(--cp-border); border-radius: var(--cp-radius-sm); background: var(--cp-surface);
  padding: 0 12px; display: flex; align-items: center; gap: 8px; font-size: 15px; white-space: nowrap; overflow: hidden; }
.input .ph { color: var(--cp-text-muted); }
.input.focus { border: 2px solid var(--cp-accent); padding: 0 11px; }
.input.error { border: 2px solid var(--cp-status-overdue); padding: 0 11px; }
.help { font-size: 12px; color: var(--cp-text-muted); line-height: 1.4; }
.err { font-size: 12px; font-weight: 600; color: var(--cp-status-overdue); display: flex; align-items: center; gap: 4px; }
.seg { display: grid; grid-auto-flow: column; grid-auto-columns: 1fr; background: var(--cp-background);
  border: 1px solid var(--cp-border); border-radius: var(--cp-radius-sm); padding: 3px; height: 44px; }
.seg span { display: flex; align-items: center; justify-content: center; gap: 6px; border-radius: 6px; font-size: 14px; font-weight: 600; color: var(--cp-text-muted); }
.seg .on { background: var(--cp-surface); color: var(--cp-text); box-shadow: 0 1px 2px rgba(16,24,40,.12); }
.opts { display: flex; flex-wrap: wrap; gap: 8px; }
.opt { min-height: 36px; padding: 0 14px; border-radius: var(--cp-radius-pill); border: 1px solid var(--cp-border);
  background: var(--cp-surface); font-size: 14px; font-weight: 550; display: inline-flex; align-items: center; gap: 6px; }
.opt.on { background: var(--cp-accent); border-color: var(--cp-accent); color: var(--cp-on-accent); }
.opts.error .opt { border-color: var(--cp-status-overdue); }
.switch-row { display: flex; align-items: center; gap: 12px; min-height: 48px; }
.switch { width: 46px; height: 28px; border-radius: 14px; background: var(--cp-border); position: relative; flex: none; }
.switch::after { content: ''; position: absolute; top: 3px; left: 3px; width: 22px; height: 22px; border-radius: 50%; background: var(--cp-surface); box-shadow: 0 1px 2px rgba(0,0,0,.2); }
.switch.on { background: var(--cp-accent); }
.switch.on::after { left: 21px; }
.private { border: 1px solid var(--cp-border); border-radius: var(--cp-radius-md); background: var(--cp-background); padding: var(--cp-space-lg); }
.banner-msg { border-radius: var(--cp-radius-md); padding: 12px 14px; display: flex; gap: 10px; font-size: 14px; align-items: flex-start; }
.banner-msg.error { background: var(--cp-status-overdue-soft); color: var(--cp-status-overdue); }
.banner-msg.info { background: var(--cp-accent-soft); color: var(--cp-text); }
.banner-msg.info .icon { color: var(--cp-accent); }

/* Cover */
.cover { height: 156px; border-radius: var(--cp-radius-lg); overflow: hidden; position: relative; background: var(--cp-banner); color: var(--cp-on-banner); }
.cover svg.photo { width: 100%; height: 100%; display: block; }
.cover .big { position: absolute; right: 18px; top: 18px; opacity: .9; }
.cover .label { position: absolute; left: 16px; bottom: 14px; font-size: var(--cp-type-label); font-weight: 600; opacity: .9; }

/* Stats */
.stats { display: grid; grid-template-columns: repeat(3, 1fr); gap: var(--cp-space-sm); }
.stat { padding: var(--cp-space-md); display: flex; flex-direction: column; gap: 6px; min-height: 104px; }
.stat .k { font-size: var(--cp-type-caption); font-weight: 600; color: var(--cp-text-muted); display: flex; align-items: center; gap: 6px; }
.stat .v { font-size: var(--cp-type-stat); font-weight: 650; font-variation-settings: 'opsz' 32; font-feature-settings: 'tnum'; }
.stat .s { font-size: var(--cp-type-caption); color: var(--cp-text-muted); }
.bar { height: 8px; border-radius: 4px; background: var(--cp-border); overflow: hidden; }
.bar i { display: block; height: 100%; background: var(--cp-accent); border-radius: 4px; }
.time { width: 50px; display: flex; flex-direction: column; font-feature-settings: 'tnum'; flex: none; }
.time strong { font-size: 15px; font-weight: 650; }
.time span { font-size: 11px; color: var(--cp-text-muted); font-weight: 600; }
.tiles { display: grid; grid-template-columns: 1fr 1fr; gap: var(--cp-space-sm); }
.tile { display: flex; align-items: center; gap: 10px; padding: 14px 12px; min-height: 64px;
  background: var(--cp-surface); border: 1px solid var(--cp-border); border-radius: var(--cp-radius-md); }
.tile .row-sub { font-size: 12px; }
.check { width: 24px; height: 24px; border-radius: 50%; border: 2px solid var(--cp-border); flex: none; display: flex; align-items: center; justify-content: center; }
.check.on { background: var(--cp-status-done); border-color: var(--cp-status-done); color: var(--cp-surface); }
.menu { position: absolute; z-index: 5; background: var(--cp-surface); border: 1px solid var(--cp-border); border-radius: var(--cp-radius-md);
  box-shadow: 0 8px 24px rgba(16,24,40,.16); padding: 6px; min-width: 200px; }
.menu div { display: flex; align-items: center; gap: 12px; height: 48px; padding: 0 12px; border-radius: var(--cp-radius-sm); font-weight: 560; }
.menu div .icon { color: var(--cp-accent); }

/* Laptop */
.app { display: grid; grid-template-columns: 248px 1fr; height: 100vh; }
.side { background: var(--cp-surface); border-right: 1px solid var(--cp-border); padding: 20px 14px; display: flex; flex-direction: column; gap: 4px; }
.side .brand { display: flex; align-items: center; gap: 10px; font-weight: 700; font-size: 17px; padding: 0 8px 18px; font-variation-settings: 'opsz' 32; }
.side .brand svg { width: 32px; height: 32px; border-radius: 8px; }
.side .item { height: 40px; border-radius: var(--cp-radius-sm); padding: 0 10px; display: flex; align-items: center; gap: 12px;
  font-size: 14px; font-weight: 560; color: var(--cp-text-muted); }
.side .item.on { background: var(--cp-accent-soft); color: var(--cp-accent); }
.side .item .badge { margin-left: auto; }
.side .group { margin-top: 18px; padding: 0 10px 6px; }
.side .event { display: flex; align-items: center; gap: 10px; padding: 8px 10px; margin-bottom: 4px; }
.side .event .thumb { width: 36px; height: 36px; border-radius: 8px; }
.side .event b { font-size: 14px; font-weight: 620; display: block; }
.side .event span { font-size: 12px; color: var(--cp-text-muted); }
.side .me { margin-top: auto; display: flex; align-items: center; gap: 10px; padding: 10px; border-top: 1px solid var(--cp-border); font-size: 14px; font-weight: 560; }
.main { overflow: hidden; }
.main-inner { max-width: 1080px; padding: 28px 40px; display: flex; flex-direction: column; gap: 24px; }
.cols-2 { display: grid; grid-template-columns: 1fr 1fr; gap: 20px; align-items: start; }
.cols-3 { display: grid; grid-template-columns: repeat(3, 1fr); gap: 16px; }
.split { display: grid; grid-template-columns: 400px 1fr; height: 100vh; }
.split .pane { border-right: 1px solid var(--cp-border); display: flex; flex-direction: column; overflow: hidden; }
.kv { display: grid; grid-template-columns: 160px 1fr; row-gap: 12px; font-size: 14px; }
.kv dt { color: var(--cp-text-muted); }
.kv dd { font-weight: 560; }
`;

// ---------------------------------------------------------------- pieces

function doc({ title, mode, width, height, body }) {
  return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=${width}">
<title>${title} · Slate and sage · ${mode}</title>
<link rel="stylesheet" href="${interFont}">
<style>
/* Tokens: Slate and sage, ${mode}. These names become the app's design tokens. */
:root {
${tokensCss(direction, mode)}
}
html, body { width: ${width}px; height: ${height}px; }
${css}
</style>
</head>
<body>
${body}
</body>
</html>
`;
}

const statusBar = `<div class="status-bar"><span>9:41</span><span class="dots"><i></i><i></i></span></div>`;

function topBar({ lead = 'back', title = '', actions = '' } = {}) {
  return `<div class="top-bar">
    <span class="btn">${i(lead, 24)}</span>
    <span class="title">${title}</span>
    ${actions}
  </div>`;
}

const action = (key) => `<span class="btn">${i(key, 22)}</span>`;
const addAction = `<span class="btn-add">${i('add', 22)}</span>`;

function nav(active) {
  const items = [['calendar', 'Events'], ['tasks', 'Tasks'], ['chat', 'Chat'], ['budget', 'Budget'], ['profile', 'Profile']];
  return `<nav class="nav">${items.map(([k, label]) =>
    `<div class="${label === active ? 'on' : ''}"><span class="pill">${i(k, 22)}</span>${label}</div>`).join('')}</nav>`;
}

// A stand-in for an organizer's uploaded photo: a lakeside venue at dusk.
// Real covers are the organizer's own photos (Req 43); this only shows how a
// photo sits in the banner and the thumbnails.
function photo(id = 'p') {
  return `<svg class="photo" viewBox="0 0 400 160" preserveAspectRatio="xMidYMid slice" aria-hidden="true">
  <defs>
    <linearGradient id="${id}sky" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#8FB3C9"/><stop offset="1" stop-color="#E9D6B8"/></linearGradient>
    <linearGradient id="${id}lake" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#7C9DB0"/><stop offset="1" stop-color="#3E5A6B"/></linearGradient>
  </defs>
  <rect width="400" height="160" fill="url(#${id}sky)"/>
  <circle cx="300" cy="62" r="16" fill="#F6E7C9" opacity=".9"/>
  <path d="M0 92 L60 64 L120 84 L190 52 L260 80 L330 58 L400 82 L400 110 L0 110Z" fill="#6E8A7A"/>
  <path d="M0 100 L80 82 L150 96 L230 76 L310 94 L400 86 L400 112 L0 112Z" fill="#4E6B5A"/>
  <rect x="96" y="80" width="120" height="30" fill="#E8E2D6"/>
  <rect x="96" y="76" width="120" height="6" fill="#B9A991"/>
  ${[0, 1, 2, 3, 4, 5, 6, 7].map((n) => `<rect x="${104 + n * 14}" y="88" width="8" height="12" fill="#5B6E78"/>`).join('')}
  <rect x="0" y="108" width="400" height="52" fill="url(#${id}lake)"/>
  <rect x="96" y="112" width="120" height="10" fill="#C9C3B6" opacity=".35"/>
  <path d="M0 106 Q20 88 34 106Z M30 108 Q46 84 62 108Z M330 106 Q348 86 364 106Z M356 108 Q374 90 392 108Z" fill="#33503F"/>
</svg>`;
}

// The CrewPoint mark (Round 1 logo strip), in the chosen palette.
function logo(mode) {
  const c = mode === 'light'
    ? { bg: '#FFFFFF', ink: '#1E2A33', accent: '#4A7A5C', soft: '#E5EFE8', muted: '#9DB5A5', muted2: '#C9D6CD' }
    : { bg: '#111518', ink: '#E7EBEE', accent: '#82AE90', soft: '#2C4636', muted: '#4D6B58', muted2: '#3A4A40' };
  const sats = [[379,172,48,'a'],[740,180,67,'s'],[254,354,105,'m'],[833,374,79,'m2'],[291,715,180,'a'],[853,669,48,'a'],[695,806,105,'m'],[339,403,41,'s'],[313,678,56,'s'],[579,790,41,'a']];
  const spokes = [[379,172],[740,180],[339,403],[833,374],[313,678],[853,669],[579,790]];
  const fill = { a: c.accent, s: c.soft, m: c.muted, m2: c.muted2 };
  return `<svg viewBox="0 0 1024 1024" role="img" aria-label="CrewPoint"><rect width="1024" height="1024" fill="${c.bg}"/>`
    + sats.slice(0, 7).map(([x, y, r, k]) => `<circle cx="${x}" cy="${y}" r="${r}" fill="${fill[k]}"/>`).join('')
    + spokes.map(([x, y]) => `<line x1="538" y1="495" x2="${x}" y2="${y}" stroke="${c.ink}" stroke-width="10"/>`).join('')
    + sats.slice(7).map(([x, y, r]) => `<circle cx="${x}" cy="${y}" r="${r}" fill="${c.ink}"/>`).join('')
    + `<circle cx="538" cy="495" r="97" fill="${c.ink}"/></svg>`;
}

function ring(doneFraction, size = 40, stroke = 5) {
  const r = size / 2 - stroke / 2 - 1;
  const c = 2 * Math.PI * r;
  const h = size / 2;
  return `<svg width="${size}" height="${size}" viewBox="0 0 ${size} ${size}" aria-hidden="true">
    <circle cx="${h}" cy="${h}" r="${r}" fill="none" stroke="var(--cp-border)" stroke-width="${stroke}"/>
    <circle cx="${h}" cy="${h}" r="${r}" fill="none" stroke="var(--cp-accent)" stroke-width="${stroke}" stroke-linecap="round"
      stroke-dasharray="${(c * doneFraction).toFixed(1)} ${c.toFixed(1)}" transform="rotate(-90 ${h} ${h})"/></svg>`;
}

const chip = (kind, label, icon) => `<span class="chip chip-${kind}">${icon ? i(icon, 15) : ''}${label}</span>`;
const statusChip = (kind, label) => chip(kind, label, kind);
const liveChip = `<span class="chip chip-neutral"><span class="dot"></span>Live</span>`;
const avatars = (list, cls = 'sm') => `<span class="stack-av">${list.map((a) => `<span class="avatar ${cls}">${a}</span>`).join('')}</span>`;

const sessionRow = (time, ampm, title, place, extra = '') => `
      <div class="row">
        <div class="time"><strong>${time}</strong><span>${ampm}</span></div>
        <div class="grow">
          <div class="row-title">${title}</div>
          <div class="row-sub">${i('place', 15)} ${place}</div>
          ${extra}
        </div>
        <span class="icon trail">${i('chevron', 20)}</span>
      </div>`;

const taskRow = (title, who, kind, label, extra = '') => `
      <div class="row">
        <span class="check${kind === 'done' ? ' on' : ''}">${kind === 'done' ? i('check', 14) : ''}</span>
        <div class="grow">
          <div class="row-title">${title}</div>
          <div class="row-sub">${who}</div>
        </div>
        ${extra}
        ${statusChip(kind, label)}
      </div>`;

const eventStats = `
    <div class="stats">
      <div class="card stat">
        <span class="k">${i('people', 15)} People</span>
        <span class="v">148</span>
        <span class="s">41 families</span>
      </div>
      <div class="card stat">
        <span class="k">${i('tasks', 15)} Tasks</span>
        <div class="hrow">${ring(18 / 26)}<span class="v" style="font-size:18px">18/26</span></div>
        <span class="s">2 overdue</span>
      </div>
      <div class="card stat">
        <span class="k">${i('budget', 15)} Budget</span>
        <span class="v">$4,320</span>
        <span class="s">of $6,000</span>
      </div>
    </div>`;

const upNext = `
      <div class="card list">
        ${sessionRow('9:00', 'AM', 'Registration opens', 'Main hall')}
        ${sessionRow('10:30', 'AM', 'Opening session', 'Ballroom A · Everyone')}
        ${sessionRow('12:30', 'PM', 'Lunch', 'Garden terrace')}
      </div>`;

const openTasks = `
      <div class="card list">
        ${taskRow('Confirm catering numbers', 'Priya · Logistics', 'overdue', 'Overdue')}
        ${taskRow('Print name badges', 'Ravi · Registration', 'due', 'Due Fri')}
        ${taskRow('Book sound crew', 'Asha · Programme', 'done', 'Done')}
      </div>`;

// ---------------------------------------------------------------- phone screens

function home() {
  const card = (thumb, title, when, sub, right) => `
      <div class="card row" style="padding:12px">
        <div class="thumb">${thumb}</div>
        <div class="grow">
          <div class="row-title">${title}</div>
          <div class="row-sub">${i('calendar', 14)} ${when}</div>
          <div class="row-sub">${sub}</div>
        </div>
        <div class="stack-sm" style="align-items:flex-end">${right}</div>
      </div>`;
  return `${statusBar}
  <div class="large-title" style="height:64px">
    <h1>Events</h1>
    <div class="hrow">${action('search')}${addAction}</div>
  </div>
  <main class="page" style="padding-top:8px">
    <section class="stack-sm">
      <div class="section-head"><h2>Happening now</h2></div>
      ${card(i('flag', 26), 'Riverside Charity Walk', 'Today · 8:00 AM – 1:00 PM', '62 people', liveChip)}
    </section>
    <section class="stack-sm">
      <div class="section-head"><h2>Upcoming</h2></div>
      ${card(photo('h1'), 'Lakeside Convention 2027', 'Fri 9 – Sun 11 July 2027', '148 people · Convention', `<span class="badge">3</span>`)}
      ${card(i('party', 26), 'Asha turns 40', 'Sat 24 July 2027', '35 people · Party', '')}
      ${card(i('trophy', 26), 'Summer Club Cup', 'Sat 7 – Sun 8 Aug 2027', '96 people', `<span class="badge">12</span>`)}
      ${card(i('heart', 26), 'Maya and Dev', 'Fri 3 – Sun 5 Dec 2027', '210 people', '')}
    </section>
    <section class="stack-sm">
      <div class="section-head"><h2>Drafts</h2></div>
      ${card(i('flag', 26), 'Autumn Outing', 'Sat 16 Oct 2027', 'Only you can see this', chip('quiet', 'Draft'))}
    </section>
  </main>
  ${nav('Events')}`;
}

function eventHome({ withPhoto }) {
  const banner = withPhoto
    ? `<div class="cover" role="img" aria-label="Event cover photo">${photo('eh')}</div>`
    : `<div class="cover" role="img" aria-label="Event cover (no photo)">
         <span class="big">${i('event', 56)}</span><span class="label">Convention</span></div>`;
  return `${statusBar}
  ${topBar({ actions: action('mute') + action('settings') })}
  <main class="page">
    ${banner}
    <div class="stack-sm">
      <div class="hrow">${chip('neutral', 'Published')}</div>
      <h1>Lakeside Convention 2027</h1>
      <div class="stack-sm muted" style="gap:6px;font-size:14px">
        <div class="hrow">${i('calendar', 17)} Fri 9 – Sun 11 July 2027</div>
        <div class="hrow">${i('place', 17)} Lakeside Centre, Madison</div>
      </div>
      <div class="hrow muted" style="font-size:14px;margin-top:4px">${avatars(['AS', 'RP', 'MK', 'JL'])} 148 attending · 12 crew</div>
    </div>
    ${eventStats}
    <section class="stack-sm">
      <div class="section-head"><h2>Up next</h2><a>Schedule ${i('chevron', 18)}</a></div>
      ${upNext}
    </section>
    <section class="stack-sm">
      <div class="section-head"><h2>Open tasks</h2><a>All tasks ${i('chevron', 18)}</a></div>
      ${openTasks}
    </section>
    <section class="stack-sm">
      <div class="section-head"><h2>Event</h2></div>
      <div class="tiles">
        ${[['chat', 'Chat', 'Updates and talk', '3'], ['budget', 'Budget', 'You are owed $120'], ['schedule', 'Schedule', '24 sessions'],
           ['agenda', 'Agenda', 'Your own plan'], ['people', 'People', '148 people'], ['counts', 'Counts', 'Updated 5 min ago']]
          .map(([k, t, s, b]) => `<div class="tile"><span class="tile-icon">${i(k, 22)}</span>
            <div class="grow"><div class="row-title">${t}</div><div class="row-sub">${s}</div></div>${b ? `<span class="badge">${b}</span>` : ''}</div>`).join('')}
      </div>
      <div class="btn-secondary full">${i('invite', 20)} Invite people</div>
    </section>
  </main>
  ${nav('Events')}`;
}

function people() {
  const person = (init, name, sub, right = '') => `
      <div class="row">
        <span class="avatar${init ? '' : ' blank'}">${init || i('profile', 18)}</span>
        <div class="grow"><div class="row-title">${name}</div><div class="row-sub">${sub}</div></div>
        ${right}
      </div>`;
  return `${statusBar}
  ${topBar({ title: 'People', actions: action('upload') + addAction })}
  <div class="menu" style="right:12px;top:100px">
    <div>${i('invite', 20)} Add person</div>
    <div>${i('people', 20)} Add family</div>
  </div>
  <main class="page" style="gap:16px">
    <div class="input">${i('search', 18)}<span class="ph">Search people</span></div>
    <div class="filters">
      <span class="filter on">All</span>
      <span class="filter">Family ${i('down', 16)}</span>
      <span class="filter">Children</span>
      <span class="filter">Diet ${i('down', 16)}</span>
    </div>
    <div class="card card-pad stack-md" style="padding:14px 16px">
      <div class="hrow"><span class="tile-icon">${i('people', 20)}</span>
        <div class="grow"><div class="overline">Your family</div><div class="row-title">Mehta · 3 people</div></div></div>
      <div class="hrow">
        <span class="btn-secondary btn-sm grow">${i('invite', 18)} Add people</span>
        <span class="btn-secondary btn-sm grow">${i('edit', 18)} Edit answers</span>
      </div>
    </div>
    <div class="card row" style="min-height:52px">
      <span class="icon" style="color:var(--cp-accent)">${i('link', 20)}</span>
      <div class="grow row-title" style="font-size:14px">2 link requests to review</div>
      <span class="icon trail">${i('chevron', 20)}</span>
    </div>
    <section class="stack-sm">
      <div class="section-head"><h2>148 people</h2><span class="count">41 families</span></div>
      <div class="card list">
        ${person('AK', 'Aarav Kapoor', 'Kapoor · Adult')}
        ${person('AS', 'Asha Singh', 'Singh · Adult')}
        ${person('DM', 'Diya Mehta', 'Mehta · Child · 6–12')}
        ${person('KM', 'Kabir Mehta', 'Mehta · Child · 6–12')}
        ${person('NM', 'Neha Mehta', 'Mehta · Adult')}
        ${person('PS', 'Priya Shah', 'Shah · Adult')}
        ${person('', 'Unnamed person', 'Shah · Adult')}
      </div>
      <div class="btn-text" style="align-self:center">Show more</div>
    </section>
  </main>
  ${nav('Events')}`;
}

const dietOpts = (on, error) => `<div class="opts${error ? ' error' : ''}">${['Veg', 'Jain', 'Non-veg']
  .map((o) => `<span class="opt${o === on ? ' on' : ''}">${o === on ? i('check', 16) : ''}${o}</span>`).join('')}</div>`;
const shirtOpts = (on) => `<div class="opts">${['2T', 'YS', 'YM', 'S', 'M', 'L', 'XL']
  .map((o) => `<span class="opt${o === on ? ' on' : ''}">${o}</span>`).join('')}</div>`;
const yesNo = (on) => `<div class="seg" style="width:180px"><span class="${on === 'Yes' ? 'on' : ''}">Yes</span><span class="${on === 'No' ? 'on' : ''}">No</span></div>`;
const adultChild = (on) => `<div class="seg"><span class="${on === 'Adult' ? 'on' : ''}">Adult</span><span class="${on === 'Child' ? 'on' : ''}">Child</span></div>`;

function newGroup() {
  const card = (n, body, copy) => `
      <div class="card card-pad stack-lg">
        <div class="section-head"><h3>Person ${n}</h3><span class="muted">${i('remove', 20)}</span></div>
        ${copy ? `<div class="btn-secondary btn-sm" style="align-self:flex-start">${i('copy', 16)} ${copy}</div>` : ''}
        ${body}
      </div>`;
  return `${statusBar}
  ${topBar({ lead: 'close', title: 'New family' })}
  <main class="page" style="padding-bottom:110px">
    <section class="card card-pad stack-lg">
      <div class="field"><label>Family name <span class="req">*</span></label><div class="input">Mehta</div></div>
      <div class="field"><span class="q-label">Arriving on</span>
        <div class="opts"><span class="opt">Thu 8</span><span class="opt on">${i('check', 16)}Fri 9</span><span class="opt">Sat 10</span></div>
        <span class="help">A question for the whole family.</span></div>
    </section>
    <div class="section-head"><h2>People</h2><span class="count">2 people</span></div>
    ${card(1, `
        <div class="field"><label>Name <span class="req">*</span></label><div class="input">Neha Mehta</div></div>
        ${adultChild('Adult')}
        <div class="field"><label>${i('lock', 14)} Email (private)</label><div class="input">neha.mehta@example.com</div>
          <span class="help">Links their account when they sign in with this email.</span></div>
        <div class="field"><span class="q-label">Diet <span class="req">*</span></span>${dietOpts('Veg')}</div>
        <div class="field"><span class="q-label">Kids activities</span>${yesNo('No')}</div>
        <div class="field"><span class="q-label">T-shirt size</span>${shirtOpts('M')}</div>`)}
    ${card(2, `
        <div class="field"><label>Name <span class="req">*</span></label><div class="input">Kabir Mehta</div></div>
        ${adultChild('Child')}
        <div class="field"><label>${i('lock', 14)} Birth date (private)</label><div class="input">${i('calendar', 18)} 14 March 2018</div>
          <span class="help">Sets the age band: 6–12.</span></div>
        <div class="field"><span class="q-label">Diet <span class="req">*</span></span>${dietOpts(null, true)}
          <span class="err">${i('overdue', 14)} Choose an answer.</span></div>
        <div class="field"><span class="q-label">Kids activities</span>${yesNo('Yes')}</div>
        <div class="field"><span class="q-label">T-shirt size</span>${shirtOpts('YS')}</div>`, 'Same answers as Neha')}
    <div class="btn-dashed">${i('add', 20)} Add another person</div>
  </main>
  <div class="save-bar">
    <span class="note">${i('overdue', 16)} 1 answer missing</span>
    <span class="btn-primary">Save family</span>
  </div>`;
}

function personForm() {
  const multi = ['Workshops', 'Sports', 'Music', 'Volunteering'];
  const picked = ['Workshops', 'Sports'];
  return `${statusBar}
  ${topBar({ title: 'Kabir Mehta', actions: action('more') })}
  <main class="page" style="padding-bottom:110px;gap:20px">
    <div class="banner-msg error">${i('overdue', 18)}<span>Couldn't save. Your changes are still here, so try again.</span></div>
    <section class="card card-pad stack-lg">
      <div class="field"><label>Name <span class="req">*</span></label><div class="input focus">Kabir Mehta</div></div>
      <div class="switch-row"><div class="grow"><div class="row-title">Child</div>
        <div class="help">Children have no account. Only a parent or guardian linked to their family, or an organizer, can add or change them.</div></div>
        <span class="switch on"></span></div>
      <div class="field"><label>Family</label><div class="input"><span class="grow">Mehta</span>${i('down', 18)}</div></div>
    </section>
    <section class="stack-sm">
      <div class="section-head"><h2>Questions</h2></div>
      <div class="card card-pad stack-lg">
        <div class="field"><span class="q-label">Diet <span class="req">*</span></span>${dietOpts(null, true)}
          <span class="err">${i('overdue', 14)} Choose an answer.</span></div>
        <div class="field"><span class="q-label">Kids activities</span>${yesNo('Yes')}</div>
        <div class="field"><span class="q-label">T-shirt size</span>${shirtOpts('YS')}</div>
        <div class="field"><span class="q-label">Interested in</span>
          <div class="opts">${multi.map((o) => `<span class="opt${picked.includes(o) ? ' on' : ''}">${picked.includes(o) ? i('check', 16) : ''}${o}</span>`).join('')}</div>
          <span class="help">Choose any.</span></div>
        <div class="field"><label>Years attending</label><div class="input tnum" style="width:120px">3</div></div>
        <div class="field"><label>Anything we should know?</label><div class="input"><span class="ph">Optional</span></div></div>
      </div>
    </section>
    <section class="private stack-lg">
      <div class="hrow"><span class="icon" style="color:var(--cp-accent)">${i('lock', 18)}</span><h3>Private</h3></div>
      <div class="help" style="margin-top:-8px">Seen only by organizers who can read private details, and by the adults linked to this person's family.</div>
      <div class="field"><label>Birth date</label><div class="input">${i('calendar', 18)} <span class="grow">14 March 2018</span>${i('close', 18)}</div>
        <span class="help">Reports show age bands: 6–12.</span></div>
      <div class="field"><label>Allergies</label><div class="input error">Peanuts, tree nuts, sesame, shellfish, eg…</div>
        <span class="err">${i('overdue', 14)} Use 40 characters or fewer.</span></div>
    </section>
  </main>
  <div class="save-bar">
    <span class="note">${i('overdue', 16)} 2 answers need attention</span>
    <span class="btn-primary">Save</span>
  </div>`;
}

function schedule() {
  const day = (wd, d, on) => `<span class="filter${on ? ' on' : ''}" style="height:52px;flex-direction:column;justify-content:center;gap:0;padding:0 16px">
      <span style="font-size:11px;font-weight:650;text-transform:uppercase">${wd}</span><span class="tnum" style="font-size:16px;font-weight:650">${d}</span></span>`;
  const tags = (...t) => `<div class="hrow wrap" style="margin-top:6px;gap:6px">${t.join('')}</div>`;
  return `${statusBar}
  ${topBar({ title: 'Schedule', actions: addAction })}
  <main class="page" style="gap:16px">
    <div class="seg"><span class="on">By day</span><span>By venue</span></div>
    <div class="filters">${day('Fri', '9')}${day('Sat', '10', true)}${day('Sun', '11')}</div>
    <div class="card list">
      <div class="row" style="opacity:.6">
        <div class="time"><strong>8:00</strong><span>AM</span></div>
        <div class="grow"><div class="row-title">Breakfast</div><div class="row-sub">${i('place', 15)} Garden terrace</div></div>
        <span class="icon trail">${i('chevron', 20)}</span></div>
      ${sessionRow('9:30', 'AM', 'Keynote: Growing together', 'Ballroom A', tags(liveChip.replace('Live', 'Now'), chip('quiet', 'Everyone')))}
      ${sessionRow('11:00', 'AM', 'Craft workshop', 'Room 2', tags(chip('quiet', 'Children 6–12'), chip('quiet', '18 of 24 places')))}
      ${sessionRow('12:30', 'PM', 'Lunch', 'Garden terrace')}
      ${sessionRow('2:00', 'PM', 'Panel: Giving back', 'Ballroom A', tags(chip('quiet', 'Adults')))}
      ${sessionRow('4:00', 'PM', 'Sports afternoon', 'Lakeside field', tags(chip('quiet', 'Time to be confirmed')))}
      ${sessionRow('7:00', 'PM', 'Cultural evening', 'Place to be announced', tags(chip('quiet', `${i('lock', 13)} Hidden draft`)))}
    </div>
  </main>
  ${nav('Events')}`;
}

function tasks() {
  return `${statusBar}
  ${topBar({ title: 'Tasks', actions: action('search') + addAction })}
  <main class="page" style="gap:18px">
    <div class="card card-pad hrow" style="gap:14px">
      ${ring(18 / 26, 52, 6)}
      <div class="grow"><div class="row-title tnum">18 of 26 done</div><div class="row-sub">2 overdue · 4 due this week</div></div>
    </div>
    <div class="filters">
      <span class="filter on">All</span><span class="filter">Mine</span><span class="filter">Overdue</span>
      <span class="filter">Crew ${i('down', 16)}</span><span class="filter">Has budget</span>
    </div>
    <section class="stack-sm">
      <div class="section-head"><h2>Overdue</h2><span class="count">2</span></div>
      <div class="card list">
        ${taskRow('Confirm catering numbers', 'Priya · Logistics', 'overdue', 'Overdue Tue')}
        ${taskRow('Send room list to hotel', 'Aarav · Logistics', 'overdue', 'Overdue Wed')}
      </div>
    </section>
    <section class="stack-sm">
      <div class="section-head"><h2>This week</h2><span class="count">4</span></div>
      <div class="card list">
        ${taskRow('Print name badges', 'Ravi · Registration', 'due', 'Due Fri', `<span class="amount muted" style="font-size:13px">$180</span>`)}
        ${taskRow('Order T-shirts', 'Neha · Merchandise', 'due', 'Due Sat', `<span class="amount muted" style="font-size:13px">$620</span>`)}
        ${taskRow('Book shuttle buses', 'Unassigned · Transport', 'due', 'Due Sun')}
        ${taskRow('Brief volunteers', 'Asha · Programme', 'due', 'Due Sun')}
      </div>
    </section>
    <section class="stack-sm">
      <div class="section-head"><h2>Done</h2><a>Show 18 ${i('down', 18)}</a></div>
      <div class="card list">
        ${taskRow('Book sound crew', 'Asha · Programme', 'done', 'Done')}
      </div>
    </section>
  </main>
  ${nav('Events')}`;
}

function budget() {
  const bal = (init, name, note, amount) => `
      <div class="row"><span class="avatar sm">${init}</span>
        <div class="grow"><div class="row-title">${name}</div><div class="row-sub">${note}</div></div>
        <span class="amount">${amount}</span></div>`;
  const exp = (title, sub, amount, when, extra = '') => `
      <div class="row"><span class="tile-icon">${i('receipt', 20)}</span>
        <div class="grow"><div class="row-title">${title}</div><div class="row-sub">${sub}</div></div>
        <div class="stack-sm" style="align-items:flex-end;gap:4px"><span class="amount">${amount}<small>${when}</small></span>${extra}</div></div>`;
  return `${statusBar}
  ${topBar({ title: 'Budget', actions: action('upload') + addAction })}
  <main class="page" style="gap:20px">
    <div class="card card-pad stack-md">
      <div class="hrow"><div class="grow"><div class="overline">Spent</div>
        <div class="tnum" style="font-size:28px;font-weight:650;font-variation-settings:'opsz' 32">$4,320 <span class="muted" style="font-size:15px;font-weight:500">of $6,000</span></div></div></div>
      <div class="bar"><i style="width:72%"></i></div>
      <div class="hrow muted" style="font-size:13px;justify-content:space-between"><span>72% of budget</span><span class="tnum">$1,680 left</span></div>
    </div>
    <div class="card card-pad stack-md">
      <div class="overline">Your balance</div>
      <div class="tnum" style="font-size:24px;font-weight:650;font-variation-settings:'opsz' 32">You are owed $120</div>
      <div class="row-sub" style="margin:0">Ravi owes you $80 · Asha owes you $40</div>
      <span class="btn-primary full">${i('settle', 18)} Settle up</span>
    </div>
    <section class="stack-sm">
      <div class="section-head"><h2>Balances</h2><a>All 12 ${i('chevron', 18)}</a></div>
      <div class="card list">
        ${bal('PS', 'Priya Shah', 'is owed', '$310')}
        ${bal('RP', 'Ravi Patel', 'owes', '$80')}
        ${bal('AS', 'Asha Singh', 'owes', '$40')}
      </div>
    </section>
    <section class="stack-sm">
      <div class="section-head"><h2>Expenses</h2><span class="count">14</span></div>
      <div class="card list">
        ${exp('Venue deposit', 'Paid by Priya · split 6 ways', '$2,000', '3 Jul')}
        ${exp('Catering advance', 'Paid by you · split 6 ways', '$1,500', '1 Jul')}
        ${exp('T-shirts', 'Paid by Neha · Merchandise', '$620', '28 Jun')}
        <div class="row"><span class="tile-icon">${i('settle', 20)}</span>
          <div class="grow"><div class="row-title">Ravi paid Priya</div><div class="row-sub">Settlement</div></div>
          <div class="stack-sm" style="align-items:flex-end;gap:4px"><span class="amount">$50</span>${statusChip('done', 'Paid')}</div></div>
      </div>
    </section>
  </main>
  ${nav('Events')}`;
}

function createEvent() {
  const tpl = (icon, name, desc, quick) => `
      <div class="card row" style="padding:14px 16px;align-items:flex-start">
        <span class="tile-icon">${i(icon, 22)}</span>
        <div class="grow"><div class="row-title">${name}</div><div class="row-sub" style="display:block">${desc}</div>
          ${quick ? `<div style="margin-top:8px">${chip('neutral', 'Just a title and a date')}</div>` : ''}</div>
        <span class="icon trail" style="align-self:center">${i('chevron', 20)}</span>
      </div>`;
  return `${statusBar}
  ${topBar({ lead: 'close', title: 'Create an event' })}
  <main class="page" style="gap:20px">
    <p class="muted" style="margin-top:-4px">Start from a template. You can change anything afterwards.</p>
    <section class="stack-sm">
      <div class="section-head"><h2>Your templates</h2></div>
      ${tpl('event', 'Lakeside Convention setup', 'Based on Convention · saved 2 October')}
    </section>
    <section class="stack-sm">
      <div class="section-head"><h2>Templates</h2></div>
      ${tpl('add', 'Blank', 'Start from nothing and set it up your way.', true)}
      ${tpl('party', 'Party', 'A birthday, a dinner or any get-together, ready in a minute.', true)}
      ${tpl('heart', 'Wedding', 'Several days of events, guests invited by party, and meal choices.')}
      ${tpl('trophy', 'Cricket tournament', 'Teams, matches and players, with costs shared by those involved.')}
      ${tpl('flag', 'Golf outing', 'Foursomes and rounds, with carts and handicaps.')}
      ${tpl('event', 'Convention', 'Hundreds of people over several days, with meals, families and a committee.')}
    </section>
  </main>`;
}

// ---------------------------------------------------------------- laptop screens

function sidebar(mode, active) {
  const app = [['calendar', 'Events'], ['tasks', 'Tasks'], ['chat', 'Chat'], ['budget', 'Budget'], ['profile', 'Profile']];
  const ev = [['dashboard', 'Overview'], ['people', 'People'], ['schedule', 'Schedule'], ['tasks', 'Tasks'],
    ['budget', 'Budget'], ['chat', 'Chat', '3'], ['counts', 'Counts'], ['settings', 'Settings']];
  return `<aside class="side">
    <div class="brand">${logo(mode)} CrewPoint</div>
    ${app.map(([k, l]) => `<div class="item">${i(k, 20)} ${l}</div>`).join('')}
    <div class="group overline">This event</div>
    <div class="event"><div class="thumb">${photo('sb')}</div><div><b>Lakeside Convention</b><span>Fri 9 – Sun 11 July</span></div></div>
    ${ev.map(([k, l, b]) => `<div class="item${l === active ? ' on' : ''}">${i(k, 20)} ${l}${b ? `<span class="badge">${b}</span>` : ''}</div>`).join('')}
    <div class="me"><span class="avatar sm">NM</span> Neha Mehta</div>
  </aside>`;
}

function laptopEventHome(mode) {
  return `<div class="app">
  ${sidebar(mode, 'Overview')}
  <main class="main"><div class="main-inner">
    <div class="cover" style="height:180px">${photo('lh')}</div>
    <div class="hrow" style="align-items:flex-end;gap:24px">
      <div class="grow stack-sm">
        <div class="hrow">${chip('neutral', 'Published')}</div>
        <h1 style="font-size:30px">Lakeside Convention 2027</h1>
        <div class="hrow muted" style="font-size:14px;gap:20px">
          <span class="hrow">${i('calendar', 17)} Fri 9 – Sun 11 July 2027</span>
          <span class="hrow">${i('place', 17)} Lakeside Centre, Madison</span>
          <span class="hrow">${avatars(['AS', 'RP', 'MK', 'JL'])} 148 attending · 12 crew</span>
        </div>
      </div>
      <span class="btn-secondary">${i('invite', 20)} Invite people</span>
      <span class="btn-secondary" style="width:48px;padding:0">${i('settings', 20)}</span>
    </div>
    <div class="cols-3">
      <div class="card stat" style="padding:18px">
        <span class="k">${i('people', 15)} People</span><span class="v" style="font-size:28px">148</span>
        <span class="s">41 families · 52 children</span></div>
      <div class="card stat" style="padding:18px">
        <span class="k">${i('tasks', 15)} Tasks</span>
        <div class="hrow">${ring(18 / 26, 44)}<span class="v" style="font-size:24px">18/26</span></div>
        <span class="s">2 overdue · 4 due this week</span></div>
      <div class="card stat" style="padding:18px">
        <span class="k">${i('budget', 15)} Budget</span><span class="v" style="font-size:28px">$4,320</span>
        <div class="bar"><i style="width:72%"></i></div><span class="s">of $6,000 · you are owed $120</span></div>
    </div>
    <div class="cols-2">
      <section class="stack-sm">
        <div class="section-head"><h2>Up next</h2><a>Schedule ${i('chevron', 18)}</a></div>
        ${upNext}
      </section>
      <section class="stack-sm">
        <div class="section-head"><h2>Open tasks</h2><a>All tasks ${i('chevron', 18)}</a></div>
        ${openTasks}
      </section>
    </div>
  </div></main>
  </div>`;
}

function laptopPeople(mode) {
  const person = (init, name, sub, sel) => `
      <div class="row${sel ? ' sel' : ''}"><span class="avatar">${init}</span>
        <div class="grow"><div class="row-title">${name}</div><div class="row-sub">${sub}</div></div></div>`;
  return `<div class="app">
  ${sidebar(mode, 'People')}
  <div class="split">
    <section class="pane">
      <div style="padding:24px 20px 12px" class="stack-md">
        <div class="section-head"><h1 style="font-size:24px">People</h1>
          <span class="btn-primary btn-sm">${i('add', 18)} Add ${i('down', 16)}</span></div>
        <div class="input">${i('search', 18)}<span class="ph">Search people</span></div>
        <div class="filters"><span class="filter on">All</span><span class="filter">Family ${i('down', 16)}</span>
          <span class="filter">Children</span><span class="filter">Diet ${i('down', 16)}</span></div>
        <div class="muted" style="font-size:13px">148 people · 41 families</div>
      </div>
      <div class="list" style="border-top:1px solid var(--cp-border)">
        ${person('AK', 'Aarav Kapoor', 'Kapoor · Adult')}
        ${person('AS', 'Asha Singh', 'Singh · Adult')}
        ${person('DM', 'Diya Mehta', 'Mehta · Child · 6–12')}
        ${person('KM', 'Kabir Mehta', 'Mehta · Child · 6–12', true)}
        ${person('NM', 'Neha Mehta', 'Mehta · Adult')}
        ${person('PS', 'Priya Shah', 'Shah · Adult')}
        ${person('RP', 'Ravi Patel', 'Patel · Adult')}
        ${person('RS', 'Rohan Shah', 'Shah · Child · 13–17')}
      </div>
    </section>
    <section style="padding:28px 36px;overflow:hidden" class="stack-lg">
      <div class="hrow" style="gap:16px">
        <span class="avatar lg">KM</span>
        <div class="grow"><h1 style="font-size:24px">Kabir Mehta</h1><div class="row-sub" style="font-size:14px">Mehta · Child · 6–12</div></div>
        <span class="btn-secondary btn-sm">${i('edit', 16)} Edit</span>
        <span class="btn-secondary btn-sm" style="width:36px;padding:0">${i('more', 18)}</span>
      </div>
      <div class="cols-2">
        <div class="card card-pad stack-md">
          <div class="section-head"><h3>Family</h3><a>Open ${i('chevron', 16)}</a></div>
          <div class="hrow">${avatars(['NM', 'DM', 'KM'])}<span class="muted" style="font-size:14px">Mehta · 3 people · linked to Neha</span></div>
        </div>
        <div class="card card-pad stack-md">
          <h3>Attending</h3>
          <div class="muted" style="font-size:14px">Fri 9 – Sun 11 July · all sessions they can join</div>
        </div>
      </div>
      <div class="card card-pad stack-md">
        <h3>Answers</h3>
        <dl class="kv"><dt>Diet</dt><dd>Veg</dd><dt>Kids activities</dt><dd>Yes</dd><dt>T-shirt size</dt><dd>YS</dd>
          <dt>Interested in</dt><dd>Workshops, Sports</dd><dt>Years attending</dt><dd>3</dd></dl>
      </div>
      <div class="private stack-md">
        <div class="hrow"><span class="icon" style="color:var(--cp-accent)">${i('lock', 18)}</span><h3>Private</h3></div>
        <dl class="kv"><dt>Birth date</dt><dd>14 March 2018</dd><dt>Allergies</dt><dd>Peanuts</dd></dl>
      </div>
    </section>
  </div>
  </div>`;
}

// ---------------------------------------------------------------- build

const screens = [
  { id: 'home', title: 'Home (event list)', height: 1060, body: home },
  { id: 'event-home', title: 'Event home', height: 1600, body: () => eventHome({ withPhoto: true }) },
  { id: 'event-home-no-photo', title: 'Event home, no photo', height: 1600, body: () => eventHome({ withPhoto: false }) },
  { id: 'people', title: 'People', height: 1080, body: people },
  { id: 'new-group', title: 'New group', height: 1930, body: newGroup },
  { id: 'person-form', title: 'Person form', height: 1720, body: personForm },
  { id: 'schedule', title: 'Schedule (day)', height: 1000, body: schedule },
  { id: 'tasks', title: 'Tasks', height: 1080, body: tasks },
  { id: 'budget', title: 'Budget', height: 1180, body: budget },
  { id: 'create-event', title: 'Create event', height: 1120, body: createEvent },
  { id: 'laptop-event-home', title: 'Event home, laptop', width: 1280, height: 860, body: laptopEventHome },
  { id: 'laptop-people', title: 'People, laptop', width: 1280, height: 860, body: laptopPeople },
];

const png = process.argv.includes('--png');
const only = process.argv.find((a) => a.startsWith('--only='))?.slice(7);
mkdirSync(outDir, { recursive: true });

for (const s of screens) {
  if (only && s.id !== only) continue;
  for (const mode of ['light', 'dark']) {
    const width = s.width ?? phone;
    const base = `${s.id}-${mode}`;
    const html = join(outDir, `${base}.html`);
    writeFileSync(html, doc({ title: s.title, mode, width, height: s.height, body: s.body(mode) }));
    if (png) exportPng(html, join(outDir, `${base}.png`), width, s.height);
    console.log(base);
  }
}
