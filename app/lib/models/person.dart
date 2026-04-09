class Person {
  String id;
  String name;
  DateTime? birthDate;
  String? birthPlace;
  DateTime? deathDate;
  String? deathPlace;
  String? gender;
  List<String> parentIds;
  List<String> childIds;

  /// Relationship type for each parent: `biological`, `adoptive`, `step`,
  /// `foster`, or `unknown`.  Defaults to `biological` when not present.
  Map<String, String> parentRelTypes;

  List<String> photoPaths;
  List<String> sourceIds;
  String? notes;
  String? treeId;

  static const List<String> allParentRelTypes = [
    'biological',
    'adoptive',
    'step',
    'foster',
    'unknown',
  ];

  Person({
    required this.id,
    required this.name,
    this.birthDate,
    this.birthPlace,
    this.deathDate,
    this.deathPlace,
    this.gender,
    List<String>? parentIds,
    List<String>? childIds,
    Map<String, String>? parentRelTypes,
    List<String>? photoPaths,
    List<String>? sourceIds,
    this.notes,
    this.treeId,
  })  : parentIds = parentIds ?? [],
        childIds = childIds ?? [],
        parentRelTypes = parentRelTypes ?? {},
        photoPaths = photoPaths ?? [],
        sourceIds = sourceIds ?? [];

  /// Returns the relationship type for [parentId], defaulting to `biological`.
  String parentRelType(String parentId) =>
      parentRelTypes[parentId] ?? 'biological';

  /// User-facing label for a parent relationship type string.
  static String relTypeLabel(String type) {
    switch (type) {
      case 'biological':
        return 'Biological';
      case 'adoptive':
        return 'Adoptive';
      case 'step':
        return 'Step';
      case 'foster':
        return 'Foster';
      default:
        return 'Unknown';
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'birthDate': birthDate?.toIso8601String(),
      'birthPlace': birthPlace,
      'deathDate': deathDate?.toIso8601String(),
      'deathPlace': deathPlace,
      'gender': gender,
      'parentIds': parentIds.join(','),
      'childIds': childIds.join(','),
      'photoPaths': photoPaths.join(';'),
      'sourceIds': sourceIds.join(','),
      // Encoded as "uuid=type,uuid=type"; UUIDs never contain '=' or ','
      'parentRelTypes': parentRelTypes.entries
          .map((e) => '${e.key}=${e.value}')
          .join(','),
      'notes': notes,
      'treeId': treeId,
    };
  }

  factory Person.fromMap(Map<String, dynamic> map) {
    final relTypesRaw = map['parentRelTypes'] as String? ?? '';
    final relTypes = <String, String>{};
    for (final entry in relTypesRaw.split(',')) {
      final idx = entry.indexOf('=');
      if (idx > 0) {
        relTypes[entry.substring(0, idx)] = entry.substring(idx + 1);
      }
    }
    return Person(
      id: map['id'] as String,
      name: map['name'] as String,
      birthDate: map['birthDate'] != null
          ? DateTime.parse(map['birthDate'] as String)
          : null,
      birthPlace: map['birthPlace'] as String?,
      deathDate: map['deathDate'] != null
          ? DateTime.parse(map['deathDate'] as String)
          : null,
      deathPlace: map['deathPlace'] as String?,
      gender: map['gender'] as String?,
      parentIds: (map['parentIds'] as String?)
              ?.split(',')
              .where((s) => s.isNotEmpty)
              .toList() ??
          [],
      childIds: (map['childIds'] as String?)
              ?.split(',')
              .where((s) => s.isNotEmpty)
              .toList() ??
          [],
      parentRelTypes: relTypes,
      photoPaths: (map['photoPaths'] as String?)
              ?.split(';')
              .where((s) => s.isNotEmpty)
              .toList() ??
          [],
      sourceIds: (map['sourceIds'] as String?)
              ?.split(',')
              .where((s) => s.isNotEmpty)
              .toList() ??
          [],
      notes: map['notes'] as String?,
      treeId: map['treeId'] as String?,
    );
  }
}
