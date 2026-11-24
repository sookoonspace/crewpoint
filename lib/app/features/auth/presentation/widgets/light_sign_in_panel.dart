import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crewpoint_app/app/core/design/components/components.dart';
import 'package:crewpoint_app/app/core/design/tokens/cp_icons.dart';
import 'package:crewpoint_app/app/core/design/tokens/tokens.dart';
import 'package:crewpoint_app/app/core/i18n/app_language.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/core/services/i_auth_service.dart';
import 'package:crewpoint_app/app/features/auth/presentation/widgets/social_auth_buttons.dart';
import 'package:crewpoint_app/app/features/participants/domain/models/phone.dart';

/// Light sign-in for registering (Spec #233 Req 12; #241): an email
/// sign-in link, a code texted to a US, Canadian or UK number, or Google or
/// Apple, with no password. Signing in by code, Google or Apple carries on
/// here; the email link opens `/auth/link`, which returns to [returnTo].
class LightSignInPanel extends ConsumerStatefulWidget {
  const LightSignInPanel({
    super.key,
    required this.returnTo,
    this.phoneCountry = PhoneCountry.us,
    this.initialEmail,
    this.emailButtonLabel,
  });

  /// Where the email link brings the person back to.
  final String returnTo;

  /// How a number without a prefix is read, from the event's time zone.
  final PhoneCountry phoneCountry;
  final String? initialEmail;

  /// Replaces "Email me a link", such as "Send a new link".
  final String? emailButtonLabel;

  @override
  ConsumerState<LightSignInPanel> createState() => _LightSignInPanelState();
}

class _LightSignInPanelState extends ConsumerState<LightSignInPanel> {
  late final _email = TextEditingController(text: widget.initialEmail ?? '');
  final _phone = TextEditingController();
  final _code = TextEditingController();

  String? _sentTo;
  bool _sendingLink = false;
  String? _emailError;

  String? _verificationId;
  String? _codeFor;
  bool _sendingCode = false;
  bool _confirming = false;
  String? _phoneError;

  @override
  void dispose() {
    _email.dispose();
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  static final _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  String _failure(Object e, LightSignInStrings s) =>
      e is FirebaseFunctionsException && e.code == 'resource-exhausted'
      ? s.tooMany
      : s.sendFailed;

  Future<void> _sendLink(LightSignInStrings s) async {
    final email = _email.text.trim().toLowerCase();
    if (!_emailPattern.hasMatch(email)) {
      setState(() => _emailError = s.emailInvalid);
      return;
    }
    setState(() {
      _sendingLink = true;
      _emailError = null;
    });
    try {
      await ref
          .read(authServiceProvider)
          .sendSignInLink(
            email: email,
            returnTo: widget.returnTo,
            language: ref.read(appLanguageProvider).code,
          );
      await ref.read(pendingSignInStoreProvider).save(email);
      if (mounted) setState(() => _sentTo = email);
    } catch (e) {
      if (mounted) setState(() => _emailError = _failure(e, s));
    } finally {
      if (mounted) setState(() => _sendingLink = false);
    }
  }

  Future<void> _sendCode(LightSignInStrings s) async {
    final phone = normalisePhone(_phone.text, widget.phoneCountry);
    if (phone == null) {
      setState(() => _phoneError = s.phoneInvalid);
      return;
    }
    // Firebase texts only these, by the project's SMS region policy.
    if (!phone.startsWith('+1') && !phone.startsWith('+44')) {
      setState(() => _phoneError = s.phoneUnsupported);
      return;
    }
    setState(() {
      _sendingCode = true;
      _phoneError = null;
    });
    final outcome = await ref.read(authServiceProvider).sendPhoneCode(phone);
    if (!mounted) return;
    setState(() {
      _sendingCode = false;
      switch (outcome) {
        case PhoneCodeSent(:final verificationId):
          _verificationId = verificationId;
          _codeFor = phone;
        case PhoneSignedIn():
          break;
        case PhoneCodeFailed(:final message):
          _phoneError = message;
      }
    });
  }

  Future<void> _confirm(LightSignInStrings s) async {
    final code = _code.text.trim();
    if (code.isEmpty) {
      setState(() => _phoneError = s.codeMissing);
      return;
    }
    setState(() {
      _confirming = true;
      _phoneError = null;
    });
    final result = await ref
        .read(authServiceProvider)
        .confirmPhoneCode(verificationId: _verificationId!, code: code);
    if (!mounted) return;
    setState(() {
      _confirming = false;
      if (result is AuthResultFailure) _phoneError = result.message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = context.strings.lightSignIn;
    final cp = context.cp;

    Widget card(List<Widget> children) => CpCard(
      padding: EdgeInsets.all(cp.space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: cp.space.md,
        children: children,
      ),
    );

    final email = _sentTo == null
        ? card([
            CpTextField(
              fieldKey: const Key('auth.light.email'),
              label: s.emailLabel,
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendLink(s),
              enabled: !_sendingLink,
              error: _emailError,
            ),
            CpButton(
              key: const Key('auth.light.sendLink'),
              label: widget.emailButtonLabel ?? s.emailButton,
              icon: CpIcons.authEmail,
              busy: _sendingLink,
              expand: true,
              onPressed: _sendingLink ? null : () => _sendLink(s),
            ),
          ])
        : card([
            Row(
              spacing: cp.space.sm,
              children: [
                Icon(
                  CpIcons.statusDone,
                  size: cp.sizes.iconMd,
                  color: cp.colors.accent,
                ),
                Expanded(
                  child: Text(
                    s.sentTitle,
                    key: const Key('auth.light.sent'),
                    style: cp.type.titleMedium.copyWith(color: cp.colors.text),
                  ),
                ),
              ],
            ),
            Text(
              s.sentBody(_sentTo!),
              style: cp.type.bodyMedium.copyWith(color: cp.colors.text),
            ),
            if (_emailError != null) CpFieldError(_emailError!),
            Wrap(
              spacing: cp.space.sm,
              runSpacing: cp.space.sm,
              children: [
                CpButton.secondary(
                  key: const Key('auth.light.resend'),
                  label: s.resend,
                  busy: _sendingLink,
                  onPressed: _sendingLink ? null : () => _sendLink(s),
                ),
                CpButton.text(
                  key: const Key('auth.light.otherEmail'),
                  label: s.differentEmail,
                  onPressed: () => setState(() => _sentTo = null),
                ),
              ],
            ),
          ]);

    final phone = _verificationId == null
        ? card([
            CpTextField(
              fieldKey: const Key('auth.light.phone'),
              label: s.phoneLabel,
              help: s.phoneHelp,
              controller: _phone,
              keyboardType: TextInputType.phone,
              enabled: !_sendingCode,
              error: _phoneError,
            ),
            CpButton.secondary(
              key: const Key('auth.light.sendCode'),
              label: s.phoneButton,
              icon: CpIcons.authPhone,
              busy: _sendingCode,
              expand: true,
              onPressed: _sendingCode ? null : () => _sendCode(s),
            ),
          ])
        : card([
            CpTextField(
              fieldKey: const Key('auth.light.code'),
              label: s.codeLabel,
              help: s.codeHelp(_codeFor!),
              controller: _code,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              autofocus: true,
              enabled: !_confirming,
              error: _phoneError,
            ),
            CpButton(
              key: const Key('auth.light.confirmCode'),
              label: s.codeButton,
              busy: _confirming,
              expand: true,
              onPressed: _confirming ? null : () => _confirm(s),
            ),
            CpButton.text(
              key: const Key('auth.light.otherPhone'),
              label: s.changePhone,
              onPressed: () => setState(() {
                _verificationId = null;
                _code.clear();
                _phoneError = null;
              }),
            ),
          ]);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: cp.space.lg,
      children: [
        email,
        phone,
        _Or(label: s.or),
        const SocialAuthButtons(),
      ],
    );
  }
}

class _Or extends StatelessWidget {
  const _Or({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    final line = Expanded(
      child: Divider(color: cp.colors.border, height: cp.sizes.hairline),
    );
    return Row(
      spacing: cp.space.md,
      children: [
        line,
        Text(
          label,
          style: cp.type.bodySmall.copyWith(color: cp.colors.textMuted),
        ),
        line,
      ],
    );
  }
}
