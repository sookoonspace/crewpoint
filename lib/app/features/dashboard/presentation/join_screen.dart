import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:crewpoint_app/app/core/constants/app_icons.dart';
import 'package:crewpoint_app/app/core/constants/app_spacing.dart';
import 'package:crewpoint_app/app/core/constants/breakpoints.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/core/router/app_router.dart';
import 'package:crewpoint_app/app/core/widgets/content_max_width.dart';
import 'package:crewpoint_app/app/features/dashboard/data/member_calls.dart';

/// Where an invite link or QR code lands (Req 47, route `/join/:code`). A
/// signed-out person signs in first and comes back here. It shows the event
/// and the role the invite carries, explains when the event is a draft,
/// ended or full, and joins with one tap. Joining needs a connection.
class JoinScreen extends ConsumerStatefulWidget {
  const JoinScreen({super.key, required this.code});

  final String code;

  @override
  ConsumerState<JoinScreen> createState() => _JoinScreenState();
}

enum _Problem { notFound, offline, joinFailed }

class _JoinScreenState extends ConsumerState<JoinScreen> {
  InvitePreview? _preview;
  _Problem? _problem;
  bool _loading = true;
  bool _joining = false;

  String get _code => widget.code.trim().toUpperCase();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _problem = null;
    });
    try {
      final preview = await ref.read(memberCallsProvider).previewInvite(_code);
      if (mounted) setState(() => _preview = preview);
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        setState(
          () => _problem = e.code == 'not-found' || e.code == 'invalid-argument'
              ? _Problem.notFound
              : _Problem.offline,
        );
      }
    } catch (_) {
      if (mounted) setState(() => _problem = _Problem.offline);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openEvent(String eventId) =>
      context.go('${AppRoutes.dashboard}/event/$eventId');

  Future<void> _join() async {
    final strings = context.strings.invites;
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _joining = true;
      _problem = null;
    });
    try {
      final eventId = await ref.read(memberCallsProvider).joinEvent(_code);
      messenger.showSnackBar(SnackBar(content: Text(strings.joined)));
      if (mounted) _openEvent(eventId);
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      if (e.code == 'already-exists') {
        _openEvent(_preview!.eventId);
      } else if (e.code == 'unavailable' ||
          e.code == 'internal' ||
          e.code == 'deadline-exceeded') {
        setState(() => _problem = _Problem.joinFailed);
      } else {
        // The event changed since it was shown: show it again.
        await _load();
      }
    } catch (_) {
      if (mounted) setState(() => _problem = _Problem.joinFailed);
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings.invites;
    final theme = Theme.of(context);
    final padding = Breakpoints.screenHorizontalPadding(context);

    final Widget body;
    if (_loading) {
      body = Column(
        key: const Key('join.loading'),
        spacing: AppSpacing.md,
        children: [
          const CircularProgressIndicator(),
          Text(strings.joinLoading),
        ],
      );
    } else if (_problem == _Problem.notFound) {
      body = _Message(
        key: const Key('join.notFound'),
        icon: AppIcons.statusError,
        text: strings.notFound,
      );
    } else if (_preview == null) {
      body = _Message(
        key: const Key('join.error'),
        icon: AppIcons.wifiOff,
        text: strings.joinFailed,
        action: TextButton.icon(
          key: const Key('join.retry'),
          onPressed: _load,
          icon: const Icon(AppIcons.actionRetry),
          label: Text(strings.retry),
        ),
      );
    } else {
      final p = _preview!;
      final start = p.startDate;
      final String? notice = p.alreadyMember
          ? strings.alreadyMember
          : !p.open
          ? (p.reason == 'draft' ? strings.notOpenDraft : strings.notOpenEnded)
          : p.full
          ? strings.full
          : null;
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpacing.md,
        children: [
          Text(
            p.title,
            key: const Key('join.title'),
            style: theme.textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          if (start != null)
            Text(
              strings.startsOn(
                p.dateOnly
                    ? DateFormat.yMMMMEEEEd().format(
                        DateTime(start.year, start.month, start.day),
                      )
                    : DateFormat.yMMMMEEEEd().add_jm().format(start.toLocal()),
              ),
              textAlign: TextAlign.center,
            ),
          if (!p.alreadyMember)
            Text(
              strings.joinAs(p.roleName),
              key: const Key('join.role'),
              textAlign: TextAlign.center,
            ),
          if (notice != null)
            Text(
              notice,
              key: const Key('join.notice'),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: p.alreadyMember
                    ? theme.colorScheme.onSurface
                    : theme.colorScheme.error,
              ),
            ),
          if (_problem == _Problem.joinFailed)
            Text(
              strings.joinFailed,
              key: const Key('join.failed'),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          if (p.alreadyMember)
            FilledButton(
              key: const Key('join.open'),
              onPressed: () => _openEvent(p.eventId),
              style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
              child: Text(strings.openEvent),
            )
          else if (notice == null)
            FilledButton(
              key: const Key('join.submit'),
              onPressed: _joining ? null : _join,
              style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
              child: _joining
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(strings.joinButton),
            ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(strings.joinTitle), elevation: 0),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          padding,
          AppSpacing.xl,
          padding,
          AppSpacing.xl,
        ),
        children: [
          ContentMaxWidth(
            maxWidth: 560,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: AppSpacing.lg,
              children: [
                body,
                Text(
                  strings.joinNeedsConnection,
                  key: const Key('join.online'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall,
                ),
                TextButton(
                  key: const Key('join.back'),
                  onPressed: () => context.go(AppRoutes.dashboard),
                  child: Text(strings.backToEvents),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    super.key,
    required this.icon,
    required this.text,
    this.action,
  });

  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      spacing: AppSpacing.md,
      children: [
        Icon(icon, size: 48, color: theme.colorScheme.onSurfaceVariant),
        Text(text, textAlign: TextAlign.center),
        ?action,
      ],
    );
  }
}
