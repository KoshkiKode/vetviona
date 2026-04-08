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
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'personId': personId,
      'title': title,
      'type': type,
      'url': url,
      'imagePath': imagePath,
      'extractedInfo': extractedInfo,
    };
  }

  factory Source.fromMap(Map<String, dynamic> map) {
    return Source(
      id: map['id'],
      personId: map['personId'],
      title: map['title'],
      type: map['type'],
      url: map['url'],
      imagePath: map['imagePath'],
      extractedInfo: map['extractedInfo'],
    );
  }
}
