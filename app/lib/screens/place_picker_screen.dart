import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/place.dart';
import '../providers/tree_provider.dart';

class PlacePickerScreen extends StatefulWidget {
  final DateTime? eventDate;

  const PlacePickerScreen({super.key, this.eventDate});

  @override
  State<PlacePickerScreen> createState() => _PlacePickerScreenState();
}

class _PlacePickerScreenState extends State<PlacePickerScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final colonizationLevel = context.watch<TreeProvider>().colonizationLevel;
    final filtered = TreeProvider.places
        .where((p) => p.name.toLowerCase().contains(_query.toLowerCase()) ||
            p.modernCountry.toLowerCase().contains(_query.toLowerCase()))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pick a Place'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
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
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
        ),
      ),
      body: filtered.isEmpty
          ? const Center(child: Text('No places match your search.'))
          : ListView.builder(
              itemCount: filtered.length,
              itemBuilder: (context, i) {
                final place = filtered[i];
                final fullName = place.getFullName(widget.eventDate);
                final info = place.getHistoricalInfo(
                    widget.eventDate, colonizationLevel, fullName);
                return ListTile(
                  leading: const Icon(Icons.location_on),
                  title: Text(fullName),
                  subtitle: Text(
                    info,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => Navigator.pop(context, place),
                );
              },
            ),
    );
  }
}
