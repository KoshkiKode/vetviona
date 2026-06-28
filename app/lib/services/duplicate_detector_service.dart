import '../models/person.dart';

/// Fuzzy duplicate detection for persons in the tree.
///
/// Uses name similarity, date proximity, and place matching to find
/// potential duplicates that should be merged.
class DuplicateDetectorService {
  DuplicateDetectorService._();
  static final DuplicateDetectorService instance =
      DuplicateDetectorService._();

  /// A potential duplicate pair with a confidence score.
  static const double defaultThreshold = 0.6;

  /// Finds all potential duplicate pairs in [persons].
  ///
  /// Returns pairs sorted by descending confidence. Only pairs with
  /// confidence ≥ [threshold] are returned.
  List<DuplicatePair> findDuplicates(
    List<Person> persons, {
    double threshold = defaultThreshold,
  }) {
    final pairs = <DuplicatePair>[];

    for (int i = 0; i < persons.length; i++) {
      for (int j = i + 1; j < persons.length; j++) {
        final score = _computeSimilarity(persons[i], persons[j]);
        if (score >= threshold) {
          pairs.add(DuplicatePair(
            person1: persons[i],
            person2: persons[j],
            confidence: score,
            reasons: _explainMatch(persons[i], persons[j]),
          ));
        }
      }
    }

    pairs.sort((a, b) => b.confidence.compareTo(a.confidence));
    return pairs;
  }

  /// Checks whether a specific person might be a duplicate of any existing
  /// person in [existingPersons].
  List<DuplicatePair> findDuplicatesOf(
    Person person,
    List<Person> existingPersons, {
    double threshold = defaultThreshold,
  }) {
    final pairs = <DuplicatePair>[];
    for (final existing in existingPersons) {
      if (existing.id == person.id) continue;
      final score = _computeSimilarity(person, existing);
      if (score >= threshold) {
        pairs.add(DuplicatePair(
          person1: person,
          person2: existing,
          confidence: score,
          reasons: _explainMatch(person, existing),
        ));
      }
    }
    pairs.sort((a, b) => b.confidence.compareTo(a.confidence));
    return pairs;
  }

  // ── Similarity scoring ────────────────────────────────────────────────────

  double _computeSimilarity(Person a, Person b) {
    double score = 0;
    double maxScore = 0;

    // Name comparison (highest weight)
    maxScore += 4.0;
    score += _nameSimilarity(a.name, b.name) * 4.0;

    // Gender match
    if (a.gender != null && b.gender != null) {
      maxScore += 1.0;
      if (a.gender == b.gender) score += 1.0;
    }

    // Birth date
    if (a.birthDate != null && b.birthDate != null) {
      maxScore += 3.0;
      final daysDiff =
          a.birthDate!.difference(b.birthDate!).inDays.abs();
      if (daysDiff == 0) {
        score += 3.0;
      } else if (daysDiff <= 365) {
        score += 2.0;
      } else if (daysDiff <= 365 * 3) {
        score += 1.0;
      }
    } else if (a.birthDate != null || b.birthDate != null) {
      // One has a date, the other doesn't — slight penalty
      maxScore += 1.0;
    }

    // Death date
    if (a.deathDate != null && b.deathDate != null) {
      maxScore += 2.0;
      final daysDiff =
          a.deathDate!.difference(b.deathDate!).inDays.abs();
      if (daysDiff == 0) {
        score += 2.0;
      } else if (daysDiff <= 365) {
        score += 1.5;
      } else if (daysDiff <= 365 * 3) {
        score += 0.5;
      }
    }

    // Birth place
    if (a.birthPlace != null && b.birthPlace != null) {
      maxScore += 2.0;
      score += _placeSimilarity(a.birthPlace!, b.birthPlace!) * 2.0;
    }

    // Death place
    if (a.deathPlace != null && b.deathPlace != null) {
      maxScore += 1.0;
      score += _placeSimilarity(a.deathPlace!, b.deathPlace!);
    }

    // Maiden name
    if (a.maidenName != null &&
        b.maidenName != null &&
        a.maidenName!.isNotEmpty &&
        b.maidenName!.isNotEmpty) {
      maxScore += 1.5;
      score += _nameSimilarity(a.maidenName!, b.maidenName!) * 1.5;
    }

    if (maxScore == 0) return 0;
    return (score / maxScore).clamp(0.0, 1.0);
  }

  /// Computes name similarity using normalised Levenshtein distance and
  /// token overlap.
  double _nameSimilarity(String name1, String name2) {
    final n1 = _normaliseName(name1);
    final n2 = _normaliseName(name2);

    if (n1 == n2) return 1.0;
    if (n1.isEmpty || n2.isEmpty) return 0.0;

    // Token-based comparison
    final tokens1 = n1.split(' ').toSet();
    final tokens2 = n2.split(' ').toSet();
    final intersection = tokens1.intersection(tokens2);
    final union = tokens1.union(tokens2);
    final jaccard =
        union.isEmpty ? 0.0 : intersection.length / union.length;

    // Levenshtein distance on full string
    final editDist = _levenshtein(n1, n2);
    final maxLen = n1.length > n2.length ? n1.length : n2.length;
    final editSimilarity = 1.0 - (editDist / maxLen);

    // Take the higher of the two methods
    return jaccard > editSimilarity ? jaccard : editSimilarity;
  }

  double _placeSimilarity(String place1, String place2) {
    final p1 = place1.toLowerCase().trim();
    final p2 = place2.toLowerCase().trim();
    if (p1 == p2) return 1.0;
    if (p1.contains(p2) || p2.contains(p1)) return 0.8;

    // Check if the main locality matches (first part before comma)
    final loc1 = p1.split(',').first.trim();
    final loc2 = p2.split(',').first.trim();
    if (loc1 == loc2) return 0.7;

    return 0.0;
  }

  String _normaliseName(String name) {
    return name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z\s]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Levenshtein edit distance.
  int _levenshtein(String s, String t) {
    if (s == t) return 0;
    if (s.isEmpty) return t.length;
    if (t.isEmpty) return s.length;

    List<int> v0 = List.generate(t.length + 1, (i) => i);
    List<int> v1 = List.filled(t.length + 1, 0);

    for (int i = 0; i < s.length; i++) {
      v1[0] = i + 1;
      for (int j = 0; j < t.length; j++) {
        final cost = s[i] == t[j] ? 0 : 1;
        v1[j + 1] = [v1[j] + 1, v0[j + 1] + 1, v0[j] + cost]
            .reduce((a, b) => a < b ? a : b);
      }
      final temp = v0;
      v0 = v1;
      v1 = temp;
    }

    return v0[t.length];
  }

  // ── Explanation ───────────────────────────────────────────────────────────

  List<String> _explainMatch(Person a, Person b) {
    final reasons = <String>[];

    final nameSim = _nameSimilarity(a.name, b.name);
    if (nameSim >= 0.9) {
      reasons.add('Names are identical or nearly identical');
    } else if (nameSim >= 0.6) {
      reasons.add('Similar names');
    }

    if (a.gender != null && b.gender != null && a.gender == b.gender) {
      reasons.add('Same gender');
    }

    if (a.birthDate != null && b.birthDate != null) {
      final diff = a.birthDate!.difference(b.birthDate!).inDays.abs();
      if (diff == 0) {
        reasons.add('Same birth date');
      } else if (diff <= 365) {
        reasons.add('Birth dates within 1 year');
      } else if (diff <= 365 * 3) {
        reasons.add('Birth dates within 3 years');
      }
    }

    if (a.deathDate != null && b.deathDate != null) {
      final diff = a.deathDate!.difference(b.deathDate!).inDays.abs();
      if (diff == 0) {
        reasons.add('Same death date');
      } else if (diff <= 365) {
        reasons.add('Death dates within 1 year');
      }
    }

    if (a.birthPlace != null && b.birthPlace != null) {
      final sim = _placeSimilarity(a.birthPlace!, b.birthPlace!);
      if (sim >= 0.7) reasons.add('Same birth place');
    }

    if (a.deathPlace != null && b.deathPlace != null) {
      final sim = _placeSimilarity(a.deathPlace!, b.deathPlace!);
      if (sim >= 0.7) reasons.add('Same death place');
    }

    return reasons;
  }
}

/// A pair of persons that are potentially duplicates.
class DuplicatePair {
  final Person person1;
  final Person person2;
  final double confidence;
  final List<String> reasons;

  const DuplicatePair({
    required this.person1,
    required this.person2,
    required this.confidence,
    this.reasons = const [],
  });

  String get confidenceLabel {
    if (confidence >= 0.9) return 'Very Likely';
    if (confidence >= 0.7) return 'Likely';
    if (confidence >= 0.5) return 'Possible';
    return 'Unlikely';
  }
}
