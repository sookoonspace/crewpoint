# Contributing to CrewPoint

Thanks for your interest in CrewPoint. This guide covers how to set up the
project, the gates a PR must clear, and the conventions we follow.

## Code of conduct

Contributions are expected to follow the
[Contributor Covenant](https://www.contributor-covenant.org/version/2/1/code_of_conduct/).
Be welcoming, assume good intent, give feedback on the work and not the
person.

## Getting set up

1. Clone the repo: `git clone git@github.com:sookoonspace/crewpoint.git`
2. Read **[ai_specs/setup-guide.md](ai_specs/setup-guide.md)** end-to-end.
   It covers Flutter SDK, Firebase project setup, FlutterFire CLI, IAM,
   and flavor switching. Skipping any of those steps is the most common
   reason a fresh checkout doesn't run.
3. Install dependencies:
   ```bash
   flutter pub get
   dart run build_runner build --delete-conflicting-outputs
   cd functions && npm ci && cd ..
   ```
4. Run the dev flavor:
   ```bash
   flutter run --flavor dev -t lib/main.dart
   ```

For web hosting setup (Firebase Hosting on `crewpoint.sookoon.space`),
see **[docs/web-hosting-guide.md](docs/web-hosting-guide.md)** *(forthcoming
in Phase 4)*.

For Cloud Functions deploy lifecycle, see
**[docs/cloud-functions-guide.md](docs/cloud-functions-guide.md)**.

## Branching

- `main` is the integration branch; PRs merge into it.
- Feature branches: `feat/<short-slug>` (e.g., `feat/responsive-shell`).
- Bug fixes: `fix/<short-slug>`.
- Docs-only: `docs/<short-slug>`.

Open a PR against `main` early; CI gates the rest.

## Commit messages

We use [Conventional Commits](https://www.conventionalcommits.org/). The
common prefixes:

- `feat(scope):` — new user-facing functionality.
- `fix(scope):` — bug fix.
- `docs(scope):` — documentation only.
- `refactor(scope):` — internal reshape, no behavior change.
- `test(scope):` — adding or improving tests.
- `chore(scope):` — tooling, deps, build config.

Subject ≤ 72 chars, imperative, no trailing period. Body explains the
*why* and any non-obvious decisions.

`release-drafter` builds the changelog from PR labels. Apply at least one
of: `feature`, `fix`, `docs`, `chore`, `breaking`. Maintainers add labels
during review if you forget.

## Testing gates

A PR must pass these locally and in CI:

```bash
flutter analyze                                # zero issues
flutter test                                   # all tests green
cd functions && npm run build && cd ..         # TypeScript typecheck
```

CI runs the same gates plus `flutter build web --release` (only when
web-relevant paths change — see `.github/workflows/web-build.yml`).

### Test invariant: never initialize Firebase from tests

Tests in `test/` **must not** call `Firebase.initializeApp()` or
`FirebaseService.initialize()`. Pumped widgets use Riverpod overrides on
the existing service interfaces (`IAuthService`, `IUserRepository`,
`IFcmGateway`, `IFileExporter`, `IUrlLauncher`). This keeps the suite
platform-channel-free and CI-portable. A grep guardrail enforces this:

```bash
grep -rn "Firebase.initializeApp\|FirebaseService.initialize" test/   # must be empty
```

## Style

Run `flutter analyze` before pushing. The project uses
`package:flutter_lints` plus `riverpod_lint` for Riverpod-specific checks.
We also use `custom_lint` — install it once with `dart run custom_lint`
to surface its warnings in your editor.

## Pull request checklist

The PR template enumerates this — copy it from `.github/PULL_REQUEST_TEMPLATE.md`
on a fresh PR. The minimum:

- [ ] `flutter analyze` clean
- [ ] `flutter test` green
- [ ] `cd functions && npm run build` green
- [ ] If UI changed: screenshot or screen recording in the PR body
- [ ] Conventional Commits format on every commit
- [ ] At least one release-drafter label applied

## Reporting issues

Open a GitHub issue with:

- What you expected
- What actually happened
- Steps to reproduce
- Flavor + platform (iOS / Android / web)
- Logs (`flutter logs --flavor dev` or browser console)

Security-sensitive issues: open a private security advisory on GitHub
instead of a public issue.
