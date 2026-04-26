// app/lib/services/tree_pdf_service.dart
//
// Vector PDF rendering of a [TreeLayout].
//
// Rebuilds the family-tree diagram (edges + couple knots + person cards)
// directly with the `pdf` package so the output stays sharp at any zoom and
// works regardless of the on-screen viewport state.  The page format and
// orientation are picked automatically to fit the entire canvas; for very
// wide trees the layout is split into a small grid of pages so each one
// stays readable.
//
// All public functions are pure with respect to widgets, which keeps them
// straightforward to unit-test (see test/services/tree_pdf_service_test.dart).

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/person.dart';
import '../screens/tree_layout.dart';

/// Result of [TreePdfService.planPages]: how the canvas is divided into a
/// grid of PDF pages.  Exposed for unit testing.
class TreePdfPagePlan {
  /// Page format used for every page in the document.
  final PdfPageFormat pageFormat;

  /// Number of columns / rows in the page grid.
  final int cols;
  final int rows;

  /// Scale factor (canvas units → PDF points) applied uniformly so the full
  /// canvas fits across `cols × rows` pages.
  final double scale;

  const TreePdfPagePlan({
    required this.pageFormat,
    required this.cols,
    required this.rows,
    required this.scale,
  });

  int get pageCount => cols * rows;
}

/// Visual styling extracted from the active preset.  Kept as a pure data
/// class so the service has zero Flutter widget dependencies.
class TreePdfStyle {
  final double nodeWidth;
  final double nodeHeight;
  final double rowGap;
  final double edgeStrokeWidth;
  final bool showCoupleKnot;

  const TreePdfStyle({
    required this.nodeWidth,
    required this.nodeHeight,
    required this.rowGap,
    required this.edgeStrokeWidth,
    required this.showCoupleKnot,
  });
}

class TreePdfService {
  /// Margin (PDF points) around the tree on every page.
  static const double pageMargin = 24.0;

  /// Reserved height (PDF points) at the top of each page for the title bar.
  static const double headerHeight = 36.0;

  /// Maximum PDF zoom (points per canvas unit) — larger values blow up small
  /// trees too much, smaller values waste page real estate.
  static const double maxScale = 1.0;

  /// Returns a page plan that fits a canvas of [canvasW] × [canvasH] across
  /// the smallest grid of landscape A3 pages whose effective scale stays
  /// readable (≥ ~0.35 pt/canvas-unit).  Single-page output is preferred
  /// whenever it remains legible.
  static TreePdfPagePlan planPages(double canvasW, double canvasH) {
    // Landscape A3 is the sweet spot: large enough that most trees fit on a
    // single sheet, small enough that consumer printers can still produce it
    // (and the printing package will down-scale to A4 transparently).
    final landscape = PdfPageFormat.a3.landscape;

    final usableW = landscape.width - 2 * pageMargin;
    final usableH = landscape.height - 2 * pageMargin - headerHeight;

    if (canvasW <= 0 || canvasH <= 0) {
      return TreePdfPagePlan(
        pageFormat: landscape,
        cols: 1,
        rows: 1,
        scale: 1.0,
      );
    }

    // Try single-page first.
    final singleScale = math.min(usableW / canvasW, usableH / canvasH);
    if (singleScale >= 0.18) {
      return TreePdfPagePlan(
        pageFormat: landscape,
        cols: 1,
        rows: 1,
        scale: math.min(singleScale, maxScale),
      );
    }

    // Pick the smallest grid (capped at 4×4 = 16 pages) that yields a
    // per-page scale ≥ minReadable.
    const double minReadable = 0.35;
    const int maxAxis = 4;
    int cols = 1;
    int rows = 1;
    double s = math.min(usableW / canvasW, usableH / canvasH);
    while (s < minReadable && (cols < maxAxis || rows < maxAxis)) {
      // Grow whichever axis is the tighter constraint, but stop when an
      // axis hits the maxAxis cap.
      final double colSlack = (usableW * cols) / canvasW;
      final double rowSlack = (usableH * rows) / canvasH;
      if (colSlack <= rowSlack && cols < maxAxis) {
        cols++;
      } else if (rows < maxAxis) {
        rows++;
      } else {
        cols++;
      }
      s = math.min((usableW * cols) / canvasW, (usableH * rows) / canvasH);
    }
    return TreePdfPagePlan(
      pageFormat: landscape,
      cols: cols,
      rows: rows,
      scale: math.min(s, maxScale),
    );
  }

  /// Builds a complete PDF document for the given tree layout.
  ///
  /// [title] is rendered in the page header along with the page index.
  /// [persons] supplies the display data for each `node.id` (the layout
  /// itself only knows id + position).
  static Future<Uint8List> buildTreePdf({
    required TreeLayout layout,
    required List<Person> persons,
    required TreePdfStyle style,
    String title = 'Family Tree',
    DateTime? generatedAt,
  }) async {
    final personMap = {for (final p in persons) p.id: p};
    final canvas = layout.canvasSize;
    final plan = planPages(canvas.width, canvas.height);

    final doc = pw.Document(title: title, author: 'Vetviona');
    final ts = generatedAt ?? DateTime.now();
    final dateStr = DateFormat('d MMM yyyy').format(ts);

    final usableW = plan.pageFormat.width - 2 * pageMargin;
    final usableH = plan.pageFormat.height - 2 * pageMargin - headerHeight;
    final tileWcanvas = usableW / plan.scale;
    final tileHcanvas = usableH / plan.scale;

    for (int row = 0; row < plan.rows; row++) {
      for (int col = 0; col < plan.cols; col++) {
        final tileIndex = row * plan.cols + col + 1;
        final tileLeft = col * tileWcanvas;
        final tileTop = row * tileHcanvas;

        doc.addPage(
          pw.Page(
            pageFormat: plan.pageFormat,
            margin: const pw.EdgeInsets.all(pageMargin),
            build: (ctx) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _buildHeader(
                    title: title,
                    dateStr: dateStr,
                    pageIndex: tileIndex,
                    pageCount: plan.pageCount,
                    cols: plan.cols,
                    rows: plan.rows,
                    col: col,
                    row: row,
                  ),
                  pw.SizedBox(height: 6),
                  pw.Expanded(
                    child: pw.ClipRect(
                      child: _buildTile(
                        layout: layout,
                        personMap: personMap,
                        style: style,
                        scale: plan.scale,
                        tileLeft: tileLeft,
                        tileTop: tileTop,
                        tileW: usableW,
                        tileH: usableH,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      }
    }

    return doc.save();
  }

  // ── Header ────────────────────────────────────────────────────────────────
  static pw.Widget _buildHeader({
    required String title,
    required String dateStr,
    required int pageIndex,
    required int pageCount,
    required int cols,
    required int rows,
    required int col,
    required int row,
  }) {
    final tileLabel = (cols == 1 && rows == 1)
        ? ''
        : '   -   Section ${col + 1},${row + 1}';
    return pw.Container(
      height: headerHeight - 8,
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.grey400, width: 0.6),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey900,
            ),
          ),
          pw.Text(
            'Generated $dateStr   -   Page $pageIndex of $pageCount$tileLabel',
            style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
        ],
      ),
    );
  }

  // ── Tile builder ──────────────────────────────────────────────────────────
  // Builds one page's slice of the tree.  Coordinates are converted from
  // layout space (top-left origin, Y down) to PDF tile space (top-left
  // origin, Y down — pw.Stack handles the PDF Y-flip internally for us) by
  // multiplying by [scale] and subtracting [tileLeft]/[tileTop].
  static pw.Widget _buildTile({
    required TreeLayout layout,
    required Map<String, Person> personMap,
    required TreePdfStyle style,
    required double scale,
    required double tileLeft,
    required double tileTop,
    required double tileW,
    required double tileH,
  }) {
    // Visible canvas window for this tile, with a small margin so cards on
    // the boundary are still drawn.
    final tileRect = _Rect(
      left: tileLeft - style.nodeWidth,
      top: tileTop - style.nodeHeight,
      right: tileLeft + tileW / scale + style.nodeWidth,
      bottom: tileTop + tileH / scale + style.nodeHeight,
    );

    final cardWidgets = <pw.Widget>[];
    for (final node in layout.nodes.values) {
      if (!tileRect.overlapsNode(
        node.x,
        node.y,
        style.nodeWidth,
        style.nodeHeight,
      )) {
        continue;
      }
      final pdfLeft = (node.x - tileLeft) * scale;
      final pdfTop = (node.y - tileTop) * scale;
      final pdfW = style.nodeWidth * scale;
      final pdfH = style.nodeHeight * scale;

      if (node.isCoupleKnot) {
        if (!style.showCoupleKnot) continue;
        cardWidgets.add(
          pw.Positioned(
            left: pdfLeft,
            top: pdfTop,
            child: pw.SizedBox(
              width: pdfW,
              height: pdfH,
              child: pw.Center(child: _coupleKnotDot(scale)),
            ),
          ),
        );
        continue;
      }

      final person = personMap[node.id];
      cardWidgets.add(
        pw.Positioned(
          left: pdfLeft,
          top: pdfTop,
          child: pw.SizedBox(
            width: pdfW,
            height: pdfH,
            child: _personCard(person, scale),
          ),
        ),
      );
    }

    return pw.Stack(
      overflow: pw.Overflow.clip,
      children: [
        // Edges painted behind the cards.
        pw.Positioned.fill(
          child: pw.CustomPaint(
            size: PdfPoint(tileW, tileH),
            painter: (canvas, size) => _paintEdges(
              canvas: canvas,
              size: size,
              layout: layout,
              style: style,
              scale: scale,
              tileLeft: tileLeft,
              tileTop: tileTop,
            ),
          ),
        ),
        ...cardWidgets,
      ],
    );
  }

  // ── Edge painter ──────────────────────────────────────────────────────────
  static void _paintEdges({
    required PdfGraphics canvas,
    required PdfPoint size,
    required TreeLayout layout,
    required TreePdfStyle style,
    required double scale,
    required double tileLeft,
    required double tileTop,
  }) {
    // pw.CustomPaint hands us a canvas in PDF coordinates (Y up) with the
    // origin already translated to the painter box.  We want to draw using
    // top-left, Y-down semantics — convert each layout point manually.
    canvas.setLineWidth(style.edgeStrokeWidth);
    for (final edge in layout.edges) {
      final from = layout.nodes[edge.from];
      final to = layout.nodes[edge.to];
      if (from == null || to == null) continue;

      final fxLayout = from.x + style.nodeWidth / 2;
      final fyLayout = from.y + style.nodeHeight / 2;
      final txLayout = to.x + style.nodeWidth / 2;
      final tyLayout = to.y + style.nodeHeight / 2;

      // Tile space (top-left origin, scaled).
      final fxTile = (fxLayout - tileLeft) * scale;
      final fyTileTop = (fyLayout - tileTop) * scale;
      final txTile = (txLayout - tileLeft) * scale;
      final tyTileTop = (tyLayout - tileTop) * scale;

      // Convert tile-top-Y → PDF-bottom-Y.
      final fyPdf = size.y - fyTileTop;
      final tyPdf = size.y - tyTileTop;

      if (edge.isCouple) {
        canvas.setStrokeColor(PdfColors.purple300);
      } else {
        canvas.setStrokeColor(PdfColors.grey600);
      }
      canvas
        ..moveTo(fxTile, fyPdf)
        ..lineTo(txTile, tyPdf)
        ..strokePath();
    }
  }

  // ── Person card widget ────────────────────────────────────────────────────
  static pw.Widget _personCard(Person? person, double scale) {
    final genderLower = person?.gender?.toLowerCase();
    PdfColor borderColor;
    PdfColor stripColor;
    if (genderLower == 'male') {
      borderColor = PdfColors.blue700;
      stripColor = PdfColors.blue100;
    } else if (genderLower == 'female') {
      borderColor = PdfColors.pink700;
      stripColor = PdfColors.pink100;
    } else {
      borderColor = PdfColors.grey700;
      stripColor = PdfColors.grey200;
    }

    final name = (person?.name.isNotEmpty ?? false) ? person!.name : '?';
    final years = person == null ? '' : _yearRange(person);
    final place = person?.birthPlace ?? '';

    // Scale-aware font sizes; keep a floor so output remains legible even at
    // very small per-page scales.
    final nameSize = math.max(5.5, 9.0 * scale);
    final yearSize = math.max(4.5, 7.5 * scale);
    final placeSize = math.max(4.0, 6.5 * scale);
    final radius = math.max(2.0, 6.0 * scale);

    return pw.Container(
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        border: pw.Border.all(color: borderColor, width: 0.8),
        borderRadius: pw.BorderRadius.circular(radius),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          // Gender strip on the left edge.
          pw.Container(width: 4.0 * scale, color: stripColor),
          pw.Expanded(
            child: pw.Padding(
              padding: pw.EdgeInsets.symmetric(
                horizontal: 4.0 * scale,
                vertical: 3.0 * scale,
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  pw.Text(
                    name,
                    maxLines: 2,
                    overflow: pw.TextOverflow.clip,
                    style: pw.TextStyle(
                      fontSize: nameSize,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey900,
                    ),
                  ),
                  if (years.isNotEmpty)
                    pw.Text(
                      years,
                      style: pw.TextStyle(
                        fontSize: yearSize,
                        color: PdfColors.grey700,
                      ),
                    ),
                  if (place.isNotEmpty)
                    pw.Text(
                      place,
                      maxLines: 1,
                      overflow: pw.TextOverflow.clip,
                      style: pw.TextStyle(
                        fontSize: placeSize,
                        color: PdfColors.grey600,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _coupleKnotDot(double scale) {
    final size = math.max(3.0, 6.0 * scale);
    return pw.Container(
      width: size,
      height: size,
      decoration: pw.BoxDecoration(
        color: PdfColors.purple100,
        shape: pw.BoxShape.circle,
        border: pw.Border.all(color: PdfColors.purple400, width: 0.6),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  static String _yearRange(Person p) {
    final by = p.birthDate?.year.toString();
    final dy = p.deathDate?.year.toString();
    if (by == null && dy == null) return '';
    if (by != null && dy != null) return '$by - $dy';
    if (by != null) return 'b. $by';
    return 'd. $dy';
  }
}

/// Tiny axis-aligned rectangle helper used for tile clipping (avoids a
/// dependency on `dart:ui` from the service layer so it can be unit-tested
/// without Flutter bindings).
class _Rect {
  final double left;
  final double top;
  final double right;
  final double bottom;
  const _Rect({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  bool overlapsNode(double x, double y, double w, double h) {
    return x < right && x + w > left && y < bottom && y + h > top;
  }
}
