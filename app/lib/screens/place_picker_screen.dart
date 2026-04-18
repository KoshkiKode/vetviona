import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/place.dart';
import '../providers/tree_provider.dart';
import '../services/geonames_service.dart';
import '../services/place_service.dart';
import '../utils/country_flag.dart';

class PlacePickerScreen extends StatefulWidget {
  final DateTime? eventDate;

  const PlacePickerScreen({super.key, this.eventDate});

  @override
  State<PlacePickerScreen> createState() => _PlacePickerScreenState();
}

class _PlacePickerScreenState extends State<PlacePickerScreen> {
  String _query = '';
  late Future<List<Place>> _placesFuture;
  Future<List<Place>>? _geonamesFuture;

  @override
  void initState() {
    super.initState();
    _placesFuture = PlaceService.instance.loadPlaces();
    // Kick off GeoNames DB init in background so it's ready when needed.
    GeonamesService.instance.init();
  }

  void _onQueryChanged(String v) {
    setState(() {
      _query = v;
      // Re-query GeoNames whenever the search text changes.
      _geonamesFuture = v.trim().length >= 2
          ? GeonamesService.instance.search(
              v.trim(),
              eventDate: widget.eventDate,
            )
          : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colonizationLevel = context.watch<TreeProvider>().colonizationLevel;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pick a Place'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 12.0,
              vertical: 8.0,
            ),
            child: TextField(
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search places\u2026',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: _onQueryChanged,
            ),
          ),
        ),
      ),
      body: FutureBuilder<List<Place>>(
        future: _placesFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator.adaptive());
          }

          final filtered = PlaceService.instance.search(
            _query,
            eventDate: widget.eventDate,
          );

          return FutureBuilder<List<Place>>(
            future: _geonamesFuture,
            builder: (context, geoSnap) {
              // Collect GeoNames results, deduplicating against compiled results.
              final compiledNames = filtered
                  .map((p) => p.name.toLowerCase())
                  .toSet();
              final geoResults = (geoSnap.data ?? <Place>[])
                  .where((p) => !compiledNames.contains(p.name.toLowerCase()))
                  .toList();

              // Build combined item list:
              //   [compiled results...]
              //   [optional GeoNames header + results...]
              final int compiledCount = filtered.length;
              final bool hasGeo = geoResults.isNotEmpty;
              final int totalItems =
                  compiledCount + (hasGeo ? 1 + geoResults.length : 0);

              if (totalItems == 0) {
                return const Center(
                  child: Text('No places match your search.'),
                );
              }

              return ListView.builder(
                itemCount: totalItems,
                itemBuilder: (context, i) {
                  // ── compiled results ──────────────────────────────────────
                  if (i < compiledCount) {
                    return _placeTile(filtered[i], colonizationLevel, context);
                  }

                  // ── GeoNames section header ───────────────────────────────
                  if (i == compiledCount) {
                    return _sectionHeader(
                      context,
                      Icons.public,
                      'Global city database',
                    );
                  }

                  // ── GeoNames results ──────────────────────────────────────
                  return _placeTile(
                    geoResults[i - compiledCount - 1],
                    colonizationLevel,
                    context,
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _placeTile(Place place, int colonizationLevel, BuildContext context) {
    final fullName = place.getFullName(widget.eventDate);
    final info = place.getHistoricalInfo(
      widget.eventDate,
      colonizationLevel,
      fullName,
    );
    return ListTile(
      leading: Text(
        countryFlagEmojiFromIso3(place.iso3),
        style: const TextStyle(fontSize: 22),
      ),
      title: Text(fullName),
      subtitle: info.isEmpty
          ? null
          : Text(info, maxLines: 2, overflow: TextOverflow.ellipsis),
      onTap: () => Navigator.pop(context, place),
    );
  }

  Widget _sectionHeader(BuildContext context, IconData icon, String label) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      color: cs.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: cs.onSurfaceVariant),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
