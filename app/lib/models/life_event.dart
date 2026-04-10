class LifeEvent {
  String id;
  String personId;
  String title;
  DateTime? date;
  String? place;
  String? notes;
  String? treeId;

  LifeEvent({
    required this.id,
    required this.personId,
    required this.title,
    this.date,
    this.place,
    this.notes,
    this.treeId,
  });

  static const List<String> commonTypes = [
    'Baptism', 'Christening', 'Confirmation', 'Bar/Bat Mitzvah',
    'Graduation', 'Military Service', 'Immigration', 'Emigration',
    'Naturalization', 'Census', 'Occupation Change', 'Residence',
    'Illness', 'Other',
  ];

  Map<String, dynamic> toMap() => {
    'id': id,
    'personId': personId,
    'title': title,
    'date': date?.toIso8601String(),
    'place': place,
    'notes': notes,
    'treeId': treeId,
  };

  factory LifeEvent.fromMap(Map<String, dynamic> map) => LifeEvent(
    id: map['id'] as String,
    personId: map['personId'] as String,
    title: map['title'] as String,
    date: map['date'] != null ? DateTime.parse(map['date'] as String) : null,
    place: map['place'] as String?,
    notes: map['notes'] as String?,
    treeId: map['treeId'] as String?,
  );
}
