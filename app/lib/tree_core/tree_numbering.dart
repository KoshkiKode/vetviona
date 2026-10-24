/// One ancestor in a Sosa-Stradonitz (ahnentafel) list.
class SosaEntry {
  const SosaEntry({
    required this.number,
    required this.personId,
    required this.generation,
  });

  final int number;
  final String personId;
  final int generation;
}

/// Sosa-Stradonitz numbering. The root is 1; the father of `n` is `2n` and the
/// mother is `2n+1`. [parentsOf] must return parents in order: index 0 is the
/// father, index 1 the mother. Missing parents leave gaps in the numbering.
///
/// Walks breadth-first with an explicit queue and stops at [maxGenerations]
/// (capped at 16) and at 65,536 entries, so cyclic data cannot run away.
List<SosaEntry> sosaNumbering(
  String rootId,
  List<String> Function(String personId) parentsOf, {
  int maxGenerations = 10,
}) {
  final limit = maxGenerations.clamp(0, 16);
  final queue = <(int, String, int)>[(1, rootId, 0)];
  final entries = <SosaEntry>[];
  for (var i = 0; i < queue.length && entries.length < 65536; i++) {
    final (number, id, generation) = queue[i];
    entries.add(SosaEntry(
      number: number,
      personId: id,
      generation: generation,
    ));
    if (generation >= limit) continue;
    final parents = parentsOf(id);
    if (parents.isNotEmpty) queue.add((2 * number, parents[0], generation + 1));
    if (parents.length > 1) {
      queue.add((2 * number + 1, parents[1], generation + 1));
    }
  }
  entries.sort((a, b) => a.number.compareTo(b.number));
  return entries;
}
