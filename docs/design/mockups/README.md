# Design refresh mockups

Static HTML screens exported to PNG for the Design refresh ([Spec #186](https://github.com/sookoonspace/crewpoint/issues/186)). Phone screens are 390 px wide, in light and dark. Each HTML file names its colour, type, spacing and radius values in a `:root` token block, so the chosen direction becomes the app's token file.

The PNGs are the agreed look until a screen is built; after that the code is the source of truth (Spec Req 19).

## Round 1 ([#189](https://github.com/sookoonspace/crewpoint/issues/189))

The Event home in three directions (Slate and sage, Ink and indigo, Warm neutral), each with Material Symbols Outlined and with Lucide icons, in light and dark: `round-1/event-home-<direction>-<icons>-<mode>.{html,png}`. `round-1/overview.html` is the review page, also published as a private page: https://claude.ai/artifact/LWKb6KDEKVbp7kCoSiUfhb

**Chosen: Slate and sage, with Lucide icons** (ledger L22). Round 2 and the design system tokens start from `round-1/event-home-slate-sage-lucide-{light,dark}.html`.

## Rebuilding

```bash
node docs/design/mockups/_src/build.mjs --png   # needs Google Chrome; drop --png for HTML only
```

`_src/build.mjs` holds the tokens and the screen. Lucide icons are inlined from `_src/lucide/` (lucide-static 0.469.0, ISC licence); Material Symbols and Inter load from Google Fonts.
