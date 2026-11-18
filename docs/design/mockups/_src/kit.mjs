// Shared tokens, icons and PNG export for the Design refresh mockups
// (Spec #186). Round 1 (`build.mjs`) and Round 2 (`round2.mjs`) both read
// from here, so the chosen direction's values live in one place.

import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

export const here = dirname(fileURLToPath(import.meta.url));

// ---------------------------------------------------------------- tokens

export const status = {
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

export const shared = {
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

export function tokensCss(direction, mode) {
  const all = { ...directions[direction][mode], ...status[mode], ...shared };
  return Object.entries(all).map(([k, v]) => `  --cp-${k}: ${v};`).join('\n');
}

export const interFont =
  'https://fonts.googleapis.com/css2?family=Inter:opsz,wght@14..32,400..700&display=block';
export const materialFont =
  'https://fonts.googleapis.com/css2?family=Material+Symbols+Outlined:opsz,wght,FILL,GRAD@20..48,400,0,0&display=block';

// ---------------------------------------------------------------- icons

// [Material Symbols name, Lucide name]. Round 2 uses Lucide only (L22), so
// later keys leave the Material name null.
export const iconNames = {
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
  search: [null, 'search'],
  close: [null, 'x'],
  down: [null, 'chevron-down'],
  remove: [null, 'trash-2'],
  copy: [null, 'copy'],
  lock: [null, 'lock'],
  receipt: [null, 'receipt'],
  party: [null, 'party-popper'],
  heart: [null, 'heart'],
  flag: [null, 'flag'],
  trophy: [null, 'trophy'],
  dashboard: [null, 'layout-dashboard'],
  more: [null, 'ellipsis-vertical'],
  upload: [null, 'upload'],
  check: [null, 'check'],
  edit: [null, 'pencil'],
  settle: [null, 'arrow-left-right'],
  link: [null, 'circle-dot'],
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

export function iconFn(set) {
  return (key, size = 20) => {
    const [material, lucide] = iconNames[key];
    if (set === 'material') {
      return `<span class="icon ms" style="font-size:${size}px" aria-hidden="true">${material}</span>`;
    }
    return `<span class="icon" aria-hidden="true">${lucideSvg(lucide, size)}</span>`;
  };
}

// ---------------------------------------------------------------- export

const chrome = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';

export function exportPng(htmlPath, pngPath, width, height) {
  execFileSync(chrome, [
    '--headless=new', '--disable-gpu', '--hide-scrollbars',
    `--window-size=${width},${height}`, '--force-device-scale-factor=2',
    '--virtual-time-budget=8000',
    `--screenshot=${pngPath}`, `file://${htmlPath}`,
  ], { stdio: 'ignore' });
}
