// Widget tests for QuickAddPersonDialog.
//
// Tests rendering, name validation, gender selection, and the
// Cancel / Add actions — all without any platform channels.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vetviona_app/widgets/quick_add_person_dialog.dart';

// Helper: pump the dialog inside a minimal MaterialApp.
Future<QuickAddPersonInput?> _pump(
  WidgetTester tester, {
  String title = 'Add Person',
  String? subtitle,
  String confirmLabel = 'Add',
  String? initialGender,
}) async {
  QuickAddPersonInput? result;
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (ctx) => ElevatedButton(
          onPressed: () async {
            result = await showQuickAddPersonDialog(
              ctx,
              title: title,
              subtitle: subtitle,
              confirmLabel: confirmLabel,
              initialGender: initialGender,
            );
          },
          child: const Text('Open'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
  return result;
}

void main() {
  group('QuickAddPersonDialog — rendering', () {
    testWidgets('shows title text', (tester) async {
      await _pump(tester, title: 'Add Child');
      expect(find.text('Add Child'), findsOneWidget);
    });

    testWidgets('shows subtitle when provided', (tester) async {
      await _pump(tester, subtitle: 'Select a parent first');
      expect(find.text('Select a parent first'), findsOneWidget);
    });

    testWidgets('does not show subtitle widget when omitted', (tester) async {
      await _pump(tester, title: 'No sub');
      expect(find.text('Select a parent first'), findsNothing);
    });

    testWidgets('shows Name text field', (tester) async {
      await _pump(tester);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Name'), findsOneWidget);
    });

    testWidgets('shows confirm button with custom label', (tester) async {
      await _pump(tester, confirmLabel: 'Create');
      expect(find.text('Create'), findsOneWidget);
    });

    testWidgets('shows Cancel button', (tester) async {
      await _pump(tester);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('shows Gender dropdown with Not specified by default',
        (tester) async {
      await _pump(tester);
      expect(find.text('Not specified'), findsOneWidget);
    });

    testWidgets('pre-selects initialGender when valid', (tester) async {
      await _pump(tester, initialGender: 'Female');
      expect(find.text('Female'), findsOneWidget);
    });

    testWidgets('falls back to null gender for invalid initialGender',
        (tester) async {
      await _pump(tester, initialGender: 'Robot');
      expect(find.text('Not specified'), findsOneWidget);
    });
  });

  group('QuickAddPersonDialog — name validation', () {
    testWidgets('Add button with empty name does not dismiss dialog',
        (tester) async {
      await _pump(tester);
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      // Dialog should still be visible (title is 'Add Person').
      expect(find.text('Add Person'), findsOneWidget);
    });

    testWidgets('Add button with whitespace-only name does not dismiss',
        (tester) async {
      await _pump(tester);
      await tester.enterText(find.byType(TextField), '   ');
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(find.text('Add Person'), findsOneWidget);
    });
  });

  group('QuickAddPersonDialog — Cancel action', () {
    testWidgets('Cancel dismisses dialog', (tester) async {
      await _pump(tester);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Add Person'), findsNothing);
    });

    testWidgets('Cancel returns null from showQuickAddPersonDialog',
        (tester) async {
      QuickAddPersonInput? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () async {
                result = await showQuickAddPersonDialog(ctx, title: 'Test');
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(result, isNull);
    });
  });

  group('QuickAddPersonDialog — Add action', () {
    testWidgets('returns QuickAddPersonInput with typed name', (tester) async {
      QuickAddPersonInput? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () async {
                result = await showQuickAddPersonDialog(ctx, title: 'New Person');
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Alice Smith');
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.name, 'Alice Smith');
      expect(result!.gender, isNull);
    });

    testWidgets('returned name is trimmed', (tester) async {
      QuickAddPersonInput? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () async {
                result = await showQuickAddPersonDialog(ctx, title: 'New Person');
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '  Bob  ');
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      expect(result!.name, 'Bob');
    });

    testWidgets('submitting via keyboard Enter also closes dialog',
        (tester) async {
      QuickAddPersonInput? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () async {
                result = await showQuickAddPersonDialog(ctx, title: 'New Person');
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Carol');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(result!.name, 'Carol');
    });
  });

  group('QuickAddPersonDialog — gender selection', () {
    testWidgets('selecting a gender is reflected in returned input',
        (tester) async {
      QuickAddPersonInput? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () async {
                result = await showQuickAddPersonDialog(ctx, title: 'New Person');
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Diana');

      // Open the gender dropdown.
      await tester.tap(find.text('Not specified'));
      await tester.pumpAndSettle();

      // Choose 'Male'.
      await tester.tap(find.text('Male').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      expect(result!.gender, 'Male');
    });

    testWidgets('resetting gender back to null is allowed', (tester) async {
      QuickAddPersonInput? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () async {
                result = await showQuickAddPersonDialog(
                  ctx,
                  title: 'New Person',
                  initialGender: 'Female',
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Eve');

      // Re-open dropdown and choose 'Not specified'.
      await tester.tap(find.text('Female'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Not specified').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      expect(result!.gender, isNull);
    });
  });
}
