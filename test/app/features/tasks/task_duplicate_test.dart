import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/features/tasks/domain/models/task.dart';

void main() {
  group('TaskModel.duplicate', () {
    final base = TaskModel(
      id: 'orig-1',
      eventId: 'evt-1',
      title: 'Buy snacks',
      description: 'Chips + soda',
      assigneeId: 'user-2',
      createdBy: 'owner-1',
      status: TaskStatus.done,
      priority: 2,
      dueDate: DateTime(2026, 7, 1),
      budgetEstimate: 25,
      completedAt: DateTime(2026, 6, 30),
      completedBy: 'user-2',
    );

    final checklist = [
      const ChecklistItem(id: 'i1', text: 'Apple', isCompleted: true),
      const ChecklistItem(id: 'i2', text: 'Banana'),
    ];

    test('fresh id + status reset to todo + completion cleared', () {
      final dup = base.duplicate(currentUserId: 'me', checklist: checklist);
      expect(dup.id, isNot(base.id));
      expect(dup.id, isNotEmpty);
      expect(dup.status, TaskStatus.todo);
      expect(dup.completedAt, isNull);
      expect(dup.completedBy, isNull);
      expect(dup.createdBy, 'me');
    });

    test(
      'preserves eventId, description, assigneeId, dueDate, priority, budget',
      () {
        final dup = base.duplicate(currentUserId: 'me', checklist: checklist);
        expect(dup.eventId, base.eventId);
        expect(dup.description, base.description);
        expect(dup.assigneeId, base.assigneeId);
        expect(dup.dueDate, base.dueDate);
        expect(dup.priority, base.priority);
        expect(dup.budgetEstimate, base.budgetEstimate);
      },
    );

    test('appends " (copy)" suffix to title', () {
      final dup = base.duplicate(currentUserId: 'me', checklist: checklist);
      expect(dup.title, 'Buy snacks (copy)');
    });

    test(
      'grapheme-aware truncation keeps result ≤120 chars + no half-emoji',
      () {
        // Build a 119-char title ending in a multi-codepoint emoji to make
        // sure code-unit substring would split it but grapheme substring
        // won't.
        const emoji = '🚀'; // 2 UTF-16 code units, one grapheme.
        final long = 'A' * 113 + emoji; // 113 letters + 1 emoji grapheme.
        final t = base.copyWith(title: long);
        final dup = t.duplicate(currentUserId: 'me', checklist: checklist);

        expect(dup.title.length, lessThanOrEqualTo(120));
        expect(dup.title.endsWith(' (copy)'), isTrue);
        // The rocket grapheme must NOT be split by truncation. Either it
        // survives or it's dropped entirely — never half.
        final body = dup.title.substring(
          0,
          dup.title.length - ' (copy)'.length,
        );
        expect(
          body.contains('\uD83D') && !body.contains('🚀'),
          isFalse,
          reason: 'truncation must not leave a high surrogate without its pair',
        );
      },
    );

    test(
      'checklist items get fresh UUIDs; text + completion + order preserved',
      () {
        final dup = base.duplicate(currentUserId: 'me', checklist: checklist);
        expect(dup.checklistItems.length, 2);
        for (var i = 0; i < dup.checklistItems.length; i++) {
          expect(dup.checklistItems[i].id, isNot(checklist[i].id));
          expect(dup.checklistItems[i].text, checklist[i].text);
          expect(dup.checklistItems[i].isCompleted, checklist[i].isCompleted);
        }
      },
    );

    test('empty checklist works (no exception)', () {
      final dup = base.duplicate(currentUserId: 'me', checklist: const []);
      expect(dup.checklistItems, isEmpty);
    });
  });
}
