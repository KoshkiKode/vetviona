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
  }) : parentIds = parentIds ?? [],
       childIds = childIds ?? [];

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
    };
  }

  factory Person.fromMap(Map<String, dynamic> map) {
    return Person(
      id: map['id'],
      name: map['name'],
      birthDate: map['birthDate'] != null ? DateTime.parse(map['birthDate']) : null,
      birthPlace: map['birthPlace'],
      deathDate: map['deathDate'] != null ? DateTime.parse(map['deathDate']) : null,
      deathPlace: map['deathPlace'],
      gender: map['gender'],
      parentIds: (map['parentIds'] as String?)?.split(',') ?? [],
      childIds: (map['childIds'] as String?)?.split(',') ?? [],
      spouseId: map['spouseId'],
    );
  }
}
