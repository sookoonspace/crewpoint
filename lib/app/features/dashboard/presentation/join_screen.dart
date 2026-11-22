import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:crewpoint_app/app/core/design/components/components.dart';
import 'package:crewpoint_app/app/core/design/tokens/cp_icons.dart';
import 'package:crewpoint_app/app/core/design/tokens/tokens.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/core/router/app_router.dart';
import 'package:crewpoint_app/app/core/widgets/content_max_width.dart';
import 'package:crewpoint_app/app/features/dashboard/data/member_calls.dart';

/// Where an invite link or QR code lands (Req 47, route `/join/:code`;
/// Spec #186). A
/// signed-out person signs in first and comes back here. It shows the event
/// and the role the invite carries, explains when the event is a draft,
/// ended or full, or the link was used, turned off or expired (#238), and
/// joins with one tap. Joining needs a connection.
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

  /// Why a known link cannot be used (`used`, `off`, `expired`; #238).
  String? _unusable;
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
        setState(() {
          _unusable = unusableInviteReason(e);
          _problem = e.code == 'not-found' || e.code == 'invalid-argument'
              ? _Problem.notFound
              : _Problem.offline;
        });
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
    final cp = context.cp;
    final strings = context.strings.invites;

    final Widget body;
    if (_loading) {
      body = CpLoadingState(
        key: const Key('join.loading'),
        semanticLabel: strings.joinLoading,
        label: strings.joinLoading,
      );
    } else if (_problem == _Problem.notFound) {
      body = CpEmptyState(
        key: const Key('join.notFound'),
        icon: CpIcons.statusError,
        title: strings.unusable(_unusable),
      );
    } else if (_preview == null) {
      body = CpErrorState(
        key: const Key('join.error'),
        icon: CpIcons.wifiOff,
        title: strings.joinFailed,
        retryLabel: strings.retry,
        retryKey: const Key('join.retry'),
        onRetry: _load,
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
        spacing: cp.space.lg,
        children: [
          CpCard(
            padding: EdgeInsets.all(cp.space.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: cp.space.sm,
              children: [
                Container(
                  width: cp.sizes.iconTile,
                  height: cp.sizes.iconTile,
                  decoration: BoxDecoration(
                    color: cp.colors.accentSoft,
                    borderRadius: cp.radii.sm,
                  ),
                  child: Icon(
                    CpIcons.joinEvent,
                    size: cp.sizes.iconMd,
                    color: cp.colors.accent,
                  ),
                ),
                Text(
                  p.title,
                  key: const Key('join.title'),
                  style: cp.type.headlineSmall.copyWith(color: cp.colors.text),
                ),
                if (start != null)
                  Text(
                    strings.startsOn(
                      p.dateOnly
                          ? DateFormat.yMMMMEEEEd().format(
                              DateTime(start.year, start.month, start.day),
                            )
                          : DateFormat.yMMMMEEEEd().add_jm().format(
                              start.toLocal(),
                            ),
                    ),
                    style: cp.type.bodyMedium.copyWith(
                      color: cp.colors.textMuted,
                    ),
                  ),
                if (!p.alreadyMember)
                  Text(
                    strings.joinAs(p.roleName),
                    key: const Key('join.role'),
                    style: cp.type.bodyLarge.copyWith(color: cp.colors.text),
                  ),
              ],
            ),
          ),
          // Why joining is not offered: an icon with the words, never
          // colour alone.
          if (notice != null)
            Container(
              key: const Key('join.notice'),
              padding: EdgeInsets.all(cp.space.md),
              decoration: BoxDecoration(
                color: cp.colors.accentSoft,
                borderRadius: cp.radii.md,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: cp.space.sm,
                children: [
                  Icon(
                    p.alreadyMember ? CpIcons.statusDone : CpIcons.statusInfo,
                    size: cp.sizes.iconMd,
                    color: cp.colors.accent,
                  ),
                  Expanded(
                    child: Text(
                      notice,
                      style: cp.type.bodyMedium.copyWith(color: cp.colors.text),
                    ),
                  ),
                ],
              ),
            ),
          if (_problem == _Problem.joinFailed)
            Container(
              padding: EdgeInsets.all(cp.space.md),
              decoration: BoxDecoration(
                color: cp.colors.overdueSoft,
                borderRadius: cp.radii.md,
              ),
              child: CpFieldError(
                strings.joinFailed,
                key: const Key('join.failed'),
              ),
            ),
          if (p.alreadyMember)
            CpButton(
              key: const Key('join.open'),
              label: strings.openEvent,
              expand: true,
              onPressed: () => _openEvent(p.eventId),
            )
          else if (notice == null)
            CpButton(
              key: const Key('join.submit'),
              label: strings.joinButton,
              expand: true,
              busy: _joining,
              onPressed: _join,
            ),
        ],
      );
    }

    return Scaffold(
      backgroundColor: cp.colors.background,
      appBar: CpTopBar(title: strings.joinTitle),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          cp.space.lg,
          cp.space.sm,
          cp.space.lg,
          cp.space.xxl,
        ),
        children: [
          ContentMaxWidth(
            maxWidth: cp.sizes.phoneColumn,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: cp.space.lg,
              children: [
                body,
                Text(
                  strings.joinNeedsConnection,
                  key: const Key('join.online'),
                  textAlign: TextAlign.center,
                  style: cp.type.bodySmall.copyWith(color: cp.colors.textMuted),
                ),
                Center(
                  child: CpButton.text(
                    key: const Key('join.back'),
                    label: strings.backToEvents,
                    onPressed: () => context.go(AppRoutes.dashboard),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
