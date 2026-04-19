import 'dart:math' show max;

import '../models/person.dart';

/// Generates and formats human-readable "short" person IDs.
///
/// ## Format
///
/// Each person is assigned a short ID of the form `FL-001` where:
/// - `F` is the first letter of the person's first name.
/// - `L` is the first letter of the person's last name (or `F` again for
///   single-word names).
/// - The number is a sequential counter within the `FL` bucket, stored
///   zero-padded to three digits (`001`–`999`).
///
/// ## Display format
///
/// The **stored** value always uses three digits (e.g. `JD-007`).  The
/// **displayed** value strips leading zeros while the bucket has ≤ 99 entries,
/// so the 99 people `JD-001`…`JD-099` are shown as `JD-1`…`JD-99`.  Once
/// the 100th person with those initials is added, every entry in the bucket
/// switches to the three-digit form: `JD-001`, `JD-010`, `JD-099`, `JD-100`.
class PersonIdService {
  PersonIdService._();

  static final PersonIdService instance = PersonIdService._();

  // ── Initials ───────────────────────────────────────────────────────────────

  /// Extracts the two-letter initials prefix from a person's name.
  ///
  /// - `"John Doe"` → `"JD"`
  /// - `"Mary Ann Smith"` → `"MS"` (first word first letter, last word first letter)
  /// - `"Madonna"` (single word) → `"MM"` (first letter used for both)
  String initials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'XX';
    final words = trimmed
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    final first = _firstLetter(words.first);
    final last = words.length > 1 ? _firstLetter(words.last) : first;
    return '$first$last';
  }

  /// Returns the first ASCII letter from [word], uppercased, or `'X'` if none.
  String _firstLetter(String word) {
    for (final codeUnit in word.codeUnits) {
      final ch = String.fromCharCode(codeUnit).toUpperCase();
      if (RegExp(r'^[A-Z]$').hasMatch(ch)) return ch;
    }
    return 'X';
  }

  // ── Generation ─────────────────────────────────────────────────────────────

  /// Generates the next available short ID for a person named [name] given
  /// [existingPersons].
  ///
  /// The counter is assigned as `max(existing) + 1`, starting at 1.
  /// If the bucket is exhausted (> 999), it wraps back to the first unused
  /// slot starting from 1.
  String generate(String name, List<Person> existingPersons) {
    final prefix = initials(name);
    final existing = _numbersInBucket(prefix, existingPersons);

    int next = 1;
    if (existing.isNotEmpty) {
      next = existing.reduce(max) + 1;
    }

    // If we go beyond 999, find the first unused slot from 1.
    if (next > 999) {
      final usedSet = existing.toSet();
      next = 1;
      while (usedSet.contains(next) && next <= 999) {
        next++;
      }
      if (next > 999) next = 1; // pathological: just wrap
    }

    return '$prefix-${next.toString().padLeft(3, '0')}';
  }

  // ── Display ────────────────────────────────────────────────────────────────

  /// Returns the user-facing display string for [shortId] given [allPersons].
  ///
  /// Returns an empty string when [shortId] is null or blank.
  ///
  /// **Display rules:**
  /// - Bucket size ≤ 99 → strip leading zeros: `JD-7`, `JD-42`, `JD-99`.
  /// - Bucket size ≥ 100 → keep 3-digit format: `JD-001`, `JD-099`, `JD-100`.
  String display(String? shortId, List<Person> allPersons) {
    if (shortId == null || shortId.isEmpty) return '';
    final dashIdx = shortId.lastIndexOf('-');
    if (dashIdx < 0) return shortId;
    final prefix = shortId.substring(0, dashIdx);
    final numStr = shortId.substring(dashIdx + 1);
    final num = int.tryParse(numStr);
    if (num == null) return shortId;

    final bucketSize = _numbersInBucket(prefix, allPersons).length;

    if (bucketSize >= 100) {
      return '$prefix-${numStr.padLeft(3, '0')}';
    } else {
      return '$prefix-$num';
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Returns all numeric counters for short IDs in the given [prefix] bucket
  /// (`<prefix>-NNN`) across [persons].
  List<int> _numbersInBucket(String prefix, List<Person> persons) {
    final pattern = RegExp('^${RegExp.escape(prefix)}-(\\d{3})\$');
    final nums = <int>[];
    for (final p in persons) {
      final sid = p.shortId;
      if (sid == null) continue;
      final m = pattern.firstMatch(sid);
      if (m != null) {
        final n = int.tryParse(m.group(1)!);
        if (n != null) nums.add(n);
      }
    }
    return nums;
  }
}
