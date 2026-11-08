/// One role an event can give: a built-in preset, the event's own version of
/// one, or a custom role (Req 26a).
class RoleDefinition {
  const RoleDefinition({
    required this.id,
    required this.name,
    required this.permissions,
    required this.isPreset,
    this.isEdited = false,
  });

  final String id;
  final String name;
  final Set<String> permissions;

  /// A built-in preset, edited or not.
  final bool isPreset;

  /// A preset the event has its own version of.
  final bool isEdited;

  bool get isOwner => id == 'owner';
}

/// The permission catalogue and the presets, read from the file the backend
/// writes from `functions/src/events/permissions.ts`, so the role screens show
/// exactly what the server grants.
class RoleCatalogue {
  RoleCatalogue.fromJson(Map<String, dynamic> json)
    : permissions = (json['permissions'] as List).cast<String>(),
      presets = [
        for (final preset
            in (json['presets'] as List).cast<Map<String, dynamic>>())
          RoleDefinition(
            id: preset['id'] as String,
            name: preset['name'] as String,
            permissions: (preset['permissions'] as List).cast<String>().toSet(),
            isPreset: true,
          ),
      ];

  /// Inside `functions/src` beside the label defaults. Regenerate it with
  /// `npm run gen:roles`.
  static const assetPath = 'functions/src/shared/role_presets.json';

  /// Set once at startup, before the app runs.
  static late RoleCatalogue current;

  /// Every permission, in catalogue order.
  final List<String> permissions;

  /// The built-in presets, in the order screens show them.
  final List<RoleDefinition> presets;
}

/// An event's roles: the presets, with the event's own version replacing any
/// it has edited, then its custom roles by name. [eventRoles] are the
/// `events/{id}/roles` documents, keyed by role ID.
List<RoleDefinition> resolveRoles(
  RoleCatalogue catalogue,
  Map<String, Map<String, dynamic>> eventRoles,
) {
  final known = catalogue.permissions.toSet();
  RoleDefinition fromDoc(String id, Map<String, dynamic> doc, {String? name}) {
    final permissions = doc['permissions'];
    final docName = doc['name'];
    return RoleDefinition(
      id: id,
      name: docName is String && docName.trim().isNotEmpty
          ? docName
          : name ?? id,
      permissions: permissions is List
          ? permissions.whereType<String>().where(known.contains).toSet()
          : const {},
      isPreset: name != null,
      isEdited: name != null,
    );
  }

  final presetIds = {for (final p in catalogue.presets) p.id};
  final custom = [
    for (final entry in eventRoles.entries)
      if (!presetIds.contains(entry.key)) fromDoc(entry.key, entry.value),
  ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return [
    for (final preset in catalogue.presets)
      // The Owner always holds everything, whatever the event saved.
      if (eventRoles[preset.id] case final doc? when !preset.isOwner)
        fromDoc(preset.id, doc, name: preset.name)
      else
        preset,
    ...custom,
  ];
}

/// What [roleIds] grant together: the union, in catalogue order, matching
/// `computePermissions` on the server. [readsAllExpenses] adds what the
/// event's expense access setting gives (Req 38).
List<String> computePermissions(
  Iterable<String> roleIds,
  List<RoleDefinition> roles, {
  bool readsAllExpenses = false,
}) {
  final byId = {for (final r in roles) r.id: r};
  final granted = {
    for (final id in roleIds) ...?byId[id]?.permissions,
    if (readsAllExpenses) 'expenses.readAll',
  };
  return [
    for (final p in RoleCatalogue.current.permissions)
      if (granted.contains(p)) p,
  ];
}

/// The groups the role editor shows permissions in, in order.
const permissionGroups = [
  'event',
  'people',
  'schedule',
  'participants',
  'money',
  'tasks',
  'chat',
  'checkin',
  'safety',
  'competition',
];

/// Which of [permissionGroups] a permission belongs to.
String permissionGroupOf(String permission) =>
    switch (permission.split('.').first) {
      'event' => 'event',
      'members' || 'roles' => 'people',
      'schedule' || 'updates' => 'schedule',
      'participants' || 'group' || 'registrations' => 'participants',
      'money' || 'budget' || 'expenses' || 'contributions' => 'money',
      'tasks' => 'tasks',
      'chat' || 'messages' => 'chat',
      'checkin' || 'counts' => 'checkin',
      'incidents' => 'safety',
      _ => 'competition',
    };
