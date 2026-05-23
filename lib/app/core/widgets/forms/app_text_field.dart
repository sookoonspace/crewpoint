/// `AppTextField` — the canonical text input for CrewPoint forms.
///
/// Visual identity matches the legacy `CustomTextField` exactly: cream-tinted
/// fill, 12-px rounded border, sage focused border, terracotta error border.
/// Adds additive optional params (`labelText`, `helperText`, `errorText`,
/// `maxLength`, `autofocus`) and a subtle outer sage focus ring on `kIsWeb`
/// when the field is focused — surfaces keyboard navigation on desktop
/// browsers without changing mobile visuals.
///
/// Focus tracking uses `Focus` + a `Builder` reading
/// `Focus.of(context).hasFocus`. The widget stays `StatelessWidget` and owns
/// no `FocusNode` — no `dispose` traps.
///
/// Supersedes: `lib/app/core/widgets/custom_text_field.dart`. The legacy
/// widget remains as a `@Deprecated` thin wrapper so the 29 existing call
/// sites continue to compile unchanged.
library;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:crewpoint_app/app/core/constants/app_colors.dart';
import 'package:crewpoint_app/app/core/constants/app_spacing.dart';

class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.hintText,
    // Legacy `CustomTextField` parameters — preserved exactly so the
    // deprecated wrapper can pass-through without any visual diff.
    this.controller,
    this.obscureText = false,
    this.keyboardType,
    this.onChanged,
    this.validator,
    this.prefixIcon,
    this.suffixIcon,
    this.maxLines = 1,
    this.enabled = true,
    this.label,
    // Additive params introduced by the forms-kit refresh.
    this.labelText,
    this.helperText,
    this.errorText,
    this.maxLength,
    this.autofocus = false,
  });

  final String hintText;
  final TextEditingController? controller;
  final bool obscureText;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final FormFieldValidator<String>? validator;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final int maxLines;
  final bool enabled;
  final String? label;
  final String? labelText;
  final String? helperText;
  final String? errorText;
  final int? maxLength;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return Focus(
      // Observe descendant focus without claiming focus itself.
      canRequestFocus: false,
      skipTraversal: true,
      child: Builder(
        builder: (ctx) {
          final focused = Focus.of(ctx).hasFocus;
          return _buildField(focused);
        },
      ),
    );
  }

  Widget _buildField(bool focused) {
    final showWebRing = kIsWeb && focused;
    return Builder(
      builder: (ctx) {
        final colors = Theme.of(ctx).colorScheme;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: showWebRing
                  ? AppColors.sage.withValues(alpha: 0.45)
                  : Colors.transparent,
              width: 2,
            ),
          ),
          padding: const EdgeInsets.all(2),
          child: TextFormField(
            controller: controller,
            obscureText: obscureText,
            keyboardType: keyboardType,
            onChanged: onChanged,
            validator: validator,
            maxLines: maxLines,
            maxLength: maxLength,
            autofocus: autofocus,
            enabled: enabled,
            style: TextStyle(color: colors.onSurface),
            decoration: InputDecoration(
              labelText: labelText ?? label,
              hintText: hintText,
              helperText: helperText,
              errorText: errorText,
              hintStyle: TextStyle(color: colors.onSurfaceVariant),
              labelStyle: TextStyle(color: colors.onSurfaceVariant),
              prefixIcon: prefixIcon,
              suffixIcon: suffixIcon,
              filled: true,
              fillColor: colors.surfaceContainerHighest,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: colors.outline),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: colors.outline),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: colors.primary, width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: colors.error),
              ),
              errorStyle: TextStyle(color: colors.error),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: colors.outline.withValues(alpha: 0.5),
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
            ),
          ),
        );
      },
    );
  }
}
