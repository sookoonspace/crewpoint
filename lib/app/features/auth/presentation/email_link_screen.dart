import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:crewpoint_app/app/core/design/components/components.dart';
import 'package:crewpoint_app/app/core/design/tokens/cp_icons.dart';
import 'package:crewpoint_app/app/core/design/tokens/tokens.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/core/services/i_auth_service.dart';
import 'package:crewpoint_app/app/core/widgets/content_max_width.dart';
import 'package:crewpoint_app/app/features/auth/presentation/widgets/light_sign_in_panel.dart';

/// Paths a sign-in link may return to, as the router allows.
String safeReturnPath(String? to) {
  const prefixes = ['/join/', '/e/', '/r/'];
  return to != null && prefixes.any(to.startsWith) && !to.contains('//')
      ? to
      : '/';
}

enum _Step { working, confirm, expired }

/// Where an email sign-in link opens, `/auth/link?to=…` (Spec #233 Req 12;
/// #241), outside the shell. On the device that asked for it, it signs in
/// at once and returns to `to`. On another device it asks "Confirm your
/// email to finish signing in"; a different address is refused, and an
/// expired or used link offers a new one, a phone code or Google or Apple.
class EmailLinkScreen extends ConsumerStatefulWidget {
  const EmailLinkScreen({super.key, required this.link, required this.to});

  /// The whole link that opened the app.
  final String link;
  final String? to;

  @override
  ConsumerState<EmailLinkScreen> createState() => _EmailLinkScreenState();
}

class _EmailLinkScreenState extends ConsumerState<EmailLinkScreen> {
  final _email = TextEditingController();
  _Step _step = _Step.working;
  bool _busy = false;
  String? _error;

  String get _returnTo => safeReturnPath(widget.to);

  @override
  void initState() {
    super.initState();
    final auth = ref.read(authServiceProvider);
    if (!auth.isSignInLink(widget.link)) {
      _step = _Step.expired;
      return;
    }
    final stored = ref.read(pendingSignInStoreProvider).email;
    if (stored == null) {
      _step = _Step.confirm;
    } else {
      _email.text = stored;
      WidgetsBinding.instance.addPostFrameCallback((_) => _complete(stored));
    }
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _complete(String email) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final outcome = await ref
        .read(authServiceProvider)
        .completeSignInLink(email: email.trim(), link: widget.link);
    if (!mounted) return;
    final s = context.strings.lightSignIn;
    switch (outcome) {
      case EmailLinkSignedIn():
        await ref.read(pendingSignInStoreProvider).clear();
        if (mounted) context.go(_returnTo);
      case EmailLinkWrongEmail():
        setState(() {
          _step = _Step.confirm;
          _error = s.wrongEmail;
        });
      case EmailLinkExpired():
        setState(() => _step = _Step.expired);
      case EmailLinkFailed(:final message):
        setState(() {
          _step = _Step.confirm;
          _error = message;
        });
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.strings.lightSignIn;
    final cp = context.cp;

    final List<Widget> body = switch (_step) {
      _Step.working => [
        CpLoadingState(
          key: const Key('auth.link.working'),
          semanticLabel: s.signingIn,
          label: s.signingIn,
        ),
      ],
      _Step.confirm => [
        _Heading(title: s.confirmTitle, help: s.confirmHelp),
        CpCard(
          padding: EdgeInsets.all(cp.space.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: cp.space.md,
            children: [
              CpTextField(
                fieldKey: const Key('auth.link.email'),
                label: s.emailLabel,
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                enabled: !_busy,
                error: _error,
                onSubmitted: (v) => _complete(v),
              ),
              CpButton(
                key: const Key('auth.link.continue'),
                label: s.continueLabel,
                busy: _busy,
                expand: true,
                onPressed: _busy ? null : () => _complete(_email.text),
              ),
            ],
          ),
        ),
      ],
      _Step.expired => [
        _Heading(
          key: const Key('auth.link.expired'),
          title: s.expiredTitle,
          help: s.expiredHelp,
          icon: CpIcons.statusDue,
        ),
        LightSignInPanel(
          returnTo: _returnTo,
          initialEmail: _email.text.isEmpty ? null : _email.text,
          emailButtonLabel: s.sendNew,
        ),
      ],
    };

    return Scaffold(
      backgroundColor: cp.colors.background,
      body: SafeArea(
        child: ListView(
          key: const Key('auth.link.body'),
          padding: EdgeInsets.fromLTRB(
            cp.space.lg,
            cp.space.xl,
            cp.space.lg,
            cp.space.xxl,
          ),
          children: [
            ContentMaxWidth(
              maxWidth: cp.sizes.phoneColumn,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: cp.space.lg,
                children: body,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading({
    super.key,
    required this.title,
    required this.help,
    this.icon,
  });

  final String title;
  final String help;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: cp.space.sm,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: cp.space.sm,
          children: [
            if (icon != null)
              Icon(icon, size: cp.sizes.iconMd, color: cp.colors.due),
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  title,
                  style: cp.type.titleLarge.copyWith(color: cp.colors.text),
                ),
              ),
            ),
          ],
        ),
        Text(
          help,
          style: cp.type.bodyMedium.copyWith(color: cp.colors.textMuted),
        ),
      ],
    );
  }
}
