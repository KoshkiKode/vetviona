import 'package:uuid/uuid.dart';

enum DnaTestType {
  autosomal,
  yDna,
  mtDna,
}

class DnaKit {
  final String id;
  final String personId;
  final DnaTestType testType;
  final String testingCompany; // e.g. AncestryDNA, 23andMe, FTDNA, MyHeritage
  final String? kitNumber;
  final String? haplogroup;
  final DateTime? dateTested;
  final String? notes;

  DnaKit({
    String? id,
    required this.personId,
    required this.testType,
    required this.testingCompany,
    this.kitNumber,
    this.haplogroup,
    this.dateTested,
    this.notes,
  }) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'personId': personId,
      'testType': testType.name,
      'testingCompany': testingCompany,
      'kitNumber': kitNumber,
      'haplogroup': haplogroup,
      'dateTested': dateTested?.toIso8601String(),
      'notes': notes,
    };
  }

  factory DnaKit.fromMap(Map<String, dynamic> map) {
    return DnaKit(
      id: map['id'] as String,
      personId: map['personId'] as String,
      testType: DnaTestType.values.firstWhere(
        (e) => e.name == map['testType'],
        orElse: () => DnaTestType.autosomal,
      ),
      testingCompany: map['testingCompany'] as String,
      kitNumber: map['kitNumber'] as String?,
      haplogroup: map['haplogroup'] as String?,
      dateTested: map['dateTested'] != null
          ? DateTime.parse(map['dateTested'] as String)
          : null,
      notes: map['notes'] as String?,
    );
  }
}
