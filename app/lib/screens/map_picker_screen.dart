import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/geo_coord.dart';
import '../services/nominatim_service.dart';

/// A full-screen map picker that lets the user:
/// 1. Tap anywhere on the OpenStreetMap to drop a pin.
/// 2. Search for a place by name (forward geocoding).
/// 3. See the reverse-geocoded address, political boundaries, and postal code.
/// 4. Confirm the selection — returns a [GeoCoord] to the caller.
///
/// Returns `null` when the user presses back or Clear without confirming.
class MapPickerScreen extends StatefulWidget {
  /// Pre-selected coordinate to show when the screen opens (optional).
  final GeoCoord? initialCoord;

  const MapPickerScreen({super.key, this.initialCoord});

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  static const _defaultCenter = LatLng(20.0, 0.0);
  static const _defaultZoom = 2.0;
  static const _pinZoom = 13.0;

  final _mapController = MapController();
  final _searchController = TextEditingController();

  LatLng? _pinLocation;
  GeoCoord? _geocoded;
  bool _geocoding = false;
  List<GeoCoord> _searchResults = [];
  bool _searching = false;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    if (widget.initialCoord != null) {
      _pinLocation = LatLng(
        widget.initialCoord!.lat,
        widget.initialCoord!.lng,
      );
      _geocoded = widget.initialCoord;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchDebounce?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  // ── Geocoding ──────────────────────────────────────────────────────────────

  Future<void> _reverseGeocode(LatLng point) async {
    setState(() {
      _pinLocation = point;
      _geocoding = true;
      _geocoded = null;
      _searchResults = [];
    });
    final result = await NominatimService.instance
        .reverseGeocode(point.latitude, point.longitude);
    if (!mounted) return;
    setState(() {
      _geocoded = result;
      _geocoding = false;
    });
  }

  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 600), () async {
      if (!mounted) return;
      setState(() => _searching = true);
      final results = await NominatimService.instance.search(query);
      if (!mounted) return;
      setState(() {
        _searchResults = results;
        _searching = false;
      });
    });
  }

  void _selectSearchResult(GeoCoord coord) {
    final point = LatLng(coord.lat, coord.lng);
    setState(() {
      _pinLocation = point;
      _geocoded = coord;
      _searchResults = [];
      _searchController.clear();
    });
    _mapController.move(point, _pinZoom);
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  void _confirmSelection() {
    Navigator.pop(context, _geocoded ?? (_pinLocation == null
        ? null
        : GeoCoord(lat: _pinLocation!.latitude, lng: _pinLocation!.longitude)));
  }

  void _clearSelection() {
    setState(() {
      _pinLocation = null;
      _geocoded = null;
      _searchResults = [];
      _searchController.clear();
    });
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final initialCenter = _pinLocation ?? _defaultCenter;
    final initialZoom = _pinLocation != null ? _pinZoom : _defaultZoom;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pick a Place'),
        actions: [
          if (_pinLocation != null)
            TextButton.icon(
              icon: Icon(Icons.close, color: colorScheme.onPrimary),
              label: Text('Clear',
                  style: TextStyle(color: colorScheme.onPrimary)),
              onPressed: _clearSelection,
            ),
          if (_pinLocation != null)
            TextButton.icon(
              icon: Icon(Icons.check, color: colorScheme.onPrimary),
              label: Text('Confirm',
                  style: TextStyle(color: colorScheme.onPrimary)),
              onPressed: _confirmSelection,
            ),
        ],
      ),
      body: Stack(
        children: [
          // ── Map ─────────────────────────────────────────────────────────
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: initialCenter,
              initialZoom: initialZoom,
              onTap: (tapPosition, point) => _reverseGeocode(point),
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'app.vetviona.vetviona_app',
                // Attribution required by OSM tile usage policy
                additionalOptions: const {},
              ),
              if (_pinLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _pinLocation!,
                      width: 40,
                      height: 40,
                      child: Icon(
                        Icons.location_pin,
                        color: colorScheme.error,
                        size: 40,
                      ),
                    ),
                  ],
                ),
            ],
          ),

          // ── OSM attribution (required by tile usage policy) ──────────────
          Positioned(
            bottom: _pinLocation != null ? 172 : 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                '© OpenStreetMap contributors',
                style: TextStyle(fontSize: 9, color: Colors.black87),
              ),
            ),
          ),

          // ── Search bar ───────────────────────────────────────────────────
          Positioned(
            top: 8,
            left: 12,
            right: 12,
            child: Column(
              children: [
                Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(28),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search for a place…',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searching
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator.adaptive(),
                              ),
                            )
                          : _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchResults = []);
                                  },
                                )
                              : null,
                      filled: true,
                      fillColor: colorScheme.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(28),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 0),
                    ),
                    onChanged: _onSearchChanged,
                  ),
                ),
                if (_searchResults.isNotEmpty)
                  Material(
                    elevation: 4,
                    borderRadius: BorderRadius.circular(12),
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount:
                          _searchResults.length.clamp(0, 6),
                      itemBuilder: (context, i) {
                        final r = _searchResults[i];
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.location_on, size: 18),
                          title: Text(
                            r.shortLabel,
                            style: const TextStyle(fontSize: 13),
                          ),
                          subtitle: r.displayName != null
                              ? Text(
                                  r.displayName!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 11),
                                )
                              : null,
                          onTap: () => _selectSearchResult(r),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),

          // ── Bottom info panel ────────────────────────────────────────────
          if (_pinLocation != null || _geocoding)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _InfoPanel(
                geocoded: _geocoded,
                geocoding: _geocoding,
                onConfirm: _confirmSelection,
                colorScheme: colorScheme,
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Info panel — shown at the bottom once a pin is placed
// ─────────────────────────────────────────────────────────────────────────────

class _InfoPanel extends StatelessWidget {
  final GeoCoord? geocoded;
  final bool geocoding;
  final VoidCallback onConfirm;
  final ColorScheme colorScheme;

  const _InfoPanel({
    required this.geocoded,
    required this.geocoding,
    required this.onConfirm,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      child: geocoding
          ? const SizedBox(
              height: 60,
              child: Center(child: CircularProgressIndicator.adaptive()),
            )
          : geocoded == null
              ? const SizedBox(
                  height: 60,
                  child: Center(
                    child: Text('Tap anywhere on the map to place a pin'),
                  ),
                )
              : _GeocodedDetails(
                  geocoded: geocoded!,
                  onConfirm: onConfirm,
                  colorScheme: colorScheme,
                ),
    );
  }
}

class _GeocodedDetails extends StatelessWidget {
  final GeoCoord geocoded;
  final VoidCallback onConfirm;
  final ColorScheme colorScheme;

  const _GeocodedDetails({
    required this.geocoded,
    required this.onConfirm,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Coordinates ──────────────────────────────────────────────────
        Row(
          children: [
            Icon(Icons.my_location,
                size: 14, color: colorScheme.primary),
            const SizedBox(width: 6),
            Text(
              geocoded.coordinateLabel,
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),

        // ── Display name ─────────────────────────────────────────────────
        if (geocoded.displayName != null) ...[
          Text(
            geocoded.displayName!,
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurfaceVariant,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
        ],

        // ── Political boundaries ─────────────────────────────────────────
        if (geocoded.politicalBoundaries.isNotEmpty) ...[
          _BoundaryRow(
            icon: Icons.account_balance_outlined,
            label: 'Political boundaries',
            value: geocoded.politicalBoundaries,
            colorScheme: colorScheme,
          ),
          const SizedBox(height: 4),
        ],

        // ── Postal code ──────────────────────────────────────────────────
        if (geocoded.postalCode != null &&
            geocoded.postalCode!.isNotEmpty) ...[
          _BoundaryRow(
            icon: Icons.local_post_office_outlined,
            label: 'Postal code',
            value: geocoded.postalCode!,
            colorScheme: colorScheme,
          ),
          const SizedBox(height: 4),
        ],

        // ── Country code ─────────────────────────────────────────────────
        if (geocoded.countryCode != null) ...[
          _BoundaryRow(
            icon: Icons.flag_outlined,
            label: 'Country code',
            value: geocoded.countryCode!,
            colorScheme: colorScheme,
          ),
          const SizedBox(height: 8),
        ] else
          const SizedBox(height: 8),

        // ── Confirm button ───────────────────────────────────────────────
        FilledButton.icon(
          icon: const Icon(Icons.check),
          label: const Text('Use this location'),
          onPressed: onConfirm,
        ),
      ],
    );
  }
}

class _BoundaryRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final ColorScheme colorScheme;

  const _BoundaryRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: colorScheme.primary),
        const SizedBox(width: 6),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(
                  fontSize: 12, color: colorScheme.onSurfaceVariant),
              children: [
                TextSpan(
                  text: '$label: ',
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
                TextSpan(
                  text: value,
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
