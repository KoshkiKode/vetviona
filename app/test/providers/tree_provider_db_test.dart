import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vetviona_app/models/person.dart';
import 'package:vetviona_app/models/partnership.dart';
import 'package:vetviona_app/models/source.dart';
import 'package:vetviona_app/models/life_event.dart';
import 'package:vetviona_app/models/medical_condition.dart';
import 'package:vetviona_app/models/research_task.dart';
import 'package:vetviona_app/models/heritage.dart';
import 'package:vetviona_app/models/memory.dart';
import 'package:vetviona_app/models/record_hint.dart';
import 'package:vetviona_app/models/dna_kit.dart';
import 'package:vetviona_app/providers/tree_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  setUpAll(() {
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      return inMemoryDatabasePath;
    });
  });

  group('TreeProvider Database Operations', () {
    late TreeProvider provider;
    late Person p1;
    late Person p2;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      provider = TreeProvider();
      await provider.clearDatabase();
      await provider.loadPersons();
      
      p1 = Person(id: 'p1', name: 'John Doe', birthDate: DateTime(1900, 1, 1));
      p2 = Person(id: 'p2', name: 'Jane Doe', birthDate: DateTime(1905, 1, 1));
      await provider.addPerson(p1);
      await provider.addPerson(p2);
    });

    test('addPerson and updatePerson', () async {
      final p = Person(id: 'p3', name: 'Jim Doe', birthDate: DateTime(1920, 1, 1));
      await provider.addPerson(p);
      expect(provider.persons.length, 3);
      expect(provider.persons.last.name, 'Jim Doe');

      p.name = 'Jimmy Doe';
      await provider.updatePerson(p);
      expect(provider.persons.last.name, 'Jimmy Doe');

      await provider.deletePerson('p3');
      expect(provider.persons.length, 2);
    });

    test('addPartnership and updatePartnership', () async {
      final p = Partnership(id: 'rel1', person1Id: 'p1', person2Id: 'p2', status: 'married');
      await provider.addPartnership(p);
      expect(provider.partnerships.length, 1);

      p.status = 'divorced';
      await provider.updatePartnership(p);
      expect(provider.partnerships.first.status, 'divorced');

      await provider.deletePartnership('rel1');
      expect(provider.partnerships.isEmpty, isTrue);
    });

    test('addSource and updateSource', () async {
      final s = Source(id: 's1', personId: 'p1', title: 'Birth Cert', type: 'Document', url: 'http://test.com');
      await provider.addSource(s);
      expect(provider.sources.length, 1);

      s.title = 'Updated Cert';
      await provider.updateSource(s);
      expect(provider.sources.first.title, 'Updated Cert');

      await provider.deleteSource('s1');
      expect(provider.sources.isEmpty, isTrue);
    });

    test('addLifeEvent and updateLifeEvent', () async {
      final e = LifeEvent(id: 'e1', personId: 'p1', title: 'Born', date: DateTime(1900, 1, 1));
      await provider.addLifeEvent(e);
      expect(provider.lifeEvents.length, 1);

      e.title = 'Born updated';
      await provider.updateLifeEvent(e);
      expect(provider.lifeEvents.first.title, 'Born updated');

      await provider.deleteLifeEvent('e1');
      expect(provider.lifeEvents.isEmpty, isTrue);
    });

    test('addMedicalCondition and updateMedicalCondition', () async {
      final mc = MedicalCondition(id: 'mc1', personId: 'p1', condition: 'Flu', category: 'General');
      await provider.addMedicalCondition(mc);
      expect(provider.medicalConditions.length, 1);

      mc.condition = 'Cold';
      await provider.updateMedicalCondition(mc);
      expect(provider.medicalConditions.first.condition, 'Cold');

      await provider.deleteMedicalCondition('mc1');
      expect(provider.medicalConditions.isEmpty, isTrue);
    });

    test('addResearchTask and updateResearchTask', () async {
      final rt = ResearchTask(id: 'rt1', treeId: 't1', title: 'Find grave', status: 'todo');
      await provider.addResearchTask(rt);
      expect(provider.researchTasks.length, 1);

      rt.status = 'done';
      await provider.updateResearchTask(rt);
      expect(provider.researchTasks.first.status, 'done');

      await provider.deleteResearchTask('rt1');
      expect(provider.researchTasks.isEmpty, isTrue);
    });
    
    test('addHeritage and updateHeritage', () async {
      final h = Heritage(id: 'h1', personId: 'p1', region: 'Europe');
      await provider.addHeritage(h);
      expect(provider.heritages.length, 1);

      h.region = 'Asia';
      await provider.updateHeritage(h);
      expect(provider.heritages.first.region, 'Asia');

      await provider.deleteHeritage('h1');
      expect(provider.heritages.isEmpty, isTrue);
    });
    
    test('addMemory and updateMemory', () async {
      final m = Memory(id: 'm1', personId: 'p1', title: 'Childhood', text: 'Story');
      await provider.addMemory(m);
      expect(provider.memories.length, 1);

      m.text = 'New Story';
      await provider.updateMemory(m);
      expect(provider.memories.first.text, 'New Story');

      await provider.deleteMemory('m1');
      expect(provider.memories.isEmpty, isTrue);
    });

    test('addDnaKit and updateDnaKit', () async {
      final k = DnaKit(personId: 'p1', testType: DnaTestType.autosomal, testingCompany: 'AncestryDNA', kitNumber: 'A1234');
      await provider.addDnaKit(k);
      expect(provider.dnaKits.length, 1);

      final updatedK = DnaKit(
        id: k.id,
        personId: k.personId,
        testType: k.testType,
        testingCompany: k.testingCompany,
        kitNumber: 'B5678',
      );
      await provider.updateDnaKit(updatedK);
      expect(provider.dnaKits.first.kitNumber, 'B5678');

      await provider.deleteDnaKit(k.id);
      expect(provider.dnaKits.isEmpty, isTrue);
    });

    test('addRecordHint and updateRecordHint', () async {
      final r = RecordHint(id: 'r1', personId: 'p1', apiSource: 'fs', externalRecordId: '123', title: 'T', recordUrl: 'U');
      await provider.addRecordHint(r);
      expect(provider.recordHints.length, 1);

      r.title = 'New T';
      await provider.updateRecordHint(r);
      expect(provider.recordHints.first.title, 'New T');
    });
  });
}
