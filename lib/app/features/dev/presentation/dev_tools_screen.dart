import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:crewpoint_app/app/core/design/components/components.dart';
import 'package:crewpoint_app/app/core/design/tokens/cp_icons.dart';
import 'package:crewpoint_app/app/core/design/tokens/tokens.dart';
import 'package:crewpoint_app/app/core/env/app_flavor.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/core/widgets/content_max_width.dart';
import 'package:crewpoint_app/app/core/router/app_router.dart';
import 'package:crewpoint_app/app/core/providers.dart';

/// Flavor-gated developer console at `/profile/dev-tools`. Surfaces ad-hoc
/// diagnostics that bypass the regular UI — currently:
///
///  * **FCM state check** — dumps the OS authorization status, APNs token,
///    FCM token, and the `users/{uid}/private/profile.fcmTokens` array so
///    we can see which leg of the iOS push chain is broken.
///  * **Design gallery** — every design-system component (Spec #186).
///  * **Force re-attach** — replays `FcmService.attach(uid)` so the
///    token-refresh-after-APNs-ready path can be exercised on demand.
///
/// More tiles can land here as new debug needs come up. Production
/// builds never reach this screen — the route is registered only when
/// `AppFlavor.current == AppFlavor.dev` (see `app_router.dart`).
class DevToolsScreen extends ConsumerWidget {
  const DevToolsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cp = context.cp;
    final s = context.strings.dev;
    final uid = ref.watch(currentUserIdProvider);
    final navigator = Navigator.of(context);
    return Scaffold(
      backgroundColor: cp.colors.background,
      appBar: CpTopBar(
        title: s.title,
        leadingTooltip: MaterialLocalizations.of(context).backButtonTooltip,
        onLeading: navigator.canPop() ? () => navigator.maybePop() : null,
      ),
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
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: CpTag(
                    label: s.flavorLine(AppFlavor.current.name),
                    icon: CpIcons.devTools,
                  ),
                ),
                if (uid == null)
                  CpCard(
                    padding: EdgeInsets.all(cp.space.lg),
                    child: Text(
                      s.signInForDiagnostics,
                      style: cp.type.bodyMedium.copyWith(color: cp.colors.text),
                    ),
                  )
                else
                  _FcmDiagnosticTile(uid: uid),
                const _CrashTestCard(),
                CpCard(
                  child: CpListRow(
                    key: const Key('dev.designGallery'),
                    leading: Icon(
                      CpIcons.image,
                      size: cp.sizes.iconMd,
                      color: cp.colors.textMuted,
                    ),
                    title: s.galleryTitle,
                    subtitle: s.galleryHelp,
                    onTap: () => context.push(AppRoutes.designGallery),
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

/// A card's heading, with an icon and anything trailing, such as a
/// spinner.
class _CardHeading extends StatelessWidget {
  const _CardHeading({required this.icon, required this.title, this.trailing});

  final IconData icon;
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    return Row(
      spacing: cp.space.sm,
      children: [
        Icon(icon, size: cp.sizes.iconMd, color: cp.colors.textMuted),
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              title,
              style: cp.type.titleMedium.copyWith(color: cp.colors.text),
            ),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

/// Confirms crash reports arrive (Req 68): sends a handled test report and
/// shows its ID, or throws an uncaught error to exercise the automatic
/// capture. Debug builds need `--dart-define=SENTRY_DEBUG=true` for either
/// to reach Sentry.
class _CrashTestCard extends ConsumerStatefulWidget {
  const _CrashTestCard();

  @override
  ConsumerState<_CrashTestCard> createState() => _CrashTestCardState();
}

class _CrashTestCardState extends ConsumerState<_CrashTestCard> {
  String? _result;

  Future<void> _sendReport() async {
    final s = context.strings.dev;
    final id = await ref
        .read(crashReporterProvider)
        .report(
          StateError('CrewPoint test crash from Dev Tools'),
          StackTrace.current,
        );
    if (!mounted) return;
    setState(() => _result = id == null ? s.crashNotSent : s.crashSent(id));
  }

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    final s = context.strings.dev;
    final isOn = ref.watch(crashReporterProvider).isOn;
    final body = cp.type.bodyMedium.copyWith(color: cp.colors.text);
    return CpCard(
      padding: EdgeInsets.all(cp.space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: cp.space.md,
        children: [
          _CardHeading(icon: CpIcons.statusError, title: s.crashHeading),
          if (!isOn)
            Text(s.crashOff, key: const Key('dev.crash.off'), style: body)
          else ...[
            Wrap(
              spacing: cp.space.sm,
              runSpacing: cp.space.sm,
              children: [
                CpButton(
                  key: const Key('dev.crash.report'),
                  label: s.crashSend,
                  onPressed: _sendReport,
                ),
                CpButton.secondary(
                  key: const Key('dev.crash.throw'),
                  label: s.crashThrow,
                  onPressed: () => throw StateError(
                    'CrewPoint uncaught test error from Dev Tools',
                  ),
                ),
              ],
            ),
            if (_result != null)
              SelectableText(
                _result!,
                key: const Key('dev.crash.result'),
                style: body,
              ),
          ],
        ],
      ),
    );
  }
}

class _FcmDiagnosticTile extends ConsumerStatefulWidget {
  const _FcmDiagnosticTile({required this.uid});

  final String uid;

  @override
  ConsumerState<_FcmDiagnosticTile> createState() => _FcmDiagnosticTileState();
}

class _FcmDiagnosticTileState extends ConsumerState<_FcmDiagnosticTile> {
  _FcmDiagnosticResult? _result;
  bool _running = false;
  bool _reAttaching = false;

  @override
  void initState() {
    super.initState();
    // Auto-run once on open so the user doesn't have to tap to see the
    // current state. Cheaper than a Stream subscription for a manual tool.
    Future.microtask(_run);
  }

  Future<void> _run() async {
    if (_running) return;
    setState(() => _running = true);
    try {
      final result = await _collectFcmState(widget.uid);
      if (!mounted) return;
      setState(() {
        _result = result;
        _running = false;
      });
    } catch (e, st) {
      if (!mounted) return;
      setState(() {
        _result = _FcmDiagnosticResult.failure('$e\n$st');
        _running = false;
      });
    }
  }

  Future<void> _forceReAttach() async {
    if (_reAttaching) return;
    final s = context.strings.dev;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _reAttaching = true);
    try {
      final service = ref.read(fcmServiceProvider);
      final ok = await service.attach(uid: widget.uid);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(ok ? s.fcmAttached : s.fcmNotAttached)),
      );
      await _run();
    } finally {
      if (mounted) setState(() => _reAttaching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    final s = context.strings.dev;
    final result = _result;
    return CpCard(
      padding: EdgeInsets.all(cp.space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: cp.space.md,
        children: [
          _CardHeading(
            icon: CpIcons.notifications,
            title: s.fcmHeading,
            trailing: _running
                ? SizedBox.square(
                    dimension: cp.sizes.iconSm,
                    child: CircularProgressIndicator(
                      strokeWidth: cp.sizes.avatarRing,
                      color: cp.colors.accent,
                    ),
                  )
                : null,
          ),
          Text(
            s.uidLine(widget.uid),
            style: cp.type.bodySmall.copyWith(color: cp.colors.textMuted),
          ),
          if (result != null) _resultBody(context, result),
          Wrap(
            spacing: cp.space.sm,
            runSpacing: cp.space.sm,
            children: [
              CpButton.secondary(
                key: const Key('dev.fcm.rerun'),
                label: s.fcmRerun,
                icon: CpIcons.actionRetry,
                onPressed: _running ? null : _run,
              ),
              CpButton(
                key: const Key('dev.fcm.reattach'),
                label: s.fcmReattach,
                icon: CpIcons.actionRetry,
                busy: _reAttaching,
                onPressed: _forceReAttach,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _resultBody(BuildContext context, _FcmDiagnosticResult result) {
    final cp = context.cp;
    final s = context.strings.dev;
    if (result.errorBlob != null) {
      return SelectableText(
        result.errorBlob!,
        style: cp.type.bodySmall.copyWith(color: cp.colors.overdue),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: cp.space.sm,
      children: [
        _Row(s.fcmAuthStatus, result.authorizationStatus ?? '—'),
        _Row(s.fcmApnsToken, result.apnsToken ?? s.fcmApnsMissing),
        _Row(
          s.fcmLiveToken,
          result.fcmTokenError != null
              ? s.fcmError(result.fcmTokenError!)
              : (result.fcmToken ?? '(null)'),
        ),
        _Row(
          s.fcmStoredTokens,
          result.firestoreTokens.isEmpty
              ? s.fcmNoStoredTokens
              : '${s.fcmTokenCount(result.firestoreTokens.length)}\n'
                    '${result.firestoreTokens.map(_truncate).join('\n')}',
        ),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: CpButton.text(
            key: const Key('dev.fcm.copy'),
            label: s.copyReport,
            icon: CpIcons.actionCopy,
            onPressed: () => _copyToClipboard(context, _formatForCopy(result)),
          ),
        ),
      ],
    );
  }
}

String _truncate(String token) => token.length <= 24
    ? token
    : '${token.substring(0, 16)}…${token.substring(token.length - 6)}';

String _formatForCopy(_FcmDiagnosticResult r) {
  final lines = <String>[
    'auth: ${r.authorizationStatus}',
    'apns: ${r.apnsToken ?? "null"}',
    'fcm:  ${r.fcmTokenError != null ? "ERR: ${r.fcmTokenError}" : r.fcmToken ?? "null"}',
    'firestore tokens (${r.firestoreTokens.length}):',
    ...r.firestoreTokens.map((t) => '  - $t'),
  ];
  return lines.join('\n');
}

void _copyToClipboard(BuildContext context, String text) {
  Clipboard.setData(ClipboardData(text: text));
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(context.strings.dev.copied)));
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: cp.space.xs / 2,
      children: [
        Text(
          label,
          style: cp.type.labelSmall.copyWith(color: cp.colors.textMuted),
        ),
        SelectableText(
          value,
          style: cp.type.bodySmall.copyWith(color: cp.colors.text),
        ),
      ],
    );
  }
}

class _FcmDiagnosticResult {
  const _FcmDiagnosticResult({
    this.authorizationStatus,
    this.apnsToken,
    this.fcmToken,
    this.fcmTokenError,
    this.firestoreTokens = const [],
    // Analyzer false positive under Dart 3.13 (Flutter 3.47): the
    // redirecting constructor below does supply this, and it is read at
    // `_resultBody`, but `unused_element_parameter` does not count a
    // redirecting generative constructor as giving a value.
    // ignore: unused_element_parameter
    this.errorBlob,
  });

  const _FcmDiagnosticResult.failure(String blob) : this(errorBlob: blob);

  final String? authorizationStatus;
  final String? apnsToken;
  final String? fcmToken;
  final String? fcmTokenError;
  final List<String> firestoreTokens;
  final String? errorBlob;
}

Future<_FcmDiagnosticResult> _collectFcmState(String uid) async {
  final messaging = FirebaseMessaging.instance;
  final settings = await messaging.getNotificationSettings();
  final apnsToken = await messaging.getAPNSToken();
  String? fcmToken;
  String? fcmTokenError;
  try {
    fcmToken = await messaging.getToken();
  } catch (e) {
    fcmTokenError = '$e';
  }

  final snap = await FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('private')
      .doc('profile')
      .get();
  final raw = snap.data()?['fcmTokens'];
  final firestoreTokens = <String>[];
  if (raw is List) {
    for (final entry in raw) {
      if (entry is String) firestoreTokens.add(entry);
    }
  }

  return _FcmDiagnosticResult(
    authorizationStatus: settings.authorizationStatus.name,
    apnsToken: apnsToken,
    fcmToken: fcmToken,
    fcmTokenError: fcmTokenError,
    firestoreTokens: firestoreTokens,
  );
}
