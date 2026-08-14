import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crewpoint_app/app/core/constants/app_spacing.dart';
import 'package:crewpoint_app/app/core/env/app_flavor.dart';
import 'package:crewpoint_app/app/core/providers.dart';

/// Flavor-gated developer console at `/profile/dev-tools`. Surfaces ad-hoc
/// diagnostics that bypass the regular UI — currently:
///
///  * **FCM state check** — dumps the OS authorization status, APNs token,
///    FCM token, and the `users/{uid}/private/profile.fcmTokens` array so
///    we can see which leg of the iOS push chain is broken.
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
    final uid = ref.watch(currentUserIdProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Dev Tools'), elevation: 0),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          _FlavorBanner(),
          const SizedBox(height: AppSpacing.lg),
          if (uid == null)
            const _NotSignedInCard()
          else
            _FcmDiagnosticTile(uid: uid),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}

class _FlavorBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: Colors.amber.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber.shade400),
      ),
      child: Text(
        'flavor: ${AppFlavor.current.name} · build: debug-only',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Colors.amber.shade900,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _NotSignedInCard extends StatelessWidget {
  const _NotSignedInCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Text(
          'Sign in to run diagnostics that need a uid '
          '(FCM token registration, Firestore round-trip, etc).',
        ),
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
    setState(() => _reAttaching = true);
    try {
      final service = ref.read(fcmServiceProvider);
      final ok = await service.attach(uid: widget.uid);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? 'attach() returned true — token written'
                : 'attach() returned false — see diagnostics below',
          ),
        ),
      );
      await _run();
    } finally {
      if (mounted) setState(() => _reAttaching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.notifications_active),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'FCM diagnostic',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (_running)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'uid: ${widget.uid}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.md),
            if (result != null) _resultBody(context, result),
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                OutlinedButton.icon(
                  onPressed: _running ? null : _run,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Re-run check'),
                ),
                FilledButton.icon(
                  onPressed: _reAttaching ? null : _forceReAttach,
                  icon: _reAttaching
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Force re-attach'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _resultBody(BuildContext context, _FcmDiagnosticResult result) {
    if (result.errorBlob != null) {
      return SelectableText(
        result.errorBlob!,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.error,
          fontFamily: 'monospace',
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Row('Auth status', result.authorizationStatus ?? '—'),
        _Row(
          'APNs token',
          result.apnsToken ?? '(null) — APNs not registered yet',
        ),
        _Row(
          'FCM token (live)',
          result.fcmTokenError != null
              ? 'ERROR: ${result.fcmTokenError}'
              : (result.fcmToken ?? '(null)'),
        ),
        _Row(
          'Firestore fcmTokens',
          result.firestoreTokens.isEmpty
              ? '(empty array — token not yet written)'
              : '${result.firestoreTokens.length} token(s):\n'
                    '${result.firestoreTokens.map(_truncate).join('\n')}',
        ),
        const SizedBox(height: AppSpacing.sm),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => _copyToClipboard(context, _formatForCopy(result)),
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Copy report'),
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
  ).showSnackBar(const SnackBar(content: Text('Copied to clipboard')));
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          SelectableText(
            value,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
          ),
        ],
      ),
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
