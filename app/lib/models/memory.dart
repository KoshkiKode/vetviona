/// A memory (story, diary entry, long-form text) attached to a person.
class Memory {
  String id;
  String personId;

  /// The title of the memory.
  String title;

  /// The main text content.
  String text;

  /// An optional date when this memory took place.
  String? date;

  /// An optional location where this memory took place.
  String? place;

  /// Optional URI to an attached image or document.
  String? mediaUri;

  /// Tree scope — mirrors Person.treeId.
  String? treeId;

  /// Unix-millisecond timestamp of the last local modification.
  int? updatedAt;

  Memory({
    required this.id,
    required this.personId,
    required this.title,
    required this.text,
    this.date,
    this.place,
    this.mediaUri,
    this.treeId,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'personId': personId,
        'title': title,
        'text': text,
        'date': date,
        'place': place,
        'mediaUri': mediaUri,
        'treeId': treeId,
        'updatedAt': updatedAt,
      };

  factory Memory.fromMap(Map<String, dynamic> map) => Memory(
        id: map['id'] as String,
        personId: map['personId'] as String,
        title: map['title'] as String,
        text: map['text'] as String,
        date: map['date'] as String?,
        place: map['place'] as String?,
        mediaUri: map['mediaUri'] as String?,
        treeId: map['treeId'] as String?,
        updatedAt: map['updatedAt'] as int?,
      );
}
