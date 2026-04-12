import 'geo_coord.dart';

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
  String? occupation;
  String? nationality;
  String? maidenName;
  DateTime? burialDate;
  String? burialPlace;

  /// Geographic coordinates + political boundaries for the birth location.
  GeoCoord? birthCoord;

  /// Geographic coordinates + political boundaries for the death location.
  GeoCoord? deathCoord;

  /// Geographic coordinates + political boundaries for the burial location.
  GeoCoord? burialCoord;

  /// Postal / ZIP code for the birth place.
  String? birthPostalCode;

  /// Postal / ZIP code for the death place.
  String? deathPostalCode;

  /// Postal / ZIP code for the burial place.
  String? burialPostalCode;

  /// When `true`, this person is excluded from GEDCOM exports and RootLoop™
  /// sync — their data stays strictly local.  Intended for living family
  /// members whose contact details and records should never leave the device.
  bool isPrivate;

  /// Cause of death, e.g. "cardiac arrest", "pneumonia".
  String? causeOfDeath;

  /// ABO/Rh blood type, one of [allBloodTypes].
  String? bloodType;

  /// Eye colour, free text (e.g. "brown", "hazel").
  String? eyeColour;

  /// Hair colour, free text (e.g. "auburn", "grey").
  String? hairColour;

  /// Height as free text (e.g. "178 cm", "5 ft 10 in").
  String? height;

  /// Religion or faith tradition (e.g. "Catholic", "Jewish").
  String? religion;

  /// Highest education level attained (e.g. "Bachelor's degree").
  String? education;

  /// Alternate or AKA names (serialised with `;` in the database).
  List<String> aliases;

  /// Maps fact name (e.g. `'Birth Date'`, `'Death Place'`) to the ID of the
  /// preferred source for that fact, as resolved in the Evidence Conflict
  /// Resolver.
  Map<String, String> preferredSourceIds;

  /// When `true`, this person's medical conditions participate in RootLoop™
  /// sync.  Defaults to `false` so that medical data stays strictly local
  /// unless the user explicitly opts in.
  bool syncMedical;

  /// Unix-millisecond timestamp of the last local modification.
  ///
  /// Used by [TreeProvider.importFromSync] to implement concurrent / parallel
  /// editing: when two devices both have a version of the same person, the one
  /// with the higher [updatedAt] value wins.  Records that pre-date the
  /// introduction of this field (i.e. where [updatedAt] is `null`) are treated
  /// as having timestamp 0 so that they never silently overwrite a locally
  /// edited record.
  int? updatedAt;

  static const List<String> allBloodTypes = [
    'A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-', 'Unknown',
  ];

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
    this.occupation,
    this.nationality,
    this.maidenName,
    this.burialDate,
    this.burialPlace,
    this.birthCoord,
    this.deathCoord,
    this.burialCoord,
    this.birthPostalCode,
    this.deathPostalCode,
    this.burialPostalCode,
    this.isPrivate = false,
    this.syncMedical = false,
    Map<String, String>? preferredSourceIds,
    this.causeOfDeath,
    this.bloodType,
    this.eyeColour,
    this.hairColour,
    this.height,
    this.religion,
    this.education,
    List<String>? aliases,
    this.updatedAt,
  })  : parentIds = parentIds ?? [],
        childIds = childIds ?? [],
        parentRelTypes = parentRelTypes ?? {},
        photoPaths = photoPaths ?? [],
        sourceIds = sourceIds ?? [],
        preferredSourceIds = preferredSourceIds ?? {},
        aliases = aliases ?? [];

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
      'occupation': occupation,
      'nationality': nationality,
      'maidenName': maidenName,
      'burialDate': burialDate?.toIso8601String(),
      'burialPlace': burialPlace,
      'birthCoord': birthCoord?.toDbString(),
      'deathCoord': deathCoord?.toDbString(),
      'burialCoord': burialCoord?.toDbString(),
      'birthPostalCode': birthPostalCode,
      'deathPostalCode': deathPostalCode,
      'burialPostalCode': burialPostalCode,
      'isPrivate': isPrivate ? 1 : 0,
      'syncMedical': syncMedical ? 1 : 0,
      // Encoded as "fact=sourceId,fact=sourceId"; fact names use spaces but
      // never '=' or ',', so the encoding is unambiguous.
      'preferredSourceIds': preferredSourceIds.entries
          .map((e) => '${e.key}=${e.value}')
          .join(','),
      'causeOfDeath': causeOfDeath,
      'bloodType': bloodType,
      'eyeColour': eyeColour,
      'hairColour': hairColour,
      'height': height,
      'religion': religion,
      'education': education,
      'aliases': aliases.join(';'),
      'updatedAt': updatedAt,
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
    final prefRaw = map['preferredSourceIds'] as String? ?? '';
    final prefSourceIds = <String, String>{};
    for (final entry in prefRaw.split(',')) {
      final idx = entry.indexOf('=');
      if (idx > 0) {
        prefSourceIds[entry.substring(0, idx)] = entry.substring(idx + 1);
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
      occupation: map['occupation'] as String?,
      nationality: map['nationality'] as String?,
      maidenName: map['maidenName'] as String?,
      burialDate: map['burialDate'] != null
          ? DateTime.parse(map['burialDate'] as String)
          : null,
      burialPlace: map['burialPlace'] as String?,
      birthCoord: GeoCoord.fromDbString(map['birthCoord'] as String?),
      deathCoord: GeoCoord.fromDbString(map['deathCoord'] as String?),
      burialCoord: GeoCoord.fromDbString(map['burialCoord'] as String?),
      birthPostalCode: map['birthPostalCode'] as String?,
      deathPostalCode: map['deathPostalCode'] as String?,
      burialPostalCode: map['burialPostalCode'] as String?,
      isPrivate: (map['isPrivate'] as int? ?? 0) != 0,
      syncMedical: (map['syncMedical'] as int? ?? 0) != 0,
      preferredSourceIds: prefSourceIds,
      causeOfDeath: map['causeOfDeath'] as String?,
      bloodType: map['bloodType'] as String?,
      eyeColour: map['eyeColour'] as String?,
      hairColour: map['hairColour'] as String?,
      height: map['height'] as String?,
      religion: map['religion'] as String?,
      education: map['education'] as String?,
      aliases: (map['aliases'] as String?)
              ?.split(';')
              .where((s) => s.isNotEmpty)
              .toList() ??
          [],
      updatedAt: map['updatedAt'] as int?,
    );
  }
}
