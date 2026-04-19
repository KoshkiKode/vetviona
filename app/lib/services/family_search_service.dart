import 'package:uuid/uuid.dart';

import '../models/source.dart';

/// Lightweight FamilySearch integration helpers.
///
/// FamilySearch requires authenticated APIs for full record access, so this
/// service currently provides safe URL/id helpers and source creation.
class FamilySearchService {
  FamilySearchService._();

  static final FamilySearchService instance = FamilySearchService._();

  /// Canonical FamilySearch person URL for a FamilySearch person id.
  String personUrl(String personId) =>
      'https://www.familysearch.org/tree/person/details/$personId';

  /// Extracts a FamilySearch person id from either:
  /// - `https://www.familysearch.org/tree/person/details/KW7S-BBQ`
  /// - `KW7S-BBQ`
  String? extractPersonId(String input) {
    final raw = input.trim();
    if (raw.isEmpty) return null;

    final fromUrl = RegExp(
      r'familysearch\.org/tree/person/details/([A-Za-z0-9-]+)',
      caseSensitive: false,
    ).firstMatch(raw);
    if (fromUrl != null) return fromUrl.group(1);

    if (RegExp(r'^[A-Za-z0-9-]+$').hasMatch(raw)) return raw;
    return null;
  }

  /// Creates a [Source] record for a FamilySearch person.
  Source personToSource(String familySearchId, String personId) {
    return Source(
      id: const Uuid().v4(),
      personId: personId,
      title: 'FamilySearch person $familySearchId',
      type: 'Online Database',
      url: personUrl(familySearchId),
      author: 'FamilySearch contributors',
      repository: 'FamilySearch (familysearch.org)',
      confidence: 'B',
      extractedInfo: 'FamilySearch ID: $familySearchId',
      citedFacts: const [],
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
  }
}
