/// An ethnicity / heritage entry for a person.
///
/// Since Vetviona does not run its own DNA lab, heritage data is entered
/// manually by the user or imported from GEDCOM DNA extensions.  Users can
/// also link to their existing DNA results on AncestryDNA, 23andMe,
/// MyHeritage DNA, etc.
class Heritage {
  String id;
  String personId;

  /// Geographic / ethnic region (e.g. "West Africa", "Scandinavian",
  /// "Ashkenazi Jewish", "Irish").
  String region;

  /// Percentage as reported by the DNA service (0.0–100.0).
  /// Null if entered manually without a percentage.
  double? percentage;

  /// Free-text notes (e.g. "From AncestryDNA, updated March 2025").
  String? notes;

  /// The DNA service this data came from, if any.
  /// e.g. "AncestryDNA", "23andMe", "MyHeritage DNA", "Manual".
  String? dnaService;

  /// Deep link to the user's results on the DNA service.
  String? dnaResultsUrl;

  /// Tree scope — mirrors Person.treeId.
  String? treeId;

  /// Unix-millisecond timestamp of the last local modification.
  int? updatedAt;

  Heritage({
    required this.id,
    required this.personId,
    required this.region,
    this.percentage,
    this.notes,
    this.dnaService,
    this.dnaResultsUrl,
    this.treeId,
    this.updatedAt,
  });

  /// Common ethnicity regions for the UI picker.
  static const List<String> commonRegions = [
    // Africa
    'West African', 'East African', 'North African', 'Southern African',
    'Central African', 'Cameroonian/Congolese', 'Nigerian', 'Malian',
    'Senegalese',
    // Americas
    'Indigenous American', 'Native American', 'Mesoamerican', 'Andean',
    'Caribbean',
    // Asia
    'East Asian', 'Chinese', 'Japanese', 'Korean', 'Southeast Asian',
    'Filipino', 'Vietnamese', 'South Asian', 'Indian', 'Central Asian',
    // Europe
    'English', 'Irish', 'Scottish', 'Welsh', 'Scandinavian', 'Norwegian',
    'Swedish', 'Danish', 'Finnish', 'German', 'French', 'Italian',
    'Iberian', 'Spanish', 'Portuguese', 'Greek', 'Balkan',
    'Eastern European', 'Polish', 'Russian', 'Ukrainian',
    'Baltic', 'Dutch', 'Belgian',
    // Middle East
    'Middle Eastern', 'Persian', 'Turkish', 'Levantine', 'Arabian',
    // Jewish
    'Ashkenazi Jewish', 'Sephardic Jewish', 'Mizrahi Jewish',
    // Oceania
    'Polynesian', 'Melanesian', 'Aboriginal Australian', 'Maori',
    // Mixed / Other
    'Other',
  ];

  /// Known DNA services for the picker.
  static const List<String> dnaServices = [
    'Manual',
    'AncestryDNA',
    '23andMe',
    'MyHeritage DNA',
    'FamilyTreeDNA',
    'LivingDNA',
    'Nebula Genomics',
    'Other',
  ];

  Map<String, dynamic> toMap() => {
        'id': id,
        'personId': personId,
        'region': region,
        'percentage': percentage,
        'notes': notes,
        'dnaService': dnaService,
        'dnaResultsUrl': dnaResultsUrl,
        'treeId': treeId,
        'updatedAt': updatedAt,
      };

  factory Heritage.fromMap(Map<String, dynamic> map) => Heritage(
        id: map['id'] as String,
        personId: map['personId'] as String,
        region: map['region'] as String,
        percentage: (map['percentage'] as num?)?.toDouble(),
        notes: map['notes'] as String?,
        dnaService: map['dnaService'] as String?,
        dnaResultsUrl: map['dnaResultsUrl'] as String?,
        treeId: map['treeId'] as String?,
        updatedAt: map['updatedAt'] as int?,
      );
}
