import 'package:flutter_test/flutter_test.dart';
import 'package:vetviona_app/models/research_task.dart';

void main() {
  group('ResearchTask', () {
    group('constructor defaults', () {
      test('status defaults to todo', () {
        final t = ResearchTask(id: 't1', title: 'Find birth record');
        expect(t.status, 'todo');
      });

      test('priority defaults to normal', () {
        final t = ResearchTask(id: 't1', title: 'Find birth record');
        expect(t.priority, 'normal');
      });

      test('optional fields default to null', () {
        final t = ResearchTask(id: 't1', title: 'Find birth record');
        expect(t.personId, isNull);
        expect(t.notes, isNull);
        expect(t.treeId, isNull);
      });
    });

    group('statuses constant', () {
      test('contains all three expected statuses', () {
        expect(
          ResearchTask.statuses,
          containsAll(['todo', 'in_progress', 'done']),
        );
      });
    });

    group('priorities constant', () {
      test('contains all three expected priority levels', () {
        expect(
          ResearchTask.priorities,
          containsAll(['low', 'normal', 'high']),
        );
      });
    });

    group('statusLabel', () {
      test('todo maps to To Do', () {
        expect(ResearchTask.statusLabel('todo'), 'To Do');
      });

      test('in_progress maps to In Progress', () {
        expect(ResearchTask.statusLabel('in_progress'), 'In Progress');
      });

      test('done maps to Done', () {
        expect(ResearchTask.statusLabel('done'), 'Done');
      });

      test('unknown status falls through to To Do', () {
        expect(ResearchTask.statusLabel('unknown_value'), 'To Do');
        expect(ResearchTask.statusLabel(''), 'To Do');
      });
    });

    group('priorityLabel', () {
      test('high maps to High', () {
        expect(ResearchTask.priorityLabel('high'), 'High');
      });

      test('low maps to Low', () {
        expect(ResearchTask.priorityLabel('low'), 'Low');
      });

      test('normal maps to Normal', () {
        expect(ResearchTask.priorityLabel('normal'), 'Normal');
      });

      test('unknown priority falls through to Normal', () {
        expect(ResearchTask.priorityLabel('unknown'), 'Normal');
        expect(ResearchTask.priorityLabel(''), 'Normal');
      });
    });

    group('toMap / fromMap', () {
      test('full roundtrip preserves all fields', () {
        final original = ResearchTask(
          id: 'rt-1',
          personId: 'p-42',
          title: 'Locate immigration records',
          notes: 'Check Ellis Island database',
          status: 'in_progress',
          priority: 'high',
          treeId: 'tree-1',
        );
        final restored = ResearchTask.fromMap(original.toMap());

        expect(restored.id, original.id);
        expect(restored.personId, original.personId);
        expect(restored.title, original.title);
        expect(restored.notes, original.notes);
        expect(restored.status, original.status);
        expect(restored.priority, original.priority);
        expect(restored.treeId, original.treeId);
      });

      test('null optional fields survive roundtrip', () {
        final original = ResearchTask(id: 'rt-2', title: 'Check census');
        final restored = ResearchTask.fromMap(original.toMap());

        expect(restored.personId, isNull);
        expect(restored.notes, isNull);
        expect(restored.treeId, isNull);
      });

      test('fromMap with null status defaults to todo', () {
        final map = <String, dynamic>{
          'id': 'rt-3',
          'title': 'Task without status',
          'status': null,
          'priority': 'normal',
        };
        final t = ResearchTask.fromMap(map);
        expect(t.status, 'todo');
      });

      test('fromMap with null priority defaults to normal', () {
        final map = <String, dynamic>{
          'id': 'rt-4',
          'title': 'Task without priority',
          'status': 'done',
          'priority': null,
        };
        final t = ResearchTask.fromMap(map);
        expect(t.priority, 'normal');
      });

      test('minimal map (only required fields) deserialises without error', () {
        final map = <String, dynamic>{
          'id': 'rt-5',
          'title': 'Minimal task',
        };
        final t = ResearchTask.fromMap(map);
        expect(t.id, 'rt-5');
        expect(t.title, 'Minimal task');
        expect(t.status, 'todo');
        expect(t.priority, 'normal');
      });

      test('all status values survive roundtrip', () {
        for (final status in ResearchTask.statuses) {
          final t = ResearchTask(id: 't', title: 'T', status: status);
          expect(ResearchTask.fromMap(t.toMap()).status, status);
        }
      });

      test('all priority values survive roundtrip', () {
        for (final priority in ResearchTask.priorities) {
          final t = ResearchTask(id: 't', title: 'T', priority: priority);
          expect(ResearchTask.fromMap(t.toMap()).priority, priority);
        }
      });
    });
  });
}
