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
  String? spouseId;
  List<String> photoPaths;
  List<String> sourceIds;
  DateTime? marriageDate;
  String? marriagePlace;
  String? notes;
  String? treeId;

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
    this.spouseId,
    List<String>? photoPaths,
    List<String>? sourceIds,
    this.marriageDate,
    this.marriagePlace,
    this.notes,
    this.treeId,
  })  : parentIds = parentIds ?? [],
        childIds = childIds ?? [],
        photoPaths = photoPaths ?? [],
        sourceIds = sourceIds ?? [];

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
      'spouseId': spouseId,
      'photoPaths': photoPaths.join(';'),
      'sourceIds': sourceIds.join(','),
      'marriageDate': marriageDate?.toIso8601String(),
      'marriagePlace': marriagePlace,
      'notes': notes,
      'treeId': treeId,
    };
  }

  factory Person.fromMap(Map<String, dynamic> map) {
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
      spouseId: map['spouseId'] as String?,
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
      marriageDate: map['marriageDate'] != null
          ? DateTime.parse(map['marriageDate'] as String)
          : null,
      marriagePlace: map['marriagePlace'] as String?,
      notes: map['notes'] as String?,
      treeId: map['treeId'] as String?,
    );
  }
}
