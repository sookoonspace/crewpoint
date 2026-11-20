# Design refresh mockups

Static HTML screens exported to PNG for the Design refresh ([Spec #186](https://github.com/sookoonspace/crewpoint/issues/186)). Phone screens are 390 px wide, in light and dark. Each HTML file names its colour, type, spacing and radius values in a `:root` token block, so the chosen direction becomes the app's token file.

> **Superseded by the code.** Every screen here is now built (Spec #186, finished in #208), so the app and [`../design-system.md`](../design-system.md) are the source of truth. These files are kept as the record of the agreed direction and are not updated (Spec Req 19).

## Round 1 ([#189](https://github.com/sookoonspace/crewpoint/issues/189))

The Event home in three directions (Slate and sage, Ink and indigo, Warm neutral), each with Material Symbols Outlined and with Lucide icons, in light and dark: `round-1/event-home-<direction>-<icons>-<mode>.{html,png}`. `round-1/overview.html` is the review page, also published as a private page: https://claude.ai/artifact/LWKb6KDEKVbp7kCoSiUfhb

**Chosen: Slate and sage, with Lucide icons** (ledger L22). Round 2 and the design system tokens start from `round-1/event-home-slate-sage-lucide-{light,dark}.html`.

## Round 2 ([#190](https://github.com/sookoonspace/crewpoint/issues/190))

Slate and sage with Lucide, in light and dark: `round-2/<screen>-<mode>.{html,png}`. **Approved by the owner on 2026-11-18**; all of them are now built.

| Screen | File |
|---|---|
| Home (event list) | `home` |
| Event home, with a cover photo | `event-home` |
| Event home, no cover photo | `event-home-no-photo` |
| People (roster) | `people` |
| New group | `new-group` |
| Person form | `person-form` |
| Schedule (day) | `schedule` |
| Tasks | `tasks` |
| Budget | `budget` |
| Create event (template picker) | `create-event` |
| Event home on a laptop (1280 px) | `laptop-event-home` |
| People on a laptop, list and detail (1280 px) | `laptop-people` |

The mockups use the Convention template's words ("Family" for group). The lakeside picture is a drawn stand-in for an organizer's own cover photo. Chat, settings, roles, counts and other admin screens have no mockups; they follow the design system. `round-2/overview.html` is the review page, published at the same private link as Round 1.

## Rebuilding

```bash
node docs/design/mockups/_src/build.mjs --png    # Round 1; needs Google Chrome; drop --png for HTML only
node docs/design/mockups/_src/round2.mjs --png   # Round 2; --only=<screen> rebuilds one screen
```

`_src/kit.mjs` holds the tokens, icon names and PNG export that both rounds share; `build.mjs` and `round2.mjs` hold the screens. Lucide icons are inlined from `_src/lucide/` (lucide-static 0.469.0, ISC licence); Material Symbols and Inter load from Google Fonts.
