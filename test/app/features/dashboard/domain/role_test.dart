import 'package:crewpoint_app/app/features/dashboard/domain/models/role.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final catalogue = RoleCatalogue.current;

  group('RoleCatalogue', () {
    test('holds the 33 permissions and the 12 presets in order', () {
      expect(catalogue.permissions, hasLength(33));
      expect(catalogue.presets.map((r) => r.id), [
        'owner',
        'coOwner',
        'admin',
        'finance',
        'crewLead',
        'crewMember',
        'volunteer',
        'scorer',
        'vendor',
        'sponsor',
        'participant',
        'observer',
      ]);
    });

    test('every preset includes group.readOwn', () {
      for (final preset in catalogue.presets) {
        expect(
          preset.permissions,
          contains('group.readOwn'),
          reason: preset.id,
        );
      }
    });
  });

  group('resolveRoles', () {
    test('with no event roles, gives the presets unchanged', () {
      final roles = resolveRoles(catalogue, const {});
      expect(roles.map((r) => r.id), catalogue.presets.map((r) => r.id));
      expect(roles.every((r) => r.isPreset && !r.isEdited), isTrue);
    });

    test('an edited preset keeps its place and is marked edited', () {
      final roles = resolveRoles(catalogue, const {
        'participant': {
          'name': 'Guest',
          'permissions': ['counts.read'],
          'preset': true,
        },
      });
      final participant = roles.firstWhere((r) => r.id == 'participant');
      expect(participant.name, 'Guest');
      expect(participant.permissions, {'counts.read'});
      expect(participant.isEdited, isTrue);
      expect(participant.isPreset, isTrue);
    });

    test('custom roles come after the presets, by name', () {
      final roles = resolveRoles(catalogue, const {
        'zeta': {'name': 'Stage crew', 'permissions': <String>[]},
        'alpha': {
          'name': 'Hospitality',
          'permissions': ['chat.send'],
        },
      });
      expect(roles.skip(12).map((r) => r.name), ['Hospitality', 'Stage crew']);
      expect(roles.last.isPreset, isFalse);
    });

    test('permissions outside the catalogue are dropped', () {
      final roles = resolveRoles(catalogue, const {
        'x': {
          'name': 'X',
          'permissions': ['chat.send', 'money.steal', 7],
        },
      });
      expect(roles.last.permissions, {'chat.send'});
    });
  });

  group('computePermissions', () {
    test('is the union of the roles, in catalogue order', () {
      final roles = resolveRoles(catalogue, const {});
      final granted = computePermissions(['scorer', 'sponsor'], roles);
      expect(granted, ['group.readOwn', 'chat.send', 'scores.enter']);
    });

    test('an unknown role grants nothing', () {
      expect(
        computePermissions(['nope'], resolveRoles(catalogue, const {})),
        isEmpty,
      );
    });
  });
}
