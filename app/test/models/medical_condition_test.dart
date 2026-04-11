import 'package:flutter_test/flutter_test.dart';
import 'package:vetviona_app/models/medical_condition.dart';

void main() {
  group('MedicalCondition', () {
    group('constructor defaults', () {
      test('attachmentPaths defaults to empty list when not provided', () {
        final mc = MedicalCondition(
          id: 'mc1',
          personId: 'p1',
          condition: 'Hypertension',
          category: 'Cardiovascular',
        );
        expect(mc.attachmentPaths, isEmpty);
      });

      test('optional fields default to null', () {
        final mc = MedicalCondition(
          id: 'mc1',
          personId: 'p1',
          condition: 'Asthma',
          category: 'Respiratory',
        );
        expect(mc.ageOfOnset, isNull);
        expect(mc.notes, isNull);
        expect(mc.treeId, isNull);
      });

      test('explicit attachmentPaths are stored', () {
        final mc = MedicalCondition(
          id: 'mc1',
          personId: 'p1',
          condition: 'Epilepsy',
          category: 'Neurological',
          attachmentPaths: ['/docs/scan1.pdf', '/docs/scan2.pdf'],
        );
        expect(mc.attachmentPaths, ['/docs/scan1.pdf', '/docs/scan2.pdf']);
      });
    });

    group('categories', () {
      test('categories list is non-empty', () {
        expect(MedicalCondition.categories, isNotEmpty);
      });

      test('contains all expected high-level categories', () {
        expect(
          MedicalCondition.categories,
          containsAll([
            'Cardiovascular',
            'Cancer',
            'Mental Health',
            'Neurological',
            'Genetic / Chromosomal',
            'Other',
          ]),
        );
      });
    });

    group('suggestions', () {
      test('suggestions map is non-empty', () {
        expect(MedicalCondition.suggestions, isNotEmpty);
      });

      test('every category has a corresponding suggestions entry', () {
        for (final cat in MedicalCondition.categories) {
          expect(
            MedicalCondition.suggestions.containsKey(cat),
            true,
            reason: '"$cat" missing from suggestions map',
          );
        }
      });

      test('Cardiovascular suggestions include common conditions', () {
        expect(
          MedicalCondition.suggestions['Cardiovascular'],
          containsAll(['Hypertension', 'Stroke / TIA']),
        );
      });

      test('Other category has an empty suggestions list', () {
        expect(MedicalCondition.suggestions['Other'], isEmpty);
      });
    });

    group('toMap / fromMap', () {
      test('full roundtrip preserves all fields', () {
        final original = MedicalCondition(
          id: 'mc-1',
          personId: 'p-42',
          condition: 'Type 2 Diabetes',
          category: 'Metabolic / Endocrine',
          ageOfOnset: '55',
          notes: 'Managed with diet',
          treeId: 'tree-1',
          attachmentPaths: ['/path/a.pdf', '/path/b.pdf'],
        );
        final restored = MedicalCondition.fromMap(original.toMap());

        expect(restored.id, original.id);
        expect(restored.personId, original.personId);
        expect(restored.condition, original.condition);
        expect(restored.category, original.category);
        expect(restored.ageOfOnset, original.ageOfOnset);
        expect(restored.notes, original.notes);
        expect(restored.treeId, original.treeId);
        expect(restored.attachmentPaths, original.attachmentPaths);
      });

      test('null optional fields survive roundtrip', () {
        final original = MedicalCondition(
          id: 'mc-2',
          personId: 'p-1',
          condition: 'Asthma',
          category: 'Respiratory',
        );
        final restored = MedicalCondition.fromMap(original.toMap());

        expect(restored.ageOfOnset, isNull);
        expect(restored.notes, isNull);
        expect(restored.treeId, isNull);
        expect(restored.attachmentPaths, isEmpty);
      });

      test('attachmentPaths serialise with semicolon separator', () {
        final mc = MedicalCondition(
          id: 'mc-3',
          personId: 'p-1',
          condition: 'BRCA1 / BRCA2 Mutation',
          category: 'Genetic / Chromosomal',
          attachmentPaths: ['a.pdf', 'b.pdf', 'c.pdf'],
        );
        final map = mc.toMap();
        expect(map['attachmentPaths'], 'a.pdf;b.pdf;c.pdf');
      });

      test('empty attachmentPaths serialise to empty string', () {
        final mc = MedicalCondition(
          id: 'mc-4',
          personId: 'p-1',
          condition: 'Gout',
          category: 'Musculoskeletal',
        );
        expect(mc.toMap()['attachmentPaths'], '');
      });

      test('fromMap with null attachmentPaths returns empty list', () {
        final map = <String, dynamic>{
          'id': 'mc-5',
          'personId': 'p-1',
          'condition': 'Migraine',
          'category': 'Neurological',
          'attachmentPaths': null,
        };
        final mc = MedicalCondition.fromMap(map);
        expect(mc.attachmentPaths, isEmpty);
      });

      test('fromMap with empty attachmentPaths string returns empty list', () {
        final map = <String, dynamic>{
          'id': 'mc-6',
          'personId': 'p-1',
          'condition': 'Psoriasis',
          'category': 'Dermatological',
          'attachmentPaths': '',
        };
        final mc = MedicalCondition.fromMap(map);
        expect(mc.attachmentPaths, isEmpty);
      });

      test('attachment paths with semicolons roundtrip correctly', () {
        final paths = ['/docs/scan1.pdf', '/docs/scan2.pdf', '/docs/scan3.pdf'];
        final mc = MedicalCondition(
          id: 'mc-7',
          personId: 'p-1',
          condition: 'Haemophilia A',
          category: 'Haematological / Blood',
          attachmentPaths: paths,
        );
        final restored = MedicalCondition.fromMap(mc.toMap());
        expect(restored.attachmentPaths, paths);
      });
    });
  });
}
