import 'package:vector_math/vector_math_64.dart' hide Colors;
import 'package:flutter/material.dart';

/// Full-screen high-quality tree viewer / wall chart printable view.
///
/// Provides a dedicated zoomable and pannable view of the family tree
/// optimized for large screens, presentations, and export to PDF/images.
class WallChartScreen extends StatefulWidget {
  const WallChartScreen({super.key});

  @override
  State<WallChartScreen> createState() => _WallChartScreenState();
}

class _WallChartScreenState extends State<WallChartScreen> {
  final TransformationController _transformationController =
      TransformationController();
  
  // Customization options for the chart
  _ChartStyle _style = _ChartStyle.modern;
  _ChartOrientation _orientation = _ChartOrientation.vertical;
  bool _showDates = true;
  bool _showPlaces = true;
  bool _showPhotos = true;

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Printable Wall Chart'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Chart Settings',
            onPressed: _showSettingsDialog,
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Export as PDF',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('PDF Export coming soon.')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.print),
            tooltip: 'Print',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Printing coming soon.')),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // The zoomable canvas
          InteractiveViewer(
            transformationController: _transformationController,
            constrained: false, // allows infinite panning
            minScale: 0.1,
            maxScale: 3.0,
            boundaryMargin: const EdgeInsets.all(2000), // huge virtual space
            child: Container(
              color: _getCanvasColor(),
              width: 4000,
              height: 4000,
              child: Center(
                child: Text(
                  'Wall Chart Rendering Engine\n(In Development)',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 48,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                ),
                // TODO: Re-use the existing graph algorithm but render with 
                // the selected _style and _orientation using CustomPainter.
              ),
            ),
          ),
          
          // Controls overlay
          Positioned(
            bottom: 24,
            right: 24,
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove),
                      onPressed: () {
                        final currentScale =
                            _transformationController.value.getMaxScaleOnAxis();
                        if (currentScale > 0.2) {
                          _zoom(0.8); // Zoom out
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.fit_screen),
                      onPressed: () {
                        // Reset to identity
                        _transformationController.value = Matrix4.identity();
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () {
                        final currentScale =
                            _transformationController.value.getMaxScaleOnAxis();
                        if (currentScale < 2.5) {
                          _zoom(1.2); // Zoom in
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _zoom(double factor) {
    final matrix = _transformationController.value.clone();
    
    // Zoom relative to the center of the viewport
    final center = Offset(
      MediaQuery.of(context).size.width / 2,
      MediaQuery.of(context).size.height / 2,
    );
    
    // Translate to center, scale, translate back
    matrix.translateByVector3(Vector3(center.dx, center.dy, 0.0));
    matrix.scaleByVector3(Vector3(factor, factor, 1.0));
    matrix.translateByVector3(Vector3(-center.dx, -center.dy, 0.0));
    
    _transformationController.value = matrix;
  }
  
  Color _getCanvasColor() {
    switch (_style) {
      case _ChartStyle.parchment:
        return const Color(0xFFF5EACF);
      case _ChartStyle.blueprint:
        return const Color(0xFF1E3D59);
      case _ChartStyle.minimalist:
        return Colors.white;
      default:
        return Theme.of(context).scaffoldBackgroundColor;
    }
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog.adaptive(
          title: const Text('Chart Settings'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Visual Style',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                SegmentedButton<_ChartStyle>(
                  segments: const [
                    ButtonSegment(
                        value: _ChartStyle.modern, label: Text('Modern')),
                    ButtonSegment(
                        value: _ChartStyle.parchment, label: Text('Classic')),
                    ButtonSegment(
                        value: _ChartStyle.minimalist, label: Text('Clean')),
                  ],
                  selected: {_style},
                  onSelectionChanged: (s) {
                    setDialogState(() => _style = s.first);
                  },
                ),
                
                const SizedBox(height: 16),
                const Text('Orientation',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                SegmentedButton<_ChartOrientation>(
                  segments: const [
                    ButtonSegment(
                      value: _ChartOrientation.vertical,
                      icon: Icon(Icons.arrow_downward),
                    ),
                    ButtonSegment(
                      value: _ChartOrientation.horizontal,
                      icon: Icon(Icons.arrow_forward),
                    ),
                    ButtonSegment(
                      value: _ChartOrientation.circular,
                      icon: Icon(Icons.radio_button_unchecked),
                    ),
                  ],
                  selected: {_orientation},
                  onSelectionChanged: (s) {
                    setDialogState(() => _orientation = s.first);
                  },
                ),
                
                const SizedBox(height: 16),
                const Text('Information to Show',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                SwitchListTile(
                  title: const Text('Photos'),
                  value: _showPhotos,
                  onChanged: (v) => setDialogState(() => _showPhotos = v),
                ),
                SwitchListTile(
                  title: const Text('Dates (Birth/Death)'),
                  value: _showDates,
                  onChanged: (v) => setDialogState(() => _showDates = v),
                ),
                SwitchListTile(
                  title: const Text('Places'),
                  value: _showPlaces,
                  onChanged: (v) => setDialogState(() => _showPlaces = v),
                ),
              ],
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() {}); // Apply changes to main view
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }
}

enum _ChartStyle { modern, parchment, blueprint, minimalist }
enum _ChartOrientation { vertical, horizontal, circular, fan }
