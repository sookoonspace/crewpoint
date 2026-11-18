import 'dart:ui' show Tristate;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crewpoint_app/app/core/design/components/components.dart';
import 'package:crewpoint_app/app/core/design/theme/cp_theme.dart';
import 'package:crewpoint_app/app/core/design/tokens/cp_colors.dart';
import 'package:crewpoint_app/app/core/design/tokens/cp_icons.dart';

import '_pump.dart';

/// Records haptic and sound calls sent to the platform.
List<String> _recordPlatformFeedback(WidgetTester tester) {
  final calls = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'HapticFeedback.vibrate' ||
          call.method == 'SystemSound.play') {
        calls.add('${call.method}:${call.arguments}');
      }
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
  return calls;
}

Future<void> _pumpOn(
  WidgetTester tester,
  TargetPlatform platform,
  Widget child,
) {
  return tester.pumpWidget(
    MaterialApp(
      theme: CpTheme.light().copyWith(platform: platform),
      home: Scaffold(body: Center(child: child)),
    ),
  );
}

void main() {
  group('CpButton', () {
    testWidgets('runs its action when tapped', (tester) async {
      var taps = 0;
      await pumpCp(
        tester,
        CpButton(
          key: const Key('test.save'),
          label: 'Save',
          onPressed: () => taps++,
        ),
      );
      await tester.tap(find.byKey(const Key('test.save')));
      expect(taps, 1);
      expect(
        tester.getSemantics(find.bySemanticsLabel('Save')),
        matchesSemantics(
          label: 'Save',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
    });

    testWidgets('while busy shows a spinner and ignores taps', (tester) async {
      var taps = 0;
      await pumpCp(
        tester,
        CpButton(
          key: const Key('test.save'),
          label: 'Save',
          busy: true,
          onPressed: () => taps++,
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.byKey(const Key('test.save')), warnIfMissed: false);
      expect(taps, 0);
      expect(
        tester.getSemantics(find.bySemanticsLabel('Save')),
        matchesSemantics(label: 'Save', isButton: true, hasEnabledState: true),
      );
    });

    testWidgets('without an action it is disabled', (tester) async {
      await pumpCp(tester, const CpButton(label: 'Save', onPressed: null));
      expect(
        tester.getSemantics(find.bySemanticsLabel('Save')),
        matchesSemantics(label: 'Save', isButton: true, hasEnabledState: true),
      );
    });

    for (final (name, button, bg, fg) in [
      (
        'primary',
        CpButton(label: 'Go', onPressed: () {}),
        CpColors.light.accent,
        CpColors.light.onAccent,
      ),
      (
        'secondary',
        CpButton.secondary(label: 'Go', onPressed: () {}),
        CpColors.light.surface,
        CpColors.light.accent,
      ),
      (
        'destructive',
        CpButton.destructive(label: 'Go', onPressed: () {}),
        CpColors.light.overdue,
        CpColors.light.surface,
      ),
    ]) {
      testWidgets('$name uses its colours', (tester) async {
        await pumpCp(tester, button);
        final style = tester.widget<TextButton>(find.byType(TextButton)).style!;
        expect(style.backgroundColor!.resolve({}), bg);
        expect(style.foregroundColor!.resolve({}), fg);
      });
    }

    testWidgets('a text button has no fill', (tester) async {
      await pumpCp(tester, CpButton.text(label: 'Cancel', onPressed: () {}));
      final style = tester.widget<TextButton>(find.byType(TextButton)).style!;
      expect(style.backgroundColor!.resolve({}), Colors.transparent);
    });
  });

  group('CpTextField', () {
    testWidgets('shows label, required star and help', (tester) async {
      await pumpCp(
        tester,
        const CpTextField(
          label: 'Name',
          required: true,
          requiredLabel: 'required',
          help: 'As it should appear on a badge',
        ),
      );
      expect(find.textContaining('Name'), findsWidgets);
      expect(find.textContaining('*', findRichText: true), findsOneWidget);
      expect(find.text('As it should appear on a badge'), findsOneWidget);
      expect(find.bySemanticsLabel('Name, required'), findsOneWidget);
    });

    testWidgets('an error replaces the help, with an icon', (tester) async {
      await pumpCp(
        tester,
        const CpTextField(
          label: 'Email',
          help: 'Links their account later',
          error: 'Enter a valid email.',
        ),
      );
      expect(find.text('Enter a valid email.'), findsOneWidget);
      expect(find.text('Links their account later'), findsNothing);
      expect(find.byIcon(CpIcons.statusError), findsOneWidget);
    });

    testWidgets('typing reaches onChanged; a validator shows its error', (
      tester,
    ) async {
      final formKey = GlobalKey<FormState>();
      final typed = <String>[];
      await pumpCp(
        tester,
        Form(
          key: formKey,
          child: CpTextField(
            label: 'Name',
            fieldKey: const Key('test.name'),
            onChanged: typed.add,
            validator: (v) => (v ?? '').trim().isEmpty ? 'Enter a name.' : null,
          ),
        ),
      );
      await tester.enterText(find.byKey(const Key('test.name')), 'Asha');
      expect(typed, ['Asha']);
      await tester.enterText(find.byKey(const Key('test.name')), ' ');
      expect(formKey.currentState!.validate(), isFalse);
      await tester.pump();
      expect(find.text('Enter a name.'), findsOneWidget);
      expect(find.byType(CpFieldError), findsOneWidget);
    });
  });

  group('CpSelectField', () {
    testWidgets('opens its picker and reads label and value', (tester) async {
      var opened = 0;
      await pumpCp(
        tester,
        CpSelectField(
          key: const Key('test.group'),
          label: 'Group',
          value: 'Mehta',
          onTap: () => opened++,
        ),
      );
      await tester.tap(find.byKey(const Key('test.group')));
      expect(opened, 1);
      expect(find.bySemanticsLabel('Group, Mehta'), findsOneWidget);
    });

    testWidgets('shows a muted placeholder with no value', (tester) async {
      await pumpCp(
        tester,
        CpSelectField(label: 'Group', placeholder: 'No group', onTap: () {}),
      );
      final text = tester.widget<Text>(find.text('No group'));
      expect(text.style?.color, CpColors.light.textMuted);
    });
  });

  group('CpDateField', () {
    Widget field({
      required ValueChanged<DateTime?> onChanged,
      DateTime? value,
    }) => CpDateField(
      key: const Key('test.date'),
      label: 'Birth date',
      value: value,
      onChanged: onChanged,
      format: (d) => '${d.year}-${d.month}-${d.day}',
      firstDate: DateTime(1900),
      lastDate: DateTime(2030),
      placeholder: 'Not set',
      clearLabel: 'Clear birth date',
    );

    testWidgets('opens the calendar picker on Android', (tester) async {
      DateTime? picked;
      await _pumpOn(
        tester,
        TargetPlatform.android,
        field(value: DateTime(2018, 3, 14), onChanged: (d) => picked = d),
      );
      await tester.tap(find.byIcon(CpIcons.calendar));
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(picked, DateTime(2018, 3, 14));
    });

    testWidgets('opens the wheel picker on iOS', (tester) async {
      DateTime? picked;
      await _pumpOn(
        tester,
        TargetPlatform.iOS,
        field(value: DateTime(2018, 3, 14), onChanged: (d) => picked = d),
      );
      await tester.tap(find.byIcon(CpIcons.calendar));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoDatePicker), findsOneWidget);
      expect(find.byType(DatePickerDialog), findsNothing);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(picked, DateTime(2018, 3, 14));
    });

    testWidgets('shows the formatted date and clears it', (tester) async {
      final changes = <DateTime?>[];
      await pumpCp(
        tester,
        field(value: DateTime(2018, 3, 14), onChanged: changes.add),
      );
      expect(find.text('2018-3-14'), findsOneWidget);
      await tester.tap(find.byTooltip('Clear birth date'));
      expect(changes, [null]);
    });
  });

  group('CpSwitchRow', () {
    testWidgets('the whole row toggles, and reads as one switch', (
      tester,
    ) async {
      final values = <bool>[];
      await pumpCp(
        tester,
        CpSwitchRow(
          title: 'Child',
          help: 'Children have no account.',
          value: false,
          switchKey: const Key('test.child'),
          onChanged: values.add,
        ),
      );
      await tester.tap(find.text('Child'));
      await tester.tap(find.byKey(const Key('test.child')));
      expect(values, [true, true]);
      final node = tester.getSemantics(find.byKey(const Key('test.child')));
      expect(node.label, contains('Child'));
      expect(node.label, contains('Children have no account.'));
    });
  });

  group('CpChoiceChips', () {
    const choices = [
      CpChoice('veg', 'Veg', key: Key('test.diet.veg')),
      CpChoice('jain', 'Jain', key: Key('test.diet.jain')),
      CpChoice('nonVeg', 'Non-veg', key: Key('test.diet.nonVeg')),
    ];

    Future<List<Set<String>>> pumpChips(
      WidgetTester tester, {
      required Set<String> selected,
      bool multiple = false,
      bool required = false,
      String? error,
    }) async {
      final changes = <Set<String>>[];
      await pumpCp(
        tester,
        CpChoiceChips<String>(
          label: 'Diet',
          choices: choices,
          selected: selected,
          multiple: multiple,
          required: required,
          error: error,
          onChanged: changes.add,
        ),
      );
      return changes;
    }

    testWidgets('one choice replaces another', (tester) async {
      final changes = await pumpChips(tester, selected: {'veg'});
      await tester.tap(find.byKey(const Key('test.diet.jain')));
      expect(changes.single, {'jain'});
    });

    testWidgets('tapping the chosen answer clears it unless required', (
      tester,
    ) async {
      var changes = await pumpChips(tester, selected: {'veg'});
      await tester.tap(find.byKey(const Key('test.diet.veg')));
      expect(changes.single, <String>{});

      changes = await pumpChips(tester, selected: {'veg'}, required: true);
      await tester.tap(find.byKey(const Key('test.diet.veg')));
      expect(changes.single, {'veg'});
    });

    testWidgets('several choices toggle independently', (tester) async {
      final changes = await pumpChips(
        tester,
        selected: {'veg'},
        multiple: true,
      );
      await tester.tap(find.byKey(const Key('test.diet.jain')));
      expect(changes.single, {'veg', 'jain'});
    });

    testWidgets('reads each choice with its selected state', (tester) async {
      await pumpChips(tester, selected: {'veg'});
      final veg = tester.getSemantics(find.byKey(const Key('test.diet.veg')));
      expect(veg.label, 'Veg');
      expect(veg.flagsCollection.isSelected, Tristate.isTrue);
      expect(veg.flagsCollection.isInMutuallyExclusiveGroup, isTrue);
      final jain = tester.getSemantics(find.byKey(const Key('test.diet.jain')));
      expect(jain.flagsCollection.isSelected, Tristate.isFalse);
      expect(find.byIcon(CpIcons.check), findsOneWidget);
    });

    testWidgets('shows a missing answer', (tester) async {
      await pumpChips(tester, selected: {}, error: 'Choose an answer.');
      expect(find.text('Choose an answer.'), findsOneWidget);
    });

    testWidgets('gives an iOS selection tick when a choice changes', (
      tester,
    ) async {
      final calls = _recordPlatformFeedback(tester);
      await _pumpOn(
        tester,
        TargetPlatform.iOS,
        CpChoiceChips<String>(
          label: 'Diet',
          choices: choices,
          selected: const {},
          onChanged: (_) {},
        ),
      );
      await tester.tap(find.byKey(const Key('test.diet.veg')));
      expect(
        calls,
        contains('HapticFeedback.vibrate:HapticFeedbackType.selectionClick'),
      );
    });

    testWidgets("uses Android's own tap feedback on Android", (tester) async {
      final calls = _recordPlatformFeedback(tester);
      await _pumpOn(
        tester,
        TargetPlatform.android,
        CpChoiceChips<String>(
          label: 'Diet',
          choices: choices,
          selected: const {},
          onChanged: (_) {},
        ),
      );
      await tester.tap(find.byKey(const Key('test.diet.veg')));
      expect(calls.where((c) => c.startsWith('HapticFeedback')), isEmpty);
      expect(calls, contains('SystemSound.play:SystemSoundType.click'));
    });
  });

  group('CpSegmented', () {
    testWidgets('picks one option and reads it as selected', (tester) async {
      final picked = <String>[];
      await pumpCp(
        tester,
        CpSegmented<String>(
          semanticLabel: 'Adult or child',
          choices: const [
            CpChoice('adult', 'Adult', key: Key('test.adult')),
            CpChoice('child', 'Child', key: Key('test.child')),
          ],
          selected: 'adult',
          onChanged: picked.add,
        ),
      );
      await tester.tap(find.byKey(const Key('test.child')));
      await tester.tap(find.byKey(const Key('test.adult')));
      expect(picked, ['child']);
      expect(
        tester
            .getSemantics(find.byKey(const Key('test.adult')))
            .flagsCollection
            .isSelected,
        Tristate.isTrue,
      );
    });
  });

  group('sheet and dialog', () {
    testWidgets('a sheet shows its title and content', (tester) async {
      await pumpCp(
        tester,
        Builder(
          builder: (context) => CpButton(
            key: const Key('test.open'),
            label: 'Open',
            onPressed: () => showCpSheet<void>(
              context: context,
              title: 'Choose a group',
              builder: (_) => const Text('Sheet body'),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('test.open')));
      await tester.pumpAndSettle();
      expect(find.text('Choose a group'), findsOneWidget);
      expect(find.text('Sheet body'), findsOneWidget);
      expect(
        tester.getSemantics(find.text('Choose a group')),
        matchesSemantics(label: 'Choose a group', isHeader: true),
      );
    });

    testWidgets('a dialog shows its message and actions', (tester) async {
      await pumpCp(
        tester,
        CpDialog(
          title: 'Remove Asha?',
          message: 'This cannot be undone.',
          actions: [
            CpButton.text(label: 'Cancel', onPressed: () {}),
            CpButton.destructive(label: 'Remove', onPressed: () {}),
          ],
        ),
      );
      expect(find.text('Remove Asha?'), findsOneWidget);
      expect(find.text('This cannot be undone.'), findsOneWidget);
      expect(find.text('Remove'), findsOneWidget);
    });
  });

  group('showCpTextPrompt', () {
    Future<Future<String?>> pumpAndOpen(
      WidgetTester tester, {
      FormFieldValidator<String>? validator,
    }) async {
      late Future<String?> result;
      await pumpCp(
        tester,
        Builder(
          builder: (context) => CpButton(
            key: const Key('test.open'),
            label: 'Open',
            onPressed: () => result = showCpTextPrompt(
              context: context,
              title: 'New group',
              label: 'Group name',
              confirmLabel: 'Create',
              cancelLabel: 'Cancel',
              validator: validator,
              fieldKey: const Key('test.prompt.field'),
              confirmKey: const Key('test.prompt.confirm'),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('test.open')));
      await tester.pumpAndSettle();
      return result;
    }

    testWidgets('returns the trimmed text', (tester) async {
      final result = await pumpAndOpen(tester);
      await tester.enterText(
        find.byKey(const Key('test.prompt.field')),
        '  Mehta  ',
      );
      await tester.tap(find.byKey(const Key('test.prompt.confirm')));
      await tester.pumpAndSettle();
      expect(await result, 'Mehta');
    });

    testWidgets('a failing validator keeps the dialog open', (tester) async {
      await pumpAndOpen(
        tester,
        validator: (v) => (v ?? '').trim().isEmpty ? 'Enter a name.' : null,
      );
      await tester.tap(find.byKey(const Key('test.prompt.confirm')));
      await tester.pumpAndSettle();
      expect(find.text('Enter a name.'), findsOneWidget);
      expect(find.byType(CpTextPrompt), findsOneWidget);
    });

    testWidgets('cancel returns nothing', (tester) async {
      final result = await pumpAndOpen(tester);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(await result, isNull);
    });

    testWidgets(
      'keeps its controller alive while it rebuilds during closing (#185)',
      (tester) async {
        final result = await pumpAndOpen(tester);
        await tester.enterText(
          find.byKey(const Key('test.prompt.field')),
          'Mehta',
        );
        // Keyboard up, then confirm, then the keyboard closes mid-exit,
        // which rebuilds the closing dialog.
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        addTearDown(tester.view.resetViewInsets);
        await tester.pump();
        await tester.tap(find.byKey(const Key('test.prompt.confirm')));
        await tester.pump();
        expect(await result, 'Mehta');
        for (var i = 0; i < 6; i++) {
          tester.view.viewInsets = FakeViewPadding(bottom: 250.0 - i * 50);
          await tester.pump(const Duration(milliseconds: 30));
        }
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(CpTextPrompt), findsNothing);
      },
    );
  });

  testWidgets('form components lay out at 200% text without overflow', (
    tester,
  ) async {
    await pumpCp(
      tester,
      textScale: 2,
      Column(
        children: [
          CpButton(label: 'Save', onPressed: () {}, expand: true),
          const CpTextField(label: 'Name', required: true, help: 'Help'),
          CpSelectField(label: 'Group', value: 'Mehta', onTap: () {}),
          CpChoiceChips<int>(
            label: 'T-shirt size',
            choices: const [
              CpChoice(1, 'Small'),
              CpChoice(2, 'Medium'),
              CpChoice(3, 'Large'),
            ],
            selected: const {2},
            onChanged: (_) {},
          ),
          CpSegmented<int>(
            choices: const [CpChoice(1, 'Adult'), CpChoice(2, 'Child')],
            selected: 1,
            onChanged: (_) {},
          ),
          CpSwitchRow(title: 'Child', value: true, onChanged: (_) {}),
        ],
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
