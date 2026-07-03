import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';



import '../providers/tree_provider.dart';
import '../models/person.dart';
import '../models/partnership.dart';
import 'tree_layout.dart';
import 'fan_chart_screen.dart'; 

class WallChartScreen extends StatefulWidget {
  const WallChartScreen({super.key});

  @override
  State<WallChartScreen> createState() => _WallChartScreenState();
}

enum _ChartStyle { modern, parchment, blueprint, minimalist }
enum _ChartOrientation { vertical, horizontal, fan }

class _WallChartScreenState extends State<WallChartScreen> {
  final TransformationController _transformationController =
      TransformationController();
  
  _ChartStyle _style = _ChartStyle.modern;
  _ChartOrientation _orientation = _ChartOrientation.vertical;
  bool _showPhotos = true;
  bool _showDates = true;
  bool _showPlaces = true;

  TreeLayout? _cachedLayout;
  int _cachedPersonsLen = -1;
  int _cachedPartnershipsLen = -1;

  @override
  Widget build(BuildContext context) {
    if (_orientation == _ChartOrientation.fan) {
      // Direct integration of Fan Chart if selected
      return Scaffold(
        appBar: AppBar(
          title: const Text('Fan Chart'),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings),
              tooltip: 'Chart Settings',
              onPressed: _showSettingsDialog,
            ),
          ],
        ),
        body: const FanChartScreen(),
      );
    }

    final provider = context.watch<TreeProvider>();
    final colorScheme = Theme.of(context).colorScheme;

    // Cache layout to avoid recomputing on every frame/zoom
    if (_cachedLayout == null ||
        _cachedPersonsLen != provider.persons.length ||
        _cachedPartnershipsLen != provider.partnerships.length) {
      _cachedPersonsLen = provider.persons.length;
      _cachedPartnershipsLen = provider.partnerships.length;
      
      final config = const TreeLayoutConfig(
        nodeWidth: 200.0,
        nodeHeight: 100.0,
        colGap: 60.0,
        rowGap: 80.0,
      );
      _cachedLayout = TreeLayout(provider.persons, provider.partnerships, config);
    }

    final layout = _cachedLayout!;
    
    // If horizontal, swap x and y bounds
    final isHorizontal = _orientation == _ChartOrientation.horizontal;
    final canvasWidth = isHorizontal ? layout.canvasSize.height : layout.canvasSize.width;
    final canvasHeight = isHorizontal ? layout.canvasSize.width : layout.canvasSize.height;

    // We add some padding around the whole canvas so nodes aren't flush to the edge
    final paddedCanvasWidth = canvasWidth + 1000;
    final paddedCanvasHeight = canvasHeight + 1000;

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
            onPressed: () => _exportToPdf(provider, layout, isHorizontal),
          ),
          IconButton(
            icon: const Icon(Icons.print),
            tooltip: 'Print',
            onPressed: () => _printPdf(provider, layout, isHorizontal),
          ),
        ],
      ),
      body: Stack(
        children: [
          // The zoomable canvas
          InteractiveViewer(
            transformationController: _transformationController,
            constrained: false, 
            minScale: 0.05,
            maxScale: 3.0,
            boundaryMargin: const EdgeInsets.all(4000), // huge virtual space
            child: Container(
              color: _getCanvasColor(),
              width: paddedCanvasWidth,
              height: paddedCanvasHeight,
              child: Center(
                child: SizedBox(
                  width: canvasWidth,
                  height: canvasHeight,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Edges
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _WallChartEdgePainter(
                            nodes: layout.nodes,
                            edges: layout.edges,
                            edgeColor: _getLineColor(),
                            isHorizontal: isHorizontal,
                            nodeWidth: layout.config.nodeWidth,
                            nodeHeight: layout.config.nodeHeight,
                          ),
                        ),
                      ),
                      // Nodes
                      for (final nodeInfo in layout.nodes.values)
                        if (!nodeInfo.isCoupleKnot)
                          _buildNodeWidget(nodeInfo, provider.persons.where((p) => p.id == nodeInfo.id).firstOrNull, layout.config, isHorizontal)
                    ],
                  ),
                ),
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
                        final currentScale = _transformationController.value.getMaxScaleOnAxis();
                        if (currentScale > 0.1) _zoom(0.8);
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.fit_screen),
                      onPressed: () {
                        _transformationController.value = Matrix4.identity();
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () {
                        final currentScale = _transformationController.value.getMaxScaleOnAxis();
                        if (currentScale < 2.5) _zoom(1.2);
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

  Widget _buildNodeWidget(TreeNodeInfo nodeInfo, Person? person, TreeLayoutConfig config, bool isHorizontal) {
    if (person == null) return const SizedBox.shrink();
    
    // In horizontal mode, the x and y coordinates are swapped.
    final top = isHorizontal ? nodeInfo.x : nodeInfo.y;
    final left = isHorizontal ? nodeInfo.y : nodeInfo.x;
    
    return Positioned(
      top: top,
      left: left,
      width: config.nodeWidth,
      height: config.nodeHeight,
      child: Container(
        decoration: _getNodeDecoration(),
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              person.name,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: _getTextColor(),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (_showDates && (person.birthDate != null || person.deathDate != null))
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  '${person.birthDate ?? '?'} - ${person.deathDate ?? '?'}',
                  style: TextStyle(fontSize: 10, color: _getTextColor().withValues(alpha: 0.8)),
                ),
              ),
            if (_showPlaces && (person.birthPlace != null))
              Padding(
                padding: const EdgeInsets.only(top: 2.0),
                child: Text(
                  person.birthPlace!,
                  style: TextStyle(fontSize: 9, color: _getTextColor().withValues(alpha: 0.6)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
    );
  }

  BoxDecoration _getNodeDecoration() {
    switch (_style) {
      case _ChartStyle.parchment:
        return BoxDecoration(
          color: const Color(0xFFFDF7E7),
          border: Border.all(color: const Color(0xFF8B5A2B), width: 2),
          borderRadius: BorderRadius.circular(4),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(2, 2))],
        );
      case _ChartStyle.blueprint:
        return BoxDecoration(
          color: const Color(0xFF234B6E),
          border: Border.all(color: Colors.white70, width: 1.5),
          borderRadius: BorderRadius.circular(0),
        );
      case _ChartStyle.minimalist:
        return BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.black12, width: 1),
          borderRadius: BorderRadius.circular(8),
        );
      case _ChartStyle.modern:
      default:
        return BoxDecoration(
          color: Theme.of(context).cardColor,
          border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5), width: 2),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).shadowColor.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ],
        );
    }
  }

  Color _getTextColor() {
    switch (_style) {
      case _ChartStyle.parchment:
        return const Color(0xFF3E2723);
      case _ChartStyle.blueprint:
        return Colors.white;
      case _ChartStyle.minimalist:
        return Colors.black87;
      case _ChartStyle.modern:
      default:
        return Theme.of(context).colorScheme.onSurface;
    }
  }

  Color _getLineColor() {
    switch (_style) {
      case _ChartStyle.parchment:
        return const Color(0xFF8B5A2B);
      case _ChartStyle.blueprint:
        return Colors.white70;
      case _ChartStyle.minimalist:
        return Colors.black26;
      case _ChartStyle.modern:
      default:
        return Theme.of(context).colorScheme.outline;
    }
  }

  void _zoom(double factor) {
    final matrix = _transformationController.value.clone();
    final center = Offset(
      MediaQuery.of(context).size.width / 2,
      MediaQuery.of(context).size.height / 2,
    );
    matrix.translate(center.dx, center.dy);
    matrix.scale(factor);
    matrix.translate(-center.dx, -center.dy);
    _transformationController.value = matrix;
  }
  
  Color _getCanvasColor() {
    switch (_style) {
      case _ChartStyle.parchment:
        return const Color(0xFFF5EACF);
      case _ChartStyle.blueprint:
        return const Color(0xFF1E3D59);
      case _ChartStyle.minimalist:
        return const Color(0xFFF8F9FA);
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
                const Text('Visual Style', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                SegmentedButton<_ChartStyle>(
                  segments: const [
                    ButtonSegment(value: _ChartStyle.modern, label: Text('Modern')),
                    ButtonSegment(value: _ChartStyle.parchment, label: Text('Classic')),
                    ButtonSegment(value: _ChartStyle.blueprint, label: Text('Blueprint')),
                    ButtonSegment(value: _ChartStyle.minimalist, label: Text('Minimal')),
                  ],
                  selected: {_style},
                  onSelectionChanged: (s) {
                    setDialogState(() => _style = s.first);
                  },
                ),
                
                const SizedBox(height: 16),
                const Text('Orientation', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                SegmentedButton<_ChartOrientation>(
                  segments: const [
                    ButtonSegment(
                      value: _ChartOrientation.vertical,
                      icon: Icon(Icons.account_tree),
                      label: Text('Tree'),
                    ),
                    ButtonSegment(
                      value: _ChartOrientation.horizontal,
                      icon: Icon(Icons.account_tree, /* need to rotate in real app but standard icon fine */),
                      label: Text('Pedigree'),
                    ),
                    ButtonSegment(
                      value: _ChartOrientation.fan,
                      icon: Icon(Icons.data_usage),
                      label: Text('Fan'),
                    ),
                  ],
                  selected: {_orientation},
                  onSelectionChanged: (s) {
                    setDialogState(() => _orientation = s.first);
                  },
                ),
                
                const SizedBox(height: 16),
                const Text('Information to Show', style: TextStyle(fontWeight: FontWeight.bold)),
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

  // --- PDF Export Logic ---

  Future<void> _exportToPdf(TreeProvider provider, TreeLayout layout, bool isHorizontal) async {
    final pdfBytes = await _generatePdfDocument(provider, layout, isHorizontal);
    await Printing.sharePdf(bytes: pdfBytes, filename: 'family_tree_chart.pdf');
  }

  Future<void> _printPdf(TreeProvider provider, TreeLayout layout, bool isHorizontal) async {
    final pdfBytes = await _generatePdfDocument(provider, layout, isHorizontal);
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdfBytes);
  }

  Future<Uint8List> _generatePdfDocument(TreeProvider provider, TreeLayout layout, bool isHorizontal) async {
    final pdf = pw.Document();

    final canvasWidth = isHorizontal ? layout.canvasSize.height : layout.canvasSize.width;
    final canvasHeight = isHorizontal ? layout.canvasSize.width : layout.canvasSize.height;
    
    // We create a page sized exactly to fit the entire tree
    final pageFormat = PdfPageFormat(canvasWidth + 200, canvasHeight + 200, marginAll: 100);

    pdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
        build: (pw.Context context) {
          return pw.SizedBox(
            width: canvasWidth,
            height: canvasHeight,
            child: pw.Stack(
              children: [
                // Render edges using pdf canvas
                pw.Positioned.fill(
                  child: pw.CustomPaint(
                    painter: (canvas, size) {
                      _drawPdfEdges(canvas, layout, isHorizontal);
                    },
                  ),
                ),
                // Render nodes
                for (final nodeInfo in layout.nodes.values)
                  if (!nodeInfo.isCoupleKnot)
                    _buildPdfNodeWidget(nodeInfo, provider.persons.where((p) => p.id == nodeInfo.id).firstOrNull, layout.config, isHorizontal)
              ],
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  void _drawPdfEdges(dynamic canvas, TreeLayout layout, bool isHorizontal) {
    // Determine color based on style
    final PdfColor color;
    switch (_style) {
      case _ChartStyle.parchment: color = const PdfColor.fromInt(0xFF8B5A2B); break;
      case _ChartStyle.blueprint: color = const PdfColor.fromInt(0xFFFFFFFF); break;
      case _ChartStyle.minimalist: color = const PdfColor.fromInt(0xFFCCCCCC); break;
      default: color = const PdfColor.fromInt(0xFF000000); break;
    }

    final nw = layout.config.nodeWidth;
    final nh = layout.config.nodeHeight;

    canvas.setStrokeColor(color);
    canvas.setLineWidth(2.0);

    for (final edge in layout.edges) {
      final fromInfo = layout.nodes[edge.from];
      final toInfo = layout.nodes[edge.to];
      if (fromInfo == null || toInfo == null) continue;

      double x1, y1, x2, y2;
      
      if (!isHorizontal) {
        // Vertical layout
        if (edge.isCouple) {
          x1 = fromInfo.x + nw;
          y1 = fromInfo.y + nh / 2;
          x2 = toInfo.x;
          y2 = toInfo.y + nh / 2;
          canvas.drawLine(x1, y1, x2, y2);
        } else {
          x1 = fromInfo.x + nw / 2;
          y1 = fromInfo.y + nh;
          x2 = toInfo.x + nw / 2;
          y2 = toInfo.y;
          final midY = (y1 + y2) / 2;
          canvas.drawLine(x1, y1, x1, midY);
          canvas.drawLine(x1, midY, x2, midY);
          canvas.drawLine(x2, midY, x2, y2);
        }
      } else {
        // Horizontal layout
        if (edge.isCouple) {
          x1 = fromInfo.y + nw / 2;
          y1 = fromInfo.x + nh;
          x2 = toInfo.y + nw / 2;
          y2 = toInfo.x;
          canvas.drawLine(x1, y1, x2, y2);
        } else {
          x1 = fromInfo.y + nw;
          y1 = fromInfo.x + nh / 2;
          x2 = toInfo.y;
          y2 = toInfo.x + nh / 2;
          final midX = (x1 + x2) / 2;
          canvas.drawLine(x1, y1, midX, y1);
          canvas.drawLine(midX, y1, midX, y2);
          canvas.drawLine(midX, y2, x2, y2);
        }
      }
    }
    canvas.strokePath();
  }

  pw.Widget _buildPdfNodeWidget(TreeNodeInfo nodeInfo, Person? person, TreeLayoutConfig config, bool isHorizontal) {
    if (person == null) return pw.SizedBox();
    
    final top = isHorizontal ? nodeInfo.x : nodeInfo.y;
    final left = isHorizontal ? nodeInfo.y : nodeInfo.x;
    
    PdfColor bgColor, borderColor, textColor;
    switch (_style) {
      case _ChartStyle.parchment:
        bgColor = const PdfColor.fromInt(0xFFFDF7E7);
        borderColor = const PdfColor.fromInt(0xFF8B5A2B);
        textColor = const PdfColor.fromInt(0xFF3E2723);
        break;
      case _ChartStyle.blueprint:
        bgColor = const PdfColor.fromInt(0xFF234B6E);
        borderColor = const PdfColor.fromInt(0xFFFFFFFF);
        textColor = const PdfColor.fromInt(0xFFFFFFFF);
        break;
      case _ChartStyle.minimalist:
        bgColor = const PdfColor.fromInt(0xFFFFFFFF);
        borderColor = const PdfColor.fromInt(0xFFE0E0E0);
        textColor = const PdfColor.fromInt(0xFF000000);
        break;
      default:
        bgColor = const PdfColor.fromInt(0xFFFFFFFF);
        borderColor = const PdfColor.fromInt(0xFF000000);
        textColor = const PdfColor.fromInt(0xFF000000);
        break;
    }

    return pw.Positioned(
      top: top,
      left: left,
      child: pw.SizedBox(
        width: config.nodeWidth,
        height: config.nodeHeight,
        child: pw.Container(
        decoration: pw.BoxDecoration(
          color: bgColor,
          border: pw.Border.all(color: borderColor, width: 2),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
        ),
        padding: const pw.EdgeInsets.all(8),
        child: pw.Column(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Text(
              person.name,
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 14,
                color: textColor,
              ),
            ),
            if (_showDates && (person.birthDate != null || person.deathDate != null))
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 4.0),
                child: pw.Text(
                  '${person.birthDate ?? '?'} - ${person.deathDate ?? '?'}',
                  style: pw.TextStyle(fontSize: 10, color: textColor),
                ),
              ),
            if (_showPlaces && (person.birthPlace != null))
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 2.0),
                child: pw.Text(
                  person.birthPlace!,
                  style: pw.TextStyle(fontSize: 9, color: textColor),
                ),
              ),
          ],
        ),
      ),
      ),
    );
  }
}

// Custom Painter for drawing the connecting lines in Flutter UI
class _WallChartEdgePainter extends CustomPainter {
  final Map<String, TreeNodeInfo> nodes;
  final List<TreeEdgeInfo> edges;
  final Color edgeColor;
  final bool isHorizontal;
  final double nodeWidth;
  final double nodeHeight;

  _WallChartEdgePainter({
    required this.nodes,
    required this.edges,
    required this.edgeColor,
    required this.isHorizontal,
    required this.nodeWidth,
    required this.nodeHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = edgeColor
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final path = Path();

    for (final edge in edges) {
      final fromInfo = nodes[edge.from];
      final toInfo = nodes[edge.to];
      if (fromInfo == null || toInfo == null) continue;

      double x1, y1, x2, y2;
      
      if (!isHorizontal) {
        // Vertical
        if (edge.isCouple) {
          x1 = fromInfo.x + nodeWidth;
          y1 = fromInfo.y + nodeHeight / 2;
          x2 = toInfo.x;
          y2 = toInfo.y + nodeHeight / 2;
          path.moveTo(x1, y1);
          path.lineTo(x2, y2);
        } else {
          x1 = fromInfo.x + nodeWidth / 2;
          y1 = fromInfo.y + nodeHeight;
          x2 = toInfo.x + nodeWidth / 2;
          y2 = toInfo.y;
          // Draw orthogonal (squared) connection instead of straight line
          path.moveTo(x1, y1);
          final midY = (y1 + y2) / 2;
          path.lineTo(x1, midY);
          path.lineTo(x2, midY);
          path.lineTo(x2, y2);
        }
      } else {
        // Horizontal
        if (edge.isCouple) {
          x1 = fromInfo.y + nodeHeight;
          y1 = fromInfo.x + nodeWidth / 2;
          x2 = toInfo.y;
          y2 = toInfo.x + nodeWidth / 2;
          path.moveTo(x1, y1);
          path.lineTo(x2, y2);
        } else {
          x1 = fromInfo.y + nodeWidth;
          y1 = fromInfo.x + nodeHeight / 2;
          x2 = toInfo.y;
          y2 = toInfo.x + nodeHeight / 2;
          // Orthogonal for horizontal
          path.moveTo(x1, y1);
          final midX = (x1 + x2) / 2;
          path.lineTo(midX, y1);
          path.lineTo(midX, y2);
          path.lineTo(x2, y2);
        }
      }
    }
    
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_WallChartEdgePainter oldDelegate) {
    return oldDelegate.edgeColor != edgeColor ||
           oldDelegate.isHorizontal != isHorizontal ||
           oldDelegate.nodes != nodes ||
           oldDelegate.edges != edges;
  }
}
