class Source {
  String id;
  String personId;
  String title;
  String type;
  String url;
  String? imagePath;
  String? extractedInfo;
  List<String> citedFacts;

  Source({
    required this.id,
    required this.personId,
    required this.title,
    required this.type,
    required this.url,
    this.imagePath,
    this.extractedInfo,
    List<String>? citedFacts,
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
    );
  }
}
