// Smoke tests for key screens — verifies that the three most-used screens
// render without throwing, regardless of platform-channel state.
//
// These tests use a minimal provider setup with empty in-memory data so they
// do not require a real SQLite database or any platform channels.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vetviona_app/models/partnership.dart';
import 'package:vetviona_app/models/person.dart';
import 'package:vetviona_app/providers/theme_provider.dart';
import 'package:vetviona_app/providers/tree_provider.dart';
import 'package:vetviona_app/screens/descendants_screen.dart';
import 'package:vetviona_app/screens/home_screen.dart';
import 'package:vetviona_app/screens/person_detail_screen.dart';
import 'package:vetviona_app/screens/splash_screen.dart';
import 'package:vetviona_app/screens/tree_diagram_screen.dart';
import 'package:vetviona_app/services/purchase_service.dart';
import 'package:vetviona_app/services/sync_service.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

/// Builds a minimal widget tree that satisfies all screen dependencies.
Widget _buildTestApp(Widget child, {TreeProvider? provider}) {
  final treeProvider = provider ?? TreeProvider();
  treeProvider.isLoaded = true;
  treeProvider.loadingMessage = 'Ready';
  treeProvider.loadingProgress = 1.0;

  return MultiProvider(
    providers: [
      ChangeNotifierProvider<TreeProvider>.value(value: treeProvider),
      ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
      ChangeNotifierProvider<SyncService>(create: (_) => SyncService()),
      ChangeNotifierProvider<PurchaseService>(
          create: (_) => PurchaseService()),
    ],
    child: MaterialApp(home: child),
  );
}

void main() {
  // ── SplashScreen ────────────────────────────────────────────────────────────

  group('SplashScreen smoke test', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('renders app name while loading', (tester) async {
      final treeProvider = TreeProvider();
      treeProvider.isLoaded = false;
      treeProvider.loadingMessage = 'Starting\u2026';
      treeProvider.loadingProgress = 0.0;

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<TreeProvider>.value(value: treeProvider),
            ChangeNotifierProvider<ThemeProvider>(
                create: (_) => ThemeProvider()),
            ChangeNotifierProvider<SyncService>(create: (_) => SyncService()),
            ChangeNotifierProvider<PurchaseService>(
                create: (_) => PurchaseService()),
          ],
          child: const MaterialApp(home: SplashScreen()),
        ),
      );

      expect(find.text('Vetviona'), findsOneWidget);
      expect(find.text('Starting\u2026'), findsOneWidget);
    });

    testWidgets('shows linear progress indicator while loading', (tester) async {
      final treeProvider = TreeProvider();
      treeProvider.isLoaded = false;
      treeProvider.loadingProgress = 0.4;
      treeProvider.loadingMessage = 'Loading people\u2026';

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<TreeProvider>.value(value: treeProvider),
            ChangeNotifierProvider<ThemeProvider>(
                create: (_) => ThemeProvider()),
            ChangeNotifierProvider<SyncService>(create: (_) => SyncService()),
            ChangeNotifierProvider<PurchaseService>(
                create: (_) => PurchaseService()),
          ],
          child: const MaterialApp(home: SplashScreen()),
        ),
      );

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.text('Loading people\u2026'), findsOneWidget);
    });
  });

  // ── HomeScreen ──────────────────────────────────────────────────────────────

  group('HomeScreen smoke test', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({'onboardingDone': true});
    });

    testWidgets('renders with empty tree without throwing', (tester) async {
      await tester.pumpWidget(_buildTestApp(const HomeScreen()));
      await tester.pump();

      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets('appBar is present', (tester) async {
      await tester.pumpWidget(_buildTestApp(const HomeScreen()));
      await tester.pump();

      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('scaffold renders without error', (tester) async {
      await tester.pumpWidget(_buildTestApp(const HomeScreen()));
      await tester.pump();

      expect(find.byType(Scaffold), findsAtLeastNWidgets(1));
    });
  });

  // ── PersonDetailScreen ──────────────────────────────────────────────────────

  group('PersonDetailScreen smoke test', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('opens in create mode without throwing', (tester) async {
      await tester.pumpWidget(_buildTestApp(const PersonDetailScreen()));
      await tester.pump();

      expect(find.byType(AppBar), findsOneWidget);
      expect(find.byType(Form), findsAtLeastNWidgets(1));
    });

    testWidgets('save button is present', (tester) async {
      await tester.pumpWidget(_buildTestApp(const PersonDetailScreen()));
      await tester.pump();

      expect(find.byIcon(Icons.save), findsAtLeastNWidgets(1));
    });
  });

  // ── TreeDiagramScreen ───────────────────────────────────────────────────────

  group('TreeDiagramScreen smoke test', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('shows empty-tree placeholder when no people are loaded',
        (tester) async {
      await tester.pumpWidget(_buildTestApp(const TreeDiagramScreen()));
      await tester.pump();

      expect(find.text('No people in the tree yet.'), findsOneWidget);
    });

    testWidgets('renders AppBar with "Family Tree" title', (tester) async {
      await tester.pumpWidget(_buildTestApp(const TreeDiagramScreen()));
      await tester.pump();

      expect(find.text('Family Tree'), findsOneWidget);
    });

    testWidgets('renders InteractiveViewer when tree has one person',
        (tester) async {
      final provider = TreeProvider()
        ..isLoaded = true
        ..loadingMessage = 'Ready'
        ..loadingProgress = 1.0
        ..persons = [Person(id: 'p1', name: 'Alice')];

      await tester.pumpWidget(
          _buildTestApp(const TreeDiagramScreen(), provider: provider));
      await tester.pump();

      expect(find.byType(InteractiveViewer), findsOneWidget);
    });

    testWidgets('renders person card name when tree has one person',
        (tester) async {
      final provider = TreeProvider()
        ..isLoaded = true
        ..loadingMessage = 'Ready'
        ..loadingProgress = 1.0
        ..persons = [Person(id: 'p1', name: 'Alice')];

      await tester.pumpWidget(
          _buildTestApp(const TreeDiagramScreen(), provider: provider));
      await tester.pump();

      expect(find.text('Alice'), findsAtLeastNWidgets(1));
    });

    testWidgets('renders parent and child when tree has two generations',
        (tester) async {
      final provider = TreeProvider()
        ..isLoaded = true
        ..loadingMessage = 'Ready'
        ..loadingProgress = 1.0
        ..persons = [
          Person(id: 'p1', name: 'Parent', childIds: ['p2']),
          Person(id: 'p2', name: 'Child', parentIds: ['p1']),
        ];

      await tester.pumpWidget(
          _buildTestApp(const TreeDiagramScreen(), provider: provider));
      await tester.pump();

      expect(find.text('Parent'), findsAtLeastNWidgets(1));
      expect(find.text('Child'), findsAtLeastNWidgets(1));
    });

    testWidgets('renders couple and child when partnership exists',
        (tester) async {
      final provider = TreeProvider()
        ..isLoaded = true
        ..loadingMessage = 'Ready'
        ..loadingProgress = 1.0
        ..persons = [
          Person(id: 'dad', name: 'Dad', childIds: ['kid']),
          Person(id: 'mum', name: 'Mum', childIds: ['kid']),
          Person(id: 'kid', name: 'Kid', parentIds: ['dad', 'mum']),
        ]
        ..partnerships = [
          Partnership(id: 'p1', person1Id: 'dad', person2Id: 'mum'),
        ];

      await tester.pumpWidget(
          _buildTestApp(const TreeDiagramScreen(), provider: provider));
      await tester.pump();

      expect(find.text('Dad'), findsAtLeastNWidgets(1));
      expect(find.text('Mum'), findsAtLeastNWidgets(1));
      expect(find.text('Kid'), findsAtLeastNWidgets(1));
    });

    testWidgets('zoom controls are present when tree has people',
        (tester) async {
      final provider = TreeProvider()
        ..isLoaded = true
        ..loadingMessage = 'Ready'
        ..loadingProgress = 1.0
        ..persons = [Person(id: 'p1', name: 'Alice')];

      await tester.pumpWidget(
          _buildTestApp(const TreeDiagramScreen(), provider: provider));
      await tester.pump();

      // Zoom in / out FABs should be visible.
      expect(find.byIcon(Icons.add), findsAtLeastNWidgets(1));
      expect(find.byIcon(Icons.remove), findsAtLeastNWidgets(1));
    });
  });

  // ── DescendantsScreen ───────────────────────────────────────────────────────

  group('DescendantsScreen smoke test', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('shows empty-tree placeholder when no people are loaded',
        (tester) async {
      await tester.pumpWidget(_buildTestApp(const DescendantsScreen()));
      await tester.pump();

      expect(find.text('No people in the tree yet.'), findsOneWidget);
    });

    testWidgets('shows "no descendants" message for a leaf person',
        (tester) async {
      final provider = TreeProvider()
        ..isLoaded = true
        ..loadingMessage = 'Ready'
        ..loadingProgress = 1.0
        ..persons = [Person(id: 'p1', name: 'Alice')];

      await tester.pumpWidget(
          _buildTestApp(const DescendantsScreen(), provider: provider));
      await tester.pump();

      expect(
          find.text('This person has no recorded descendants.'), findsOneWidget);
    });

    testWidgets('renders AppBar with "Descendants Chart" title when empty',
        (tester) async {
      await tester.pumpWidget(_buildTestApp(const DescendantsScreen()));
      await tester.pump();

      expect(find.text('Descendants Chart'), findsOneWidget);
    });

    testWidgets('renders InteractiveViewer when root has descendants',
        (tester) async {
      final provider = TreeProvider()
        ..isLoaded = true
        ..loadingMessage = 'Ready'
        ..loadingProgress = 1.0
        ..persons = [
          Person(id: 'gp', name: 'Grandparent', childIds: ['p1']),
          Person(id: 'p1', name: 'Parent', parentIds: ['gp'], childIds: ['c1']),
          Person(id: 'c1', name: 'Child', parentIds: ['p1']),
        ];

      await tester
          .pumpWidget(_buildTestApp(DescendantsScreen(initialPerson: provider.persons.first), provider: provider));
      await tester.pump();

      expect(find.byType(InteractiveViewer), findsOneWidget);
    });
  });
}
