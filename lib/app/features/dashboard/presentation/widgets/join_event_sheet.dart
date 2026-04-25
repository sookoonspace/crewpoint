import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:crewpoint_app/app/core/constants/app_colors.dart';
import 'package:crewpoint_app/app/core/constants/app_radius.dart';
import 'package:crewpoint_app/app/core/constants/app_spacing.dart';
import 'package:crewpoint_app/app/core/widgets/primary_button.dart';

/// Bottom sheet for entering a 6-char join code to join an event.
class JoinEventSheet extends StatefulWidget {
  const JoinEventSheet({super.key});

  static Future<void> show({required BuildContext context}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.xxl),
        ),
      ),
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
    final code = _controller.text.trim().toUpperCase();
    if (code.length != 6) {
      setState(() => _errorMessage = 'Please enter a 6-character code');
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You joined the event!'),
            backgroundColor: AppColors.sage,
          ),
        );
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = switch (e.code) {
            'not-found' => 'This code is invalid or has expired.',
            'already-exists' => "You're already a member of this event.",
            'resource-exhausted' => 'This event is full.',
            _ => 'Something went wrong. Please try again.',
          };
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Network error. Check your connection.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.xl,
        AppSpacing.xl,
        MediaQuery.viewInsetsOf(context).bottom + AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: .min,
        spacing: AppSpacing.lg,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.lightGrey,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          Text(
            'Join Event',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
          ),

          Text(
            'Enter the 6-character code shared by the event organizer',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.mediumGrey),
            textAlign: TextAlign.center,
          ),

          // Code input
          TextField(
            controller: _controller,
            enabled: !_isLoading,
            textAlign: TextAlign.center,
            textCapitalization: TextCapitalization.characters,
            maxLength: 6,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              letterSpacing: 8,
              fontWeight: FontWeight.w700,
            ),
            decoration: InputDecoration(
              counterText: '',
              hintText: '------',
              hintStyle: const TextStyle(
                letterSpacing: 8,
                color: AppColors.lightGrey,
              ),
              filled: true,
              fillColor: AppColors.offWhite,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.lightGrey),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.lightGrey),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.sage, width: 2),
              ),
            ),
          ),

          if (_errorMessage != null)
            Text(
              _errorMessage!,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.terracotta),
              textAlign: TextAlign.center,
            ),

          PrimaryButton(
            label: 'Join Event',
            onPressed: _isLoading ? null : _join,
            isLoading: _isLoading,
          ),
        ],
      ),
    );
  }
}
