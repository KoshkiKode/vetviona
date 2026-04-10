class MedicalCondition {
  String id;
  String personId;
  String condition;
  String category;
  String? ageOfOnset;
  String? notes;
  String? treeId;

  static const List<String> categories = [
    'Cardiovascular',
    'Cancer',
    'Mental Health',
    'Neurological',
    'Metabolic / Endocrine',
    'Autoimmune',
    'Respiratory',
    'Genetic',
    'Musculoskeletal',
    'Other',
  ];

  MedicalCondition({
    required this.id,
    required this.personId,
    required this.condition,
    required this.category,
    this.ageOfOnset,
    this.notes,
    this.treeId,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'personId': personId,
        'condition': condition,
        'category': category,
        'ageOfOnset': ageOfOnset,
        'notes': notes,
        'treeId': treeId,
      };

  factory MedicalCondition.fromMap(Map<String, dynamic> map) =>
      MedicalCondition(
        id: map['id'] as String,
        personId: map['personId'] as String,
        condition: map['condition'] as String,
        category: map['category'] as String,
        ageOfOnset: map['ageOfOnset'] as String?,
        notes: map['notes'] as String?,
        treeId: map['treeId'] as String?,
      );
}
