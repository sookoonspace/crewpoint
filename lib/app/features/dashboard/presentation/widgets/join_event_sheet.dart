import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import 'package:crewpoint_app/app/core/design/components/components.dart';
import 'package:crewpoint_app/app/core/design/tokens/tokens.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';

/// Bottom sheet for entering a 6-char join code to join an event.
class JoinEventSheet extends StatefulWidget {
  const JoinEventSheet({super.key});

  static Future<void> show({required BuildContext context}) {
    return showCpSheet<void>(
      context: context,
      title: context.strings.dashboard.joinSheetTitle,
      builder: (_) => const JoinEventSheet(),
    );
  }

  @override
  State<JoinEventSheet> createState() => _JoinEventSheetState();
}

class _JoinEventSheetState extends State<JoinEventSheet> {
  final _controller = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final strings = context.strings.dashboard;
    final code = _controller.text.trim().toUpperCase();
    if (code.length != 6) {
      setState(() => _errorMessage = strings.joinCodeLength);
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final callable = FirebaseFunctions.instance.httpsCallable('joinEvent');
      await callable.call<Map<String, dynamic>>({'joinCode': code});

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(strings.joined)));
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = switch (e.code) {
            'not-found' => strings.joinCodeInvalid,
            'already-exists' => strings.joinAlreadyMember,
            'resource-exhausted' => strings.joinFull,
            'failed-precondition' => strings.notOpenToJoin,
            _ => strings.joinFailed,
          };
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = strings.joinOffline;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    final strings = context.strings.dashboard;
    return Column(
      mainAxisSize: .min,
      crossAxisAlignment: .stretch,
      spacing: cp.space.lg,
      children: [
        Text(
          strings.joinSheetHelp,
          style: cp.type.bodyMedium.copyWith(color: cp.colors.textMuted),
        ),

        // Code input: the theme's field look, with the code spaced out.
        Semantics(
          label: strings.joinCodeLabel,
          child: TextField(
            key: const Key('dashboard.join.code'),
            controller: _controller,
            enabled: !_isLoading,
            textAlign: TextAlign.center,
            textCapitalization: TextCapitalization.characters,
            maxLength: 6,
            style: cp.type.headlineMedium.copyWith(
              letterSpacing: cp.space.sm,
              color: cp.colors.text,
            ),
            decoration: InputDecoration(
              counterText: '',
              hintText: '------',
              hintStyle: cp.type.headlineMedium.copyWith(
                letterSpacing: cp.space.sm,
                color: cp.colors.textMuted,
              ),
            ),
            onSubmitted: (_) => _join(),
          ),
        ),

        if (_errorMessage != null)
          KeyedSubtree(
            key: const Key('dashboard.join.error'),
            child: CpFieldError(_errorMessage!),
          ),

        CpButton(
          key: const Key('dashboard.join.submit'),
          label: strings.joinSheetTitle,
          expand: true,
          busy: _isLoading,
          onPressed: _isLoading ? null : _join,
        ),
      ],
    );
  }
}
