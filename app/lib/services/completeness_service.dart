import '../models/person.dart';
import '../models/source.dart';

/// Per-person and per-tree completeness scoring.
///
/// Helps users identify which persons are missing critical data (no birth
/// date, no parents, no sources) and prioritise research accordingly.
class CompletenessService {
  CompletenessService._();
  static final CompletenessService instance = CompletenessService._();

  /// Computes a completeness score for a single person.
  ///
  /// Returns a [PersonCompleteness] with a score from 0–100 and a list of
  /// missing items the user could fill in.
  PersonCompleteness scorePerson(
    Person person, {
    required List<Source> personSources,
    required List<Person> allPersons,
  }) {
    double score = 0;
    const maxScore = 100.0;
    final missing = <String>[];

    // ── Name (5 points) ─────────────────────────────────────────────────────
    if (person.name.trim().isNotEmpty &&
        person.name.trim().split(RegExp(r'\s+')).length >= 2) {
      score += 5;
    } else if (person.name.trim().isNotEmpty) {
      score += 2;
      missing.add('Full name (first and last)');
    } else {
      missing.add('Name');
    }

    // ── Gender (5 points) ───────────────────────────────────────────────────
    if (person.gender != null && person.gender!.isNotEmpty) {
      score += 5;
    } else {
      missing.add('Gender');
    }

    // ── Birth date (15 points) ──────────────────────────────────────────────
    if (person.birthDate != null) {
      score += 15;
    } else {
      missing.add('Birth date');
    }

    // ── Birth place (10 points) ─────────────────────────────────────────────
    if (person.birthPlace != null && person.birthPlace!.isNotEmpty) {
      score += 10;
    } else {
      missing.add('Birth place');
    }

    // ── Death date (10 points, only for deceased) ───────────────────────────
    if (person.deathDate != null) {
      score += 10;
    } else if (_isLikelyDeceased(person)) {
      missing.add('Death date');
    } else {
      score += 10; // Living person — no penalty
    }

    // ── Death place (5 points, only for deceased) ───────────────────────────
    if (person.deathPlace != null && person.deathPlace!.isNotEmpty) {
      score += 5;
    } else if (person.deathDate != null) {
      missing.add('Death place');
    } else {
      score += 5; // Living — no penalty
    }

    // ── Parents (15 points) ─────────────────────────────────────────────────
    if (person.parentIds.length >= 2) {
      score += 15;
    } else if (person.parentIds.length == 1) {
      score += 7;
      missing.add('Second parent');
    } else {
      missing.add('Parents');
    }

    // ── At least one source (15 points) ─────────────────────────────────────
    if (personSources.isNotEmpty) {
      score += 15;
      // Bonus: source with confidence A or B
      if (personSources.any(
          (s) => s.confidence == 'A' || s.confidence == 'B')) {
        score += 5; // quality source bonus
      } else {
        missing.add('Reliable source (rating A or B)');
      }
    } else {
      missing.add('Sources / citations');
    }

    // ── Photo (5 points) ────────────────────────────────────────────────────
    if (person.photoPaths.isNotEmpty) {
      score += 5;
    } else {
      missing.add('Photo');
    }

    // ── Optional extras (5 points total) ────────────────────────────────────
    double extras = 0;
    if (person.occupation != null && person.occupation!.isNotEmpty) extras++;
    if (person.nationality != null && person.nationality!.isNotEmpty) extras++;
    if (person.religion != null && person.religion!.isNotEmpty) extras++;
    if (person.education != null && person.education!.isNotEmpty) extras++;
    if (person.notes != null && person.notes!.isNotEmpty) extras++;
    score += (extras / 5.0) * 5.0;

    return PersonCompleteness(
      personId: person.id,
      personName: person.name,
      score: score.clamp(0, maxScore).round(),
      maxScore: maxScore.round(),
      missingItems: missing,
    );
  }

  /// Computes the average completeness across all persons in the tree.
  TreeCompleteness scoreTree(
    List<Person> persons, {
    required List<Source> allSources,
  }) {
    if (persons.isEmpty) {
      return const TreeCompleteness(
        averageScore: 0,
        totalPersons: 0,
        wellDocumented: 0,
        needsWork: 0,
        critical: 0,
        personScores: [],
      );
    }

    final personScores = <PersonCompleteness>[];
    for (final person in persons) {
      final personSources = allSources
          .where((s) =>
              s.personId == person.id || person.sourceIds.contains(s.id))
          .toList();
      personScores.add(scorePerson(
        person,
        personSources: personSources,
        allPersons: persons,
      ));
    }

    final avgScore =
        personScores.map((s) => s.score).reduce((a, b) => a + b) /
            personScores.length;

    return TreeCompleteness(
      averageScore: avgScore.round(),
      totalPersons: persons.length,
      wellDocumented: personScores.where((s) => s.score >= 70).length,
      needsWork: personScores
          .where((s) => s.score >= 40 && s.score < 70)
          .length,
      critical: personScores.where((s) => s.score < 40).length,
      personScores: personScores
        ..sort((a, b) => a.score.compareTo(b.score)), // worst first
    );
  }

  bool _isLikelyDeceased(Person person) {
    if (person.deathDate != null) return true;
    if (person.birthDate != null) {
      final age = DateTime.now().difference(person.birthDate!).inDays ~/ 365;
      return age > 110;
    }
    return false;
  }
}

/// Completeness result for a single person.
class PersonCompleteness {
  final String personId;
  final String personName;
  final int score;      // 0–100
  final int maxScore;
  final List<String> missingItems;

  const PersonCompleteness({
    required this.personId,
    required this.personName,
    required this.score,
    required this.maxScore,
    required this.missingItems,
  });

  String get grade {
    if (score >= 90) return 'A';
    if (score >= 80) return 'B';
    if (score >= 70) return 'C';
    if (score >= 60) return 'D';
    return 'F';
  }

  String get label {
    if (score >= 80) return 'Well Documented';
    if (score >= 60) return 'Good';
    if (score >= 40) return 'Needs Work';
    return 'Critical';
  }
}

/// Aggregate completeness for the entire tree.
class TreeCompleteness {
  final int averageScore;
  final int totalPersons;
  final int wellDocumented;
  final int needsWork;
  final int critical;
  final List<PersonCompleteness> personScores;

  const TreeCompleteness({
    required this.averageScore,
    required this.totalPersons,
    required this.wellDocumented,
    required this.needsWork,
    required this.critical,
    required this.personScores,
  });

  String get grade {
    if (averageScore >= 90) return 'A';
    if (averageScore >= 80) return 'B';
    if (averageScore >= 70) return 'C';
    if (averageScore >= 60) return 'D';
    return 'F';
  }
}
