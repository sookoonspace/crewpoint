## Overview

Replace default Flutter README with a real project README. Quick plan; no spec.

## Context

- **Structure**: feature-first under `lib/app/features/`; core in `lib/app/core/`
- **State management**: Riverpod 3 (hand-written `Notifier`s, no codegen yet)
- **Existing docs**: `docs/cloud-functions-guide.md` (deploy), `ai_specs/setup-guide.md` (Firebase setup), `ai_specs/todo.md` (backlog), `ai_specs/*-spec.md` + `*-plan.md` (feature history)
- **Remote**: `git@github.com:sookoonspace/crewpoint.git`
- **Assumptions**: licensing not specified — leave LICENSE out; user can add if needed

## Plan

### Phase 1: Refresh README

- **Goal**: README matches the actual app instead of Flutter boilerplate.
- [ ] `README.md` — replace template with sections:
  - One-line tagline + 1-paragraph overview (CrewPoint = collaborative event management; tasks, budget w/ Splitwise-style ledger, chat with urgent push)
  - Feature highlights (Events + RBAC, Tasks, Budget + deep-link settle, Chat + urgent push)
  - Tech stack (Flutter 3.11.5 / Dart 3, Riverpod 3, Firebase Auth + Firestore + Storage + Functions + Messaging, Drift v4, go_router 14)
  - Project layout (`lib/app/features/{feature}/{data,domain,application,presentation}` + `lib/app/core/`)
  - Getting started (clone, `flutter pub get`, build_runner, run with flavor — point at `ai_specs/setup-guide.md` for Firebase config)
  - Build flavors (dev/stg/prod via existing `flutter_launcher_icons-*.yaml` + `firebase.json`)
  - Cloud Functions (link to `docs/cloud-functions-guide.md`; one-line build/deploy reminder)
  - Testing (`flutter test`; 133 tests; robot journey at `test/journeys/`)
  - Architecture pointers (Firestore source of truth + Drift mirror; pure utilities in `data/` like `PayLinkBuilder`; test seams: `IFcmGateway`, `IUrlLauncher`, `AppLifecycleSource`)
  - Roadmap pointer to `ai_specs/todo.md`
- [ ] Verify: `flutter analyze` (README change is doc-only; this is the smoke that nothing else regressed)

## Risks / Out of scope

- **Risks**: Drift in feature scope while writing — keep README a digest, not duplicate of `ai_specs/setup-guide.md` or `docs/cloud-functions-guide.md`
- **Out of scope**: LICENSE, CONTRIBUTING.md, CI badges, screenshot embed, releasing notes — add only if user later asks
