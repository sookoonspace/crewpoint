/// Locks the strike-through colour contract on completed checklist
/// items — they must paint at `colorScheme.onSurfaceVariant` in both
/// themes so the strike-through reads as "done but still legible"
/// against the screen surface (2026-06-11 task detail dark-mode pass).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/theme/app_theme.dart';
import 'package:crewpoint_app/app/features/tasks/domain/models/task.dart';
import 'package:crewpoint_app/app/features/tasks/presentation/widgets/checklist_editor.dart';

Future<Text> _pumpAndFindRowText(
  WidgetTester tester, {
  required ThemeData theme,
  required ChecklistItem item,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: Scaffold(
        body: ChecklistEditor(items: [item], onToggle: (_, _) {}),
      ),
    ),
  );
  return tester.widget<Text>(find.text(item.text));
}

void main() {
  testWidgets(
    'completed checklist item paints colorScheme.onSurfaceVariant with '
    'TextDecoration.lineThrough (dark theme)',
    (tester) async {
      final theme = AppTheme.dark();
      const completed = ChecklistItem(
        id: 'c-1',
        text: 'Beers',
        isCompleted: true,
      );
      final text = await _pumpAndFindRowText(
        tester,
        theme: theme,
        item: completed,
      );
      expect(text.style!.color, theme.colorScheme.onSurfaceVariant);
      expect(text.style!.decoration, TextDecoration.lineThrough);
    },
  );

  testWidgets(
    'completed checklist item paints colorScheme.onSurfaceVariant with '
    'TextDecoration.lineThrough (light theme)',
    (tester) async {
      final theme = AppTheme.light();
      const completed = ChecklistItem(
        id: 'c-1',
        text: 'Beers',
        isCompleted: true,
      );
      final text = await _pumpAndFindRowText(
        tester,
        theme: theme,
        item: completed,
      );
      expect(text.style!.color, theme.colorScheme.onSurfaceVariant);
      expect(text.style!.decoration, TextDecoration.lineThrough);
    },
  );

  testWidgets('unchecked checklist item paints colorScheme.onSurface, no '
      'strike-through (dark theme)', (tester) async {
    final theme = AppTheme.dark();
    const pending = ChecklistItem(id: 'c-2', text: 'Water');
    final text = await _pumpAndFindRowText(tester, theme: theme, item: pending);
    expect(text.style!.color, theme.colorScheme.onSurface);
    expect(text.style!.decoration, isNull);
  });

  testWidgets('unchecked checklist item paints colorScheme.onSurface, no '
      'strike-through (light theme)', (tester) async {
    final theme = AppTheme.light();
    const pending = ChecklistItem(id: 'c-2', text: 'Water');
    final text = await _pumpAndFindRowText(tester, theme: theme, item: pending);
    expect(text.style!.color, theme.colorScheme.onSurface);
    expect(text.style!.decoration, isNull);
  });
}
