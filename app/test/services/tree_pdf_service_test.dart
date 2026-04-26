// Unit tests for TreePdfService — page planning and end-to-end vector PDF
// generation from a TreeLayout.
//
// These tests run without a display (pure Dart + the `pdf` package) so they
// cover the deterministic "build a PDF document" path without needing the
// platform `printing` channel.

import 'package:flutter/material.dart' show Size;
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';

import 'package:vetviona_app/models/partnership.dart';
import 'package:vetviona_app/models/person.dart';
import 'package:vetviona_app/screens/tree_layout.dart';
import 'package:vetviona_app/services/tree_pdf_service.dart';

Person _person(
  String id, {
  String? name,
  List<String>? parentIds,
  List<String>? childIds,
  String? gender,
  DateTime? birthDate,
  DateTime? deathDate,
  String? birthPlace,
}) =>
    Person(
      id: id,
      name: name ?? 'Person $id',
      parentIds: parentIds ?? const [],
      childIds: childIds ?? const [],
      gender: gender,
      birthDate: birthDate,
      deathDate: deathDate,
      birthPlace: birthPlace,
    );

const TreePdfStyle _style = TreePdfStyle(
  nodeWidth: 128,
  nodeHeight: 88,
  rowGap: 100,
  edgeStrokeWidth: 1.4,
  showCoupleKnot: true,
);

void main() {
  group('TreePdfService.planPages', () {
    test('returns single page for a small canvas', () {
      final plan = TreePdfService.planPages(800, 500);
      expect(plan.cols, 1);
      expect(plan.rows, 1);
      expect(plan.pageCount, 1);
      expect(plan.scale, lessThanOrEqualTo(TreePdfService.maxScale));
      expect(plan.scale, greaterThan(0));
      expect(plan.pageFormat.width, PdfPageFormat.a3.landscape.width);
    });

    test('clamps the scale to the maxScale ceiling', () {
      // A tiny canvas would otherwise compute a scale much larger than 1.
      final plan = TreePdfService.planPages(50, 30);
      expect(plan.cols, 1);
      expect(plan.rows, 1);
      expect(plan.scale, TreePdfService.maxScale);
    });

    test('returns multiple pages for a very wide canvas', () {
      final plan = TreePdfService.planPages(20000, 1000);
      expect(plan.pageCount, greaterThan(1));
      // Wider canvas should grow the column dimension first.
      expect(plan.cols, greaterThanOrEqualTo(plan.rows));
      expect(plan.scale, greaterThan(0.0));
    });

    test('returns multiple pages for a very tall canvas', () {
      final plan = TreePdfService.planPages(1000, 12000);
      expect(plan.pageCount, greaterThan(1));
      expect(plan.rows, greaterThanOrEqualTo(plan.cols));
    });

    test('handles zero/negative canvas size without crashing', () {
      final plan = TreePdfService.planPages(0, 0);
      expect(plan.cols, 1);
      expect(plan.rows, 1);
      expect(plan.scale, 1.0);
    });

    test('caps the page grid at 16 pages even for huge canvases', () {
      final plan = TreePdfService.planPages(200000, 200000);
      expect(plan.pageCount, lessThanOrEqualTo(16));
    });
  });

  group('TreePdfService.buildTreePdf', () {
    test('produces a non-empty PDF for a small tree', () async {
      final persons = [
        _person(
          'p1',
          name: 'Alice Anderson',
          gender: 'female',
          birthDate: DateTime(1970, 3, 4),
          birthPlace: 'Reykjavík',
        ),
        _person(
          'p2',
          name: 'Bob Brown',
          gender: 'male',
          birthDate: DateTime(1968, 1, 1),
        ),
        _person(
          'c1',
          name: 'Cory Brown',
          gender: 'male',
          parentIds: const ['p1', 'p2'],
        ),
      ];
      final partnerships = [Partnership(id: 'm1', person1Id: 'p1', person2Id: 'p2')];
      final layout = TreeLayout(persons, partnerships)..compute();

      final bytes = await TreePdfService.buildTreePdf(
        layout: layout,
        persons: persons,
        style: _style,
        title: 'Test Family',
        generatedAt: DateTime(2025, 1, 1),
      );
      expect(bytes.length, greaterThan(500));
      // PDF magic header.
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    });

    test('produces multiple pages when the canvas is enormous', () async {
      // Generate 200 unrelated roots — wide canvas, single row.
      final persons = [
        for (int i = 0; i < 200; i++)
          _person('p$i', name: 'Person $i', gender: i.isEven ? 'male' : 'female'),
      ];
      final layout = TreeLayout(persons, const <Partnership>[])..compute();
      // Sanity: the layout should be very wide.
      expect(layout.canvasSize.width, greaterThan(8000));

      final bytes = await TreePdfService.buildTreePdf(
        layout: layout,
        persons: persons,
        style: _style,
      );
      expect(bytes.length, greaterThan(1000));

      final plan = TreePdfService.planPages(
        layout.canvasSize.width,
        layout.canvasSize.height,
      );
      expect(plan.pageCount, greaterThan(1));
    });

    test('handles a tree with empty layout gracefully', () async {
      final layout = TreeLayout(const <Person>[], const <Partnership>[])
        ..compute();
      // Empty layout has Size.zero canvas — service should still produce a
      // valid (single-page) PDF rather than throwing.
      expect(layout.canvasSize, Size.zero);
      final bytes = await TreePdfService.buildTreePdf(
        layout: layout,
        persons: const <Person>[],
        style: _style,
      );
      expect(bytes.length, greaterThan(200));
    });
  });
}
