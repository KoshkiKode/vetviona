/// A union between two people — marriage, civil partnership, or any
/// romantic/co-parenting relationship. Stored in the `partnerships` table.
class Partnership {
  String id;
  String person1Id;
  String person2Id;

  /// One of [allStatuses].
  String status;

  DateTime? startDate;
  String? startPlace;

  /// Non-null once the union has ended (divorce, separation, annulment, death).
  DateTime? endDate;
  String? endPlace;

  String? treeId;

  /// Free-text notes about this union.
  String? notes;

  /// Ceremony type — one of [allCeremonyTypes].
  String? ceremonyType;

  /// IDs of sources that evidence this union (comma-separated in DB).
  List<String> sourceIds;

  /// Names of witnesses or officiants.
  String? witnesses;

  /// Unix-millisecond timestamp of the last local modification.
  /// See [Person.updatedAt] for the merge semantics.
  int? updatedAt;

  static const List<String> allCeremonyTypes = [
    'civil',
    'religious',
    'traditional',
    'common-law',
    'other',
  ];

  Partnership({
    required this.id,
    required this.person1Id,
    required this.person2Id,
    this.status = 'married',
    this.startDate,
    this.startPlace,
    this.endDate,
    this.endPlace,
    this.treeId,
    this.notes,
    this.ceremonyType,
    List<String>? sourceIds,
    this.witnesses,
    this.updatedAt,
  }) : sourceIds = sourceIds ?? [];

  /// Whether this union has formally ended.
  bool get isEnded =>
      endDate != null ||
      status == 'divorced' ||
      status == 'separated' ||
      status == 'annulled';

  /// User-facing label for [status].
  String get statusLabel {
    switch (status) {
      case 'married':
        return 'Married';
      case 'partnered':
        return 'Partnered';
      case 'divorced':
        return 'Divorced';
      case 'separated':
        return 'Separated';
      case 'annulled':
        return 'Annulled';
      default:
        return 'Other';
    }
  }

  static const List<String> allStatuses = [
    'married',
    'partnered',
    'divorced',
    'separated',
    'annulled',
    'other',
  ];

  Map<String, dynamic> toMap() => {
        'id': id,
        'person1Id': person1Id,
        'person2Id': person2Id,
        'status': status,
        'startDate': startDate?.toIso8601String(),
        'startPlace': startPlace,
        'endDate': endDate?.toIso8601String(),
        'endPlace': endPlace,
        'treeId': treeId,
        'notes': notes,
        'ceremonyType': ceremonyType,
        'sourceIds': sourceIds.join(','),
        'witnesses': witnesses,
        'updatedAt': updatedAt,
      };

  factory Partnership.fromMap(Map<String, dynamic> map) => Partnership(
        id: map['id'] as String,
        person1Id: map['person1Id'] as String,
        person2Id: map['person2Id'] as String,
        status: map['status'] as String? ?? 'married',
        startDate: map['startDate'] != null
            ? DateTime.parse(map['startDate'] as String)
            : null,
        startPlace: map['startPlace'] as String?,
        endDate: map['endDate'] != null
            ? DateTime.parse(map['endDate'] as String)
            : null,
        endPlace: map['endPlace'] as String?,
        treeId: map['treeId'] as String?,
        notes: map['notes'] as String?,
        ceremonyType: map['ceremonyType'] as String?,
        sourceIds: (map['sourceIds'] as String?)
                ?.split(',')
                .where((s) => s.isNotEmpty)
                .toList() ??
            [],
        witnesses: map['witnesses'] as String?,
        updatedAt: map['updatedAt'] as int?,
      );
}
