import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:crewpoint_app/app/core/constants/app_colors.dart';
import 'package:crewpoint_app/app/core/constants/app_spacing.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';

/// Resolves an event by id from `dashboardEventsProvider` and renders one
/// of three states:
///
/// - **loading** — provider hasn't emitted yet → centered progress.
/// - **resolved** — event found in the user's stream → `child(event)`.
/// - **not found** — provider has emitted but event is absent. To suppress
///   the cold-start flicker on web reload / multi-device first-load, a 750
///   ms grace timer fires before the fallback shows. If the provider
///   re-emits with the event during the grace window, the resolved state
///   wins and `_graceElapsed` is reset.
///
/// Router-internal: drives every event-related route. Do not reuse outside
/// the router.
class EventGuard extends ConsumerStatefulWidget {
  const EventGuard({super.key, required this.eventId, required this.child});

  final String eventId;
  final Widget Function(EventModel) child;

  @override
  ConsumerState<EventGuard> createState() => _EventGuardState();
}

class _EventGuardState extends ConsumerState<EventGuard> {
  Timer? _graceTimer;
  bool _graceElapsed = false;

  @override
  void initState() {
    super.initState();
    // Evaluate the current state once on mount. flutter_riverpod 3's
    // WidgetRef.listen has no fireImmediately flag, so the listener in
    // build() only fires on transitions — without this initial pass, a
    // widget that mounts after dashboardEventsProvider is already in a
    // `data` state never schedules its grace timer.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.eventId.isEmpty) return;
      _evaluate(ref.read(dashboardEventsProvider));
    });
  }

  @override
  void didUpdateWidget(EventGuard old) {
    super.didUpdateWidget(old);
    if (old.eventId != widget.eventId) {
      _cancelGrace();
      _graceElapsed = false;
      // Re-evaluate against current state for the new id.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || widget.eventId.isEmpty) return;
        _evaluate(ref.read(dashboardEventsProvider));
      });
    }
  }

  @override
  void dispose() {
    _cancelGrace();
    super.dispose();
  }

  void _cancelGrace() {
    _graceTimer?.cancel();
    _graceTimer = null;
  }

  void _scheduleGrace() {
    if (_graceTimer != null || _graceElapsed) return;
    _graceTimer = Timer(const Duration(milliseconds: 750), () {
      if (!mounted) return;
      _graceTimer = null;
      setState(() => _graceElapsed = true);
    });
  }

  void _evaluate(AsyncValue<List<EventModel>> async) {
    async.whenOrNull(
      data: (events) {
        final hasEvent = events.any((e) => e.id == widget.eventId);
        if (hasEvent) {
          _cancelGrace();
          if (_graceElapsed && mounted) {
            setState(() => _graceElapsed = false);
          }
        } else {
          _scheduleGrace();
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.eventId.isEmpty) {
      return const EventNotFoundScreen(eventId: '');
    }

    // Riverpod's side-effect seam — fires only on state transitions.
    // Subscription is auto-managed; no manual cleanup needed.
    ref.listen<AsyncValue<List<EventModel>>>(
      dashboardEventsProvider,
      (_, next) => _evaluate(next),
    );

    final asyncEvents = ref.watch(dashboardEventsProvider);
    final event = ref.watch(eventByIdProvider(widget.eventId));
    if (event != null) return widget.child(event);

    return asyncEvents.when(
      loading: () => const _ProgressScaffold(),
      error: (_, _) => EventNotFoundScreen(eventId: widget.eventId),
      data: (_) => _graceElapsed
          ? EventNotFoundScreen(eventId: widget.eventId)
          : const _ProgressScaffold(),
    );
  }
}

class _ProgressScaffold extends StatelessWidget {
  const _ProgressScaffold();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.cream,
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

/// Friendly fallback for missing events (deleted, no access, or bad URL).
/// Logs the requested eventId once on first build via `developer.log`.
class EventNotFoundScreen extends StatefulWidget {
  const EventNotFoundScreen({super.key, required this.eventId});

  final String eventId;

  @override
  State<EventNotFoundScreen> createState() => _EventNotFoundScreenState();
}

class _EventNotFoundScreenState extends State<EventNotFoundScreen> {
  @override
  void initState() {
    super.initState();
    developer.log(
      'Event not found: ${widget.eventId.isEmpty ? "<empty>" : widget.eventId}',
      name: 'router',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: AppSpacing.lg,
              children: [
                const Icon(
                  Icons.event_busy_outlined,
                  size: 64,
                  color: AppColors.sage,
                ),
                Text(
                  "We couldn't find that event",
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  'It may have been deleted, or you may not have access.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                ElevatedButton.icon(
                  key: const Key('event.notFound.back'),
                  onPressed: () => context.go('/dashboard'),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Back to events'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.sage,
                    foregroundColor: AppColors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
