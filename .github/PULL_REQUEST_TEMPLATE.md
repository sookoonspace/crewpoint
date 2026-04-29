<!--
Thanks for the PR! Replace the placeholder text in each section. Sections
you don't use can be left out — but the Checklist is required.
-->

## Summary

<!-- 1–3 sentences describing what this PR changes and why. -->

## Changes

<!-- Bullet list of the concrete changes. File paths are great. -->

-

## Testing

<!-- How did you verify this? Unit tests? Widget tests? Manual smoke?
     If manual, list the flows you exercised and the platform(s). -->

-

## Screenshots / recording

<!-- For UI changes: drag-and-drop a screenshot or screen recording.
     Mobile + web if both are affected. Skip the section if no UI change. -->

## Checklist

- [ ] `flutter analyze` clean
- [ ] `flutter test` green
- [ ] `cd functions && npm run build` green (if `functions/**` touched)
- [ ] At least one release-drafter label applied (`feature` / `fix` /
      `docs` / `chore` / `breaking`)
- [ ] Commits follow Conventional Commits format
- [ ] No secrets, `.p8` keys, or `.env` files committed
- [ ] Tests do not call `Firebase.initializeApp()` or
      `FirebaseService.initialize()` (use Riverpod overrides instead)
