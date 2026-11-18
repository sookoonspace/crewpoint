// Builds the Round 1 Event home mockups (Spec #186, Work Item #189).
//
//   node docs/design/mockups/_src/build.mjs          # HTML only
//   node docs/design/mockups/_src/build.mjs --png    # HTML and PNG (headless Chrome)
//
// Every screen is written as a self-contained HTML file whose tokens sit in a
// named `:root` block, so the chosen direction can become the app's token file.
// Lucide icons are inlined from `_src/lucide/` (lucide-static 0.469.0, ISC).
// Material Symbols Outlined loads from Google Fonts.

import { execFileSync } from 'node:child_process';
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const outDir = join(here, '..', 'round-1');
const width = 390;
const height = 1580;

// ---------------------------------------------------------------- tokens

const status = {
  light: {
    'status-done': '#2E7D4F', 'status-done-soft': '#E6F2EA',
    'status-due': '#9A6200', 'status-due-soft': '#FBF0DC',
    'status-overdue': '#B3261E', 'status-overdue-soft': '#FBE6E4',
  },
  dark: {
    'status-done': '#73C796', 'status-done-soft': '#1B2E23',
    'status-due': '#E7B04A', 'status-due-soft': '#33280F',
    'status-overdue': '#F2877F', 'status-overdue-soft': '#3A1B19',
  },
};

export const directions = {
  'slate-sage': {
    name: 'Slate and sage',
    light: {
      background: '#F6F7F8', surface: '#FFFFFF', border: '#E2E6EA',
      text: '#1E2A33', 'text-muted': '#5A6672',
      accent: '#4A7A5C', 'accent-soft': '#E5EFE8', 'on-accent': '#FFFFFF',
      banner: '#4A7A5C', 'on-banner': '#FFFFFF',
    },
    dark: {
      background: '#111518', surface: '#1A2026', border: '#29323A',
      text: '#E7EBEE', 'text-muted': '#9AA5AF',
      accent: '#82AE90', 'accent-soft': '#1F2F25', 'on-accent': '#0D1A12',
      banner: '#2C4636', 'on-banner': '#DCEADF',
    },
  },
  'ink-indigo': {
    name: 'Ink and indigo',
    light: {
      background: '#F8F8FA', surface: '#FFFFFF', border: '#E5E6EC',
      text: '#111318', 'text-muted': '#5C606E',
      accent: '#4A51A6', 'accent-soft': '#ECEDF8', 'on-accent': '#FFFFFF',
      banner: '#4A51A6', 'on-banner': '#FFFFFF',
    },
    dark: {
      background: '#0E0F14', surface: '#17191F', border: '#262933',
      text: '#ECEDF2', 'text-muted': '#9A9EAD',
      accent: '#9097E3', 'accent-soft': '#202342', 'on-accent': '#0E0F14',
      banner: '#2B2F66', 'on-banner': '#E1E3FA',
    },
  },
  'warm-neutral': {
    name: 'Warm neutral',
    light: {
      background: '#F8F7F5', surface: '#FFFFFF', border: '#E7E3DE',
      text: '#2A2927', 'text-muted': '#6A6661',
      accent: '#A85F45', 'accent-soft': '#F4E8E2', 'on-accent': '#FFFFFF',
      banner: '#A85F45', 'on-banner': '#FFFFFF',
    },
    dark: {
      background: '#151413', surface: '#1F1D1B', border: '#312E2B',
      text: '#EEEAE5', 'text-muted': '#A8A29B',
      accent: '#D99276', 'accent-soft': '#3A2922', 'on-accent': '#1A0F0A',
      banner: '#5E3426', 'on-banner': '#F5E2DA',
    },
  },
};

const shared = {
  'font-text': "'Inter', system-ui, sans-serif",
  'font-heading-opsz': '32', // Inter Display: Inter at optical size 32
  'type-title': '26px', 'type-section': '17px', 'type-body': '15px',
  'type-label': '13px', 'type-caption': '12px', 'type-stat': '22px',
  'space-xs': '4px', 'space-sm': '8px', 'space-md': '12px',
  'space-lg': '16px', 'space-xl': '24px', 'space-2xl': '32px',
  'radius-sm': '8px', 'radius-md': '12px', 'radius-lg': '16px', 'radius-pill': '999px',
  'shadow-card': '0 1px 2px rgba(16, 24, 40, 0.04)',
  'icon-size': '20px', 'tap-min': '48px',
};

// ---------------------------------------------------------------- icons

const iconNames = {
  back: ['arrow_back', 'arrow-left'],
  mute: ['notifications_off', 'bell-off'],
  settings: ['settings', 'settings'],
  calendar: ['calendar_today', 'calendar'],
  place: ['location_on', 'map-pin'],
  people: ['group', 'users'],
  tasks: ['checklist', 'list-checks'],
  budget: ['account_balance_wallet', 'wallet'],
  chat: ['chat_bubble', 'message-circle'],
  schedule: ['schedule', 'clock'],
  agenda: ['calendar_month', 'calendar-days'],
  counts: ['bar_chart', 'chart-column'],
  chevron: ['chevron_right', 'chevron-right'],
  done: ['check_circle', 'circle-check'],
  due: ['schedule', 'clock'],
  overdue: ['error', 'circle-alert'],
  add: ['add', 'plus'],
  profile: ['person', 'user'],
  invite: ['person_add', 'user-plus'],
  event: ['groups', 'users-round'],
};

function lucideSvg(name, size) {
  const raw = readFileSync(join(here, 'lucide', `${name}.svg`), 'utf8')
    .replace(/<!--.*?-->/s, '')
    .trim();
  return raw
    .replace(/width="24"/, `width="${size}"`)
    .replace(/height="24"/, `height="${size}"`)
    .replace(/stroke-width="2"/, 'stroke-width="1.75"')
    .replace(/\s*\n\s*/g, ' ');
}

function iconFn(set) {
  return (key, size = 20) => {
    const [material, lucide] = iconNames[key];
    if (set === 'material') {
      return `<span class="icon ms" style="font-size:${size}px" aria-hidden="true">${material}</span>`;
    }
    return `<span class="icon" aria-hidden="true">${lucideSvg(lucide, size)}</span>`;
  };
}

// ---------------------------------------------------------------- screen

function tokensCss(direction, mode) {
  const all = { ...directions[direction][mode], ...status[mode], ...shared };
  return Object.entries(all).map(([k, v]) => `  --cp-${k}: ${v};`).join('\n');
}

function screen({ direction, set, mode }) {
  const i = iconFn(set);
  const d = directions[direction];
  const setLabel = set === 'material' ? 'Material Symbols Outlined' : 'Lucide';
  const fonts = [
    'https://fonts.googleapis.com/css2?family=Inter:opsz,wght@14..32,400..700&display=block',
    set === 'material'
      ? 'https://fonts.googleapis.com/css2?family=Material+Symbols+Outlined:opsz,wght,FILL,GRAD@20..48,400,0,0&display=block'
      : null,
  ].filter(Boolean);

  const avatars = ['AS', 'RP', 'MK', 'JL']
    .map((a, n) => `<span class="avatar" style="z-index:${10 - n}">${a}</span>`)
    .join('');

  const session = (time, ampm, title, place, tag) => `
      <div class="row">
        <div class="time"><strong>${time}</strong><span>${ampm}</span></div>
        <div class="grow">
          <div class="row-title">${title}</div>
          <div class="row-sub">${i('place', 15)} ${place}${tag ? ` · ${tag}` : ''}</div>
        </div>
        ${i('chevron', 20)}
      </div>`;

  const task = (title, who, kind, label) => `
      <div class="row">
        <div class="grow">
          <div class="row-title">${title}</div>
          <div class="row-sub">${who}</div>
        </div>
        <span class="chip chip-${kind}">${i(kind, 15)} ${label}</span>
      </div>`;

  const link = (key, title, sub, badge) => `
      <div class="tile">
        <span class="tile-icon">${i(key, 22)}</span>
        <div class="grow">
          <div class="row-title">${title}</div>
          <div class="row-sub">${sub}</div>
        </div>
        ${badge ? `<span class="badge">${badge}</span>` : ''}
      </div>`;

  // Progress ring: 18 of 26 tasks done.
  const r = 17, c = 2 * Math.PI * r, done = 18 / 26;

  return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=${width}">
<title>Event home · ${d.name} · ${setLabel} · ${mode}</title>
${fonts.map((f) => `<link rel="stylesheet" href="${f}">`).join('\n')}
<style>
/* Tokens: ${d.name}, ${mode}. These names become the app's design tokens. */
:root {
${tokensCss(direction, mode)}
}
* { box-sizing: border-box; margin: 0; padding: 0; }
html, body { width: ${width}px; height: ${height}px; overflow: hidden; }
body { position: relative; }
body {
  background: var(--cp-background); color: var(--cp-text);
  font-family: var(--cp-font-text); font-size: var(--cp-type-body); line-height: 1.4;
  -webkit-font-smoothing: antialiased; padding-bottom: 96px;
}
h1, h2 { font-variation-settings: 'opsz' var(--cp-font-heading-opsz); letter-spacing: -0.01em; }
h1 { font-size: var(--cp-type-title); font-weight: 650; line-height: 1.2; }
h2 { font-size: var(--cp-type-section); font-weight: 620; }
.icon { display: inline-flex; align-items: center; justify-content: center; line-height: 1; flex: none; }
.icon svg { display: block; }
.ms { font-family: 'Material Symbols Outlined'; font-weight: 400; font-style: normal;
  font-variation-settings: 'FILL' 0, 'wght' 400, 'GRAD' 0, 'opsz' 24; }
.status-bar { height: 44px; display: flex; align-items: center; justify-content: space-between;
  padding: 0 24px; font-size: 15px; font-weight: 600; }
.status-bar .dots { display: flex; gap: 5px; }
.status-bar .dots i { width: 17px; height: 10px; border-radius: 3px; background: var(--cp-text); opacity: .85; display: block; }
.top-bar { height: 52px; display: flex; align-items: center; padding: 0 4px; color: var(--cp-text); }
.top-bar .btn { width: var(--cp-tap-min); height: var(--cp-tap-min); display: flex; align-items: center; justify-content: center; }
.top-bar .grow { flex: 1; }
.page { padding: 0 var(--cp-space-lg); display: flex; flex-direction: column; gap: var(--cp-space-xl); }
.banner { height: 132px; border-radius: var(--cp-radius-lg); background: var(--cp-banner);
  color: var(--cp-on-banner); display: flex; align-items: flex-end; justify-content: space-between;
  padding: var(--cp-space-lg); position: relative; overflow: hidden; }
.banner .big { position: absolute; right: 18px; top: 18px; opacity: .9; }
.banner .label { font-size: var(--cp-type-label); font-weight: 600; opacity: .9; }
.head { display: flex; flex-direction: column; gap: var(--cp-space-sm); }
.meta { display: flex; flex-direction: column; gap: 6px; color: var(--cp-text-muted); font-size: 14px; }
.meta div { display: flex; align-items: center; gap: 8px; }
.chip { display: inline-flex; align-items: center; gap: 4px; height: 28px; padding: 0 10px;
  border-radius: var(--cp-radius-pill); font-size: var(--cp-type-label); font-weight: 600; white-space: nowrap; }
.chip-neutral { background: var(--cp-accent-soft); color: var(--cp-accent); }
.chip-done { background: var(--cp-status-done-soft); color: var(--cp-status-done); }
.chip-due { background: var(--cp-status-due-soft); color: var(--cp-status-due); }
.chip-overdue { background: var(--cp-status-overdue-soft); color: var(--cp-status-overdue); }
.title-row { display: flex; align-items: center; gap: var(--cp-space-sm); }
.people { display: flex; align-items: center; gap: 10px; margin-top: 4px; font-size: 14px; color: var(--cp-text-muted); }
.stack { display: flex; }
.avatar { width: 32px; height: 32px; border-radius: 50%; background: var(--cp-accent-soft); color: var(--cp-accent);
  border: 2px solid var(--cp-background); font-size: 11px; font-weight: 700; display: flex;
  align-items: center; justify-content: center; margin-left: -6px; position: relative; }
.avatar:first-child { margin-left: 0; }
.stats { display: grid; grid-template-columns: repeat(3, 1fr); gap: var(--cp-space-sm); }
.card { background: var(--cp-surface); border: 1px solid var(--cp-border); border-radius: var(--cp-radius-md);
  box-shadow: var(--cp-shadow-card); }
.stat { padding: var(--cp-space-md); display: flex; flex-direction: column; gap: 6px; min-height: 104px; }
.stat .k { font-size: var(--cp-type-caption); font-weight: 600; color: var(--cp-text-muted); display: flex; align-items: center; gap: 6px; }
.stat .v { font-size: var(--cp-type-stat); font-weight: 650; font-variation-settings: 'opsz' 32; font-feature-settings: 'tnum'; }
.stat .s { font-size: var(--cp-type-caption); color: var(--cp-text-muted); }
.ring-wrap { display: flex; align-items: center; gap: 8px; }
.section { display: flex; flex-direction: column; gap: var(--cp-space-sm); }
.section-head { display: flex; align-items: center; justify-content: space-between; min-height: 32px; }
.section-head a { color: var(--cp-accent); font-size: 14px; font-weight: 600; text-decoration: none; display: flex; align-items: center; }
.list .row + .row { border-top: 1px solid var(--cp-border); }
.row { display: flex; align-items: center; gap: var(--cp-space-md); padding: 12px var(--cp-space-lg); min-height: 64px; color: var(--cp-text); }
.row > .icon:last-child { color: var(--cp-text-muted); }
.grow { flex: 1; min-width: 0; }
.row-title { font-weight: 560; }
.row-sub { font-size: 13px; color: var(--cp-text-muted); display: flex; align-items: center; gap: 4px; margin-top: 2px; }
.time { width: 44px; display: flex; flex-direction: column; align-items: flex-start; font-feature-settings: 'tnum'; }
.time strong { font-size: 15px; font-weight: 650; }
.time span { font-size: 11px; color: var(--cp-text-muted); font-weight: 600; }
.tiles { display: grid; grid-template-columns: 1fr 1fr; gap: var(--cp-space-sm); }
.tile { display: flex; align-items: center; gap: 10px; padding: 14px 12px; min-height: 64px;
  background: var(--cp-surface); border: 1px solid var(--cp-border); border-radius: var(--cp-radius-md); position: relative; }
.tile .row-sub { font-size: 12px; }
.tile-icon { width: 36px; height: 36px; border-radius: var(--cp-radius-sm); background: var(--cp-accent-soft);
  color: var(--cp-accent); display: flex; align-items: center; justify-content: center; flex: none; }
.badge { min-width: 22px; height: 22px; padding: 0 6px; border-radius: 11px; background: var(--cp-accent);
  color: var(--cp-on-accent); font-size: 12px; font-weight: 700; display: flex; align-items: center; justify-content: center; }
.button-secondary { height: 48px; border-radius: var(--cp-radius-md); border: 1px solid var(--cp-border);
  background: var(--cp-surface); color: var(--cp-accent); font-weight: 600; display: flex;
  align-items: center; justify-content: center; gap: 8px; }
.nav { position: absolute; left: 0; width: ${width}px; top: ${height - 84}px; height: 84px; padding-bottom: 20px;
  background: var(--cp-surface); border-top: 1px solid var(--cp-border); display: grid; grid-template-columns: repeat(5, 1fr); }
.nav div { display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 3px;
  font-size: 11px; font-weight: 600; color: var(--cp-text-muted); }
.nav .on { color: var(--cp-accent); }
.nav .on .pill { background: var(--cp-accent-soft); }
.nav .pill { width: 56px; height: 30px; border-radius: 15px; display: flex; align-items: center; justify-content: center; }
</style>
</head>
<body>
  <div class="status-bar"><span>9:41</span><span class="dots"><i></i><i></i></span></div>
  <div class="top-bar">
    <span class="btn">${i('back', 24)}</span>
    <span class="grow"></span>
    <span class="btn">${i('mute', 22)}</span>
    <span class="btn">${i('settings', 22)}</span>
  </div>

  <main class="page">
    <div class="banner" role="img" aria-label="Event cover (no photo)">
      <span class="big">${i('event', 56)}</span>
      <span class="label">Convention</span>
    </div>

    <div class="head">
      <div class="title-row"><span class="chip chip-neutral">Published</span></div>
      <h1>Lakeside Convention 2027</h1>
      <div class="meta">
        <div>${i('calendar', 17)} Fri 9 – Sun 11 July 2027</div>
        <div>${i('place', 17)} Lakeside Centre, Madison</div>
      </div>
      <div class="people"><span class="stack">${avatars}</span> 148 attending · 12 crew</div>
    </div>

    <div class="stats">
      <div class="card stat">
        <span class="k">${i('people', 15)} People</span>
        <span class="v">148</span>
        <span class="s">41 groups</span>
      </div>
      <div class="card stat">
        <span class="k">${i('tasks', 15)} Tasks</span>
        <div class="ring-wrap">
          <svg width="40" height="40" viewBox="0 0 40 40" aria-label="18 of 26 done">
            <circle cx="20" cy="20" r="${r}" fill="none" stroke="var(--cp-border)" stroke-width="5"/>
            <circle cx="20" cy="20" r="${r}" fill="none" stroke="var(--cp-accent)" stroke-width="5"
              stroke-linecap="round" stroke-dasharray="${(c * done).toFixed(1)} ${c.toFixed(1)}"
              transform="rotate(-90 20 20)"/>
          </svg>
          <span class="v" style="font-size:18px">18/26</span>
        </div>
        <span class="s">2 overdue</span>
      </div>
      <div class="card stat">
        <span class="k">${i('budget', 15)} Budget</span>
        <span class="v">$4,320</span>
        <span class="s">of $6,000</span>
      </div>
    </div>

    <section class="section">
      <div class="section-head"><h2>Up next</h2><a>Schedule ${i('chevron', 18)}</a></div>
      <div class="card list">
        ${session('9:00', 'AM', 'Registration opens', 'Main hall')}
        ${session('10:30', 'AM', 'Opening session', 'Ballroom A', 'Everyone')}
        ${session('12:30', 'PM', 'Lunch', 'Garden terrace')}
      </div>
    </section>

    <section class="section">
      <div class="section-head"><h2>Open tasks</h2><a>All tasks ${i('chevron', 18)}</a></div>
      <div class="card list">
        ${task('Confirm catering numbers', 'Priya · Logistics', 'overdue', 'Overdue')}
        ${task('Print name badges', 'Ravi · Registration', 'due', 'Due Fri')}
        ${task('Book sound crew', 'Asha · Programme', 'done', 'Done')}
      </div>
    </section>

    <section class="section">
      <div class="section-head"><h2>Event</h2></div>
      <div class="tiles">
        ${link('chat', 'Chat', 'Updates and talk', '3')}
        ${link('budget', 'Budget', 'You are owed $120')}
        ${link('schedule', 'Schedule', '24 sessions')}
        ${link('agenda', 'Agenda', 'Your own plan')}
        ${link('people', 'People', '148 people')}
        ${link('counts', 'Counts', 'Updated 5 min ago')}
      </div>
      <div class="button-secondary">${i('invite', 20)} Invite people</div>
    </section>
  </main>

  <nav class="nav">
    <div class="on"><span class="pill">${i('calendar', 22)}</span>Events</div>
    <div><span class="pill">${i('tasks', 22)}</span>Tasks</div>
    <div><span class="pill">${i('chat', 22)}</span>Chat</div>
    <div><span class="pill">${i('budget', 22)}</span>Budget</div>
    <div><span class="pill">${i('profile', 22)}</span>Profile</div>
  </nav>
</body>
</html>
`;
}

// ---------------------------------------------------------------- build

const chrome = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const png = process.argv.includes('--png');
mkdirSync(outDir, { recursive: true });

for (const direction of Object.keys(directions)) {
  for (const set of ['material', 'lucide']) {
    for (const mode of ['light', 'dark']) {
      const base = `event-home-${direction}-${set}-${mode}`;
      const html = join(outDir, `${base}.html`);
      writeFileSync(html, screen({ direction, set, mode }));
      if (png) {
        execFileSync(chrome, [
          '--headless=new', '--disable-gpu', '--hide-scrollbars',
          `--window-size=${width},${height}`, '--force-device-scale-factor=2',
          '--virtual-time-budget=8000',
          `--screenshot=${join(outDir, `${base}.png`)}`, `file://${html}`,
        ], { stdio: 'ignore' });
      }
      console.log(base);
    }
  }
}
