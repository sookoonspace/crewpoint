import 'package:flutter/material.dart';

import 'package:crewpoint_app/app/core/design/tokens/cp_colors.dart';
import 'package:crewpoint_app/app/core/design/tokens/cp_scales.dart';
import 'package:crewpoint_app/app/core/design/tokens/cp_type.dart';
import 'package:crewpoint_app/app/core/design/tokens/tokens.dart';

/// CrewPoint's light and dark themes, built only from the tokens (Spec #186
/// Req 13, Technical Decision 1). Light and dark run the same code with
/// different token values.
///
/// The look is CrewPoint's own on every platform; platform behaviours
/// (back swipe, date pickers, haptics, scrolling physics) stay native
/// because [ThemeData.platform] and the page transitions are left at their
/// defaults (Req 21).
abstract final class CpTheme {
  static ThemeData light() => _build(Brightness.light, CpColors.light);

  static ThemeData dark() => _build(Brightness.dark, CpColors.dark);

  static ThemeData _build(Brightness brightness, CpColors c) {
    const type = CpType.standard;
    const space = CpSpacing();
    const radii = CpRadii();
    const sizes = CpSizes();
    final textTheme = type.textTheme(c.text);
    final scheme = ColorScheme(
      brightness: brightness,
      primary: c.accent,
      onPrimary: c.onAccent,
      primaryContainer: c.accentSoft,
      onPrimaryContainer: c.text,
      secondary: c.accent,
      onSecondary: c.onAccent,
      secondaryContainer: c.accentSoft,
      onSecondaryContainer: c.text,
      tertiary: c.due,
      onTertiary: c.surface,
      tertiaryContainer: c.dueSoft,
      onTertiaryContainer: c.due,
      error: c.overdue,
      onError: c.surface,
      errorContainer: c.overdueSoft,
      onErrorContainer: c.overdue,
      surface: c.surface,
      onSurface: c.text,
      onSurfaceVariant: c.textMuted,
      surfaceContainerLowest: c.surface,
      surfaceContainerLow: c.surface,
      surfaceContainer: c.surface,
      surfaceContainerHigh: c.fill,
      surfaceContainerHighest: c.fill,
      outline: c.border,
      outlineVariant: c.border,
      shadow: Colors.transparent,
      scrim: c.text.withValues(alpha: 0.4),
      inverseSurface: c.text,
      onInverseSurface: c.surface,
      inversePrimary: c.accentSoft,
      surfaceTint: Colors.transparent,
    );
    final buttonShape = RoundedRectangleBorder(borderRadius: radii.md);
    final buttonSize = Size(sizes.tapMin, sizes.tapMin);
    final buttonPadding = EdgeInsets.symmetric(horizontal: space.lg + 2);
    final fieldBorder = OutlineInputBorder(
      borderRadius: radii.sm,
      borderSide: BorderSide(color: c.border),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: CpType.textFont,
      fontFamilyFallback: CpType.scriptFallback,
      textTheme: textTheme,
      extensions: cpExtensions(brightness),
      scaffoldBackgroundColor: c.background,
      canvasColor: c.background,
      dividerColor: c.border,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: c.background,
        foregroundColor: c.text,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: c.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: radii.md,
          side: BorderSide(color: c.border),
        ),
      ),
      dividerTheme: DividerThemeData(color: c.border, thickness: 1, space: 1),
      listTileTheme: ListTileThemeData(
        iconColor: c.textMuted,
        textColor: c.text,
        titleTextStyle: textTheme.titleMedium,
        subtitleTextStyle: textTheme.bodySmall?.copyWith(color: c.textMuted),
        contentPadding: EdgeInsets.symmetric(horizontal: space.lg),
        minVerticalPadding: space.md,
      ),
      iconTheme: IconThemeData(color: c.text, size: sizes.iconLg),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: c.accent,
          foregroundColor: c.onAccent,
          disabledBackgroundColor: c.fill,
          disabledForegroundColor: c.textMuted,
          elevation: 0,
          minimumSize: Size.fromHeight(sizes.tapMin),
          padding: buttonPadding,
          shape: buttonShape,
          textStyle: textTheme.labelLarge,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.accent,
          foregroundColor: c.onAccent,
          disabledBackgroundColor: c.fill,
          disabledForegroundColor: c.textMuted,
          minimumSize: buttonSize,
          padding: buttonPadding,
          shape: buttonShape,
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.accent,
          backgroundColor: c.surface,
          side: BorderSide(color: c.border),
          minimumSize: buttonSize,
          padding: buttonPadding,
          shape: buttonShape,
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.accent,
          minimumSize: buttonSize,
          shape: buttonShape,
          textStyle: textTheme.labelLarge,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: c.text,
          minimumSize: buttonSize,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: c.accent,
        foregroundColor: c.onAccent,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        shape: RoundedRectangleBorder(borderRadius: radii.lg),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surface,
        border: fieldBorder,
        enabledBorder: fieldBorder,
        disabledBorder: fieldBorder,
        focusedBorder: fieldBorder.copyWith(
          borderSide: BorderSide(color: c.accent, width: 2),
        ),
        errorBorder: fieldBorder.copyWith(
          borderSide: BorderSide(color: c.overdue, width: 2),
        ),
        focusedErrorBorder: fieldBorder.copyWith(
          borderSide: BorderSide(color: c.overdue, width: 2),
        ),
        labelStyle: textTheme.bodyMedium?.copyWith(color: c.textMuted),
        hintStyle: textTheme.bodyMedium?.copyWith(color: c.textMuted),
        helperStyle: textTheme.bodySmall?.copyWith(color: c.textMuted),
        errorStyle: textTheme.bodySmall?.copyWith(
          color: c.overdue,
          fontWeight: FontWeight.w600,
        ),
        prefixIconColor: c.textMuted,
        suffixIconColor: c.textMuted,
        contentPadding: EdgeInsets.symmetric(
          horizontal: space.md,
          vertical: space.md + 2,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: c.surface,
        selectedColor: c.accent,
        disabledColor: c.fill,
        checkmarkColor: c.onAccent,
        labelStyle: textTheme.labelMedium?.copyWith(color: c.text),
        secondaryLabelStyle: textTheme.labelMedium?.copyWith(color: c.onAccent),
        side: BorderSide(color: c.border),
        shape: RoundedRectangleBorder(borderRadius: radii.pill),
        padding: EdgeInsets.symmetric(horizontal: space.sm),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? c.accent : null,
        ),
        checkColor: WidgetStateProperty.all(c.onAccent),
        side: BorderSide(color: c.textMuted, width: 2),
        shape: RoundedRectangleBorder(borderRadius: radii.xs),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? c.accent : c.textMuted,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? c.onAccent : c.surface,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? c.accent : c.border,
        ),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.accent,
        linearTrackColor: c.border,
        circularTrackColor: c.border,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.surface,
        indicatorColor: c.accentSoft,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? c.accent
                : c.textMuted,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: states.contains(WidgetState.selected)
                ? c.accent
                : c.textMuted,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: c.surface,
        indicatorColor: c.accentSoft,
        selectedIconTheme: IconThemeData(color: c.accent),
        unselectedIconTheme: IconThemeData(color: c.textMuted),
        selectedLabelTextStyle: textTheme.labelMedium?.copyWith(
          color: c.accent,
        ),
        unselectedLabelTextStyle: textTheme.labelMedium?.copyWith(
          color: c.textMuted,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        modalBackgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: c.border,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: radii.lg.topLeft),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: radii.lg),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: c.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: radii.md,
          side: BorderSide(color: c.border),
        ),
        textStyle: textTheme.bodyMedium,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.text,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: c.surface),
        actionTextColor: c.accentSoft,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: radii.md),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: c.accent,
        unselectedLabelColor: c.textMuted,
        indicatorColor: c.accent,
        dividerColor: c.border,
        labelStyle: textTheme.labelLarge,
        unselectedLabelStyle: textTheme.labelLarge,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          backgroundColor: c.fill,
          foregroundColor: c.textMuted,
          selectedBackgroundColor: c.surface,
          selectedForegroundColor: c.text,
          side: BorderSide(color: c.border),
          textStyle: textTheme.labelLarge,
        ),
      ),
    );
  }
}
