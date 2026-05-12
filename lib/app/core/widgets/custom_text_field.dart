import 'package:flutter/material.dart';
import 'package:crewpoint_app/app/core/widgets/forms/app_text_field.dart';

/// Deprecated: use [AppTextField] from
/// `lib/app/core/widgets/forms/app_text_field.dart` directly.
///
/// `CustomTextField` is kept as a thin wrapper so the 29 pre-existing
/// call sites continue to compile without modification. New screens
/// should reach for `AppTextField` and the rest of the forms kit.
@Deprecated(
  'Use AppTextField from lib/app/core/widgets/forms/app_text_field.dart',
)
class CustomTextField extends StatelessWidget {
  const CustomTextField({
    super.key,
    required this.hintText,
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

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      hintText: hintText,
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      onChanged: onChanged,
      validator: validator,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      maxLines: maxLines,
      enabled: enabled,
      label: label,
    );
  }
}
