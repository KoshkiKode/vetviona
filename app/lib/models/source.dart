class Source {
  String id;
  String personId;
  String title;
  String type;
  String url;
  String? imagePath;
  String? extractedInfo;
  List<String> citedFacts;

  /// Author(s) of the source document.
  String? author;

  /// Publisher of the source document.
  String? publisher;

  /// Publication date as free text (e.g. "1920" or "Jan 1920").
  String? publicationDate;

  /// Archive or repository name (e.g. "National Archives, Kew").
  String? repository;

  /// Volume and/or page reference (e.g. "Vol. 3, p. 45").
  String? volumePage;

  /// Date the URL was accessed, as free text.
  String? retrievalDate;

  /// Evidence quality rating — one of [confidenceRatings].
  String? confidence;

  /// Tree scope — mirrors Person.treeId so tree-level sources can be loaded.
  String? treeId;

  /// Unix-millisecond timestamp of the last local modification.
  /// See [Person.updatedAt] for the merge semantics.
  int? updatedAt;

  static const List<String> confidenceRatings = ['A', 'B', 'C', 'D', 'F'];
  static const Map<String, String> confidenceLabels = {
    'A': 'Reliable',
    'B': 'Secondary',
    'C': 'Questionable',
    'D': 'Unreliable',
    'F': 'Conflicting',
  };

  Source({
    required this.id,
    required this.personId,
    required this.title,
    required this.type,
    required this.url,
    this.imagePath,
    this.extractedInfo,
    List<String>? citedFacts,
    this.author,
    this.publisher,
    this.publicationDate,
    this.repository,
    this.volumePage,
    this.retrievalDate,
    this.confidence,
    this.treeId,
    this.updatedAt,
  }) : citedFacts = citedFacts ?? [];

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'personId': personId,
      'title': title,
      'type': type,
      'url': url,
      'imagePath': imagePath,
      'extractedInfo': extractedInfo,
      'citedFacts': citedFacts.join(','),
      'author': author,
      'publisher': publisher,
      'publicationDate': publicationDate,
      'repository': repository,
      'volumePage': volumePage,
      'retrievalDate': retrievalDate,
      'confidence': confidence,
      'treeId': treeId,
      'updatedAt': updatedAt,
    };
  }

  factory Source.fromMap(Map<String, dynamic> map) {
    return Source(
      id: map['id'] as String,
      personId: map['personId'] as String,
      title: map['title'] as String,
      type: map['type'] as String,
      url: map['url'] as String,
      imagePath: map['imagePath'] as String?,
      extractedInfo: map['extractedInfo'] as String?,
      citedFacts: (map['citedFacts'] as String?)
              ?.split(',')
              .where((s) => s.isNotEmpty)
              .toList() ??
          [],
      author: map['author'] as String?,
      publisher: map['publisher'] as String?,
      publicationDate: map['publicationDate'] as String?,
      repository: map['repository'] as String?,
      volumePage: map['volumePage'] as String?,
      retrievalDate: map['retrievalDate'] as String?,
      confidence: map['confidence'] as String?,
      treeId: map['treeId'] as String?,
      updatedAt: map['updatedAt'] as int?,
    );
  }
}
