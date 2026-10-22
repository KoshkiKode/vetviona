import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/place.dart';
import '../providers/tree_provider.dart';
import '../services/geonames_service.dart';
import '../services/place_service.dart';
import '../utils/country_flag.dart';

class PlaceAutocompleteField extends StatefulWidget {
  final TextEditingController controller;
  final String labelText;
  final DateTime? eventDate;
  final String? helperText;
  final Widget? icon;

  const PlaceAutocompleteField({
    super.key,
    required this.controller,
    required this.labelText,
    this.eventDate,
    this.helperText,
    this.icon,
  });

  @override
  State<PlaceAutocompleteField> createState() => _PlaceAutocompleteFieldState();
}

class _PlaceAutocompleteFieldState extends State<PlaceAutocompleteField> {
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    PlaceService.instance.loadPlaces();
    GeonamesService.instance.init();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  Future<List<Place>> _getSuggestions(String query) async {
    if (query.trim().length < 2) {
      return [];
    }

    final filtered = PlaceService.instance.search(
      query,
      eventDate: widget.eventDate,
    );

    final compiledNames = filtered.map((p) => p.name.toLowerCase()).toSet();

    final geoSnap = await GeonamesService.instance.search(
      query.trim(),
      eventDate: widget.eventDate,
    );

    final geoResults = geoSnap
        .where((p) => !compiledNames.contains(p.name.toLowerCase()))
        .toList();

    return [...filtered, ...geoResults];
  }

  @override
  Widget build(BuildContext context) {
    final colonizationLevel = context.watch<TreeProvider>().colonizationLevel;

    return LayoutBuilder(
      builder: (context, constraints) => RawAutocomplete<Place>(
        textEditingController: widget.controller,
        focusNode: _focusNode,
        optionsBuilder: (TextEditingValue textEditingValue) {
          return _getSuggestions(textEditingValue.text);
        },
        displayStringForOption: (Place option) =>
            option.getFullName(widget.eventDate),
        onSelected: (Place selection) {
          // Do nothing specific, the controller updates automatically
        },
        fieldViewBuilder: (
          BuildContext context,
          TextEditingController textEditingController,
          FocusNode focusNode,
          VoidCallback onFieldSubmitted,
        ) {
          return TextFormField(
            controller: textEditingController,
            focusNode: focusNode,
            onFieldSubmitted: (String value) {
              onFieldSubmitted();
            },
            decoration: InputDecoration(
              labelText: widget.labelText,
              helperText: widget.helperText,
              icon: widget.icon,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          );
        },
        optionsViewBuilder: (
          BuildContext context,
          AutocompleteOnSelected<Place> onSelected,
          Iterable<Place> options,
        ) {
          return Align(
            alignment: Alignment.topLeft,
            child: Material(
              elevation: 4.0,
              borderRadius: BorderRadius.circular(8.0),
              child: SizedBox(
                width: constraints.maxWidth,
                // Restrict the dropdown height
                height: 300,
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  itemCount: options.length,
                  itemBuilder: (BuildContext context, int index) {
                    final Place option = options.elementAt(index);
                    final fullName = option.getFullName(widget.eventDate);
                    final info = option.getHistoricalInfo(
                        widget.eventDate, colonizationLevel, fullName);
                    
                    return InkWell(
                      onTap: () {
                        onSelected(option);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16.0, vertical: 12.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              countryFlagEmojiFromIso3(option.iso3),
                              style: const TextStyle(fontSize: 24),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    fullName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  if (info.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      info,
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 12,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ]
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
