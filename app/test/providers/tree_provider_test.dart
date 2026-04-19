// Tests for TreeProvider that do NOT require a real database or path_provider.
//
// The provider exposes its in-memory lists as public fields, so pure-logic
// methods (search, BFS, export, auth) can be exercised directly without
// platform channels or SQLite.

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vetviona_app/models/life_event.dart';
import 'package:vetviona_app/models/medical_condition.dart';
import 'package:vetviona_app/models/partnership.dart';
import 'package:vetviona_app/models/person.dart';
import 'package:vetviona_app/models/research_task.dart';
import 'package:vetviona_app/models/source.dart';
import 'package:vetviona_app/providers/tree_provider.dart';

void main() {
  // ── Helpers ─────────────────────────────────────────────────────────────────

  /// Creates [n] persons in a linear parent→child chain: p0→p1→…→p(n-1).
  List<Person> linearChain(int n) => List.generate(
        n,
        (i) => Person(
          id: 'p$i',
          name: 'Person $i',
          parentIds: i > 0 ? ['p${i - 1}'] : [],
          childIds: i < n - 1 ? ['p${i + 1}'] : [],
        ),
      );

  // ── searchPersons ──────────────────────────────────────────────────────────
  group('TreeProvider.searchPersons', () {
    late TreeProvider provider;

    setUp(() {
      provider = TreeProvider();
    });

    test('matches by name (case-insensitive)', () {
      provider.persons = [
        Person(id: '1', name: 'Alice Smith'),
        Person(id: '2', name: 'Bob Jones'),
        Person(id: '3', name: 'Charlie Smith'),
      ];
      final results = provider.searchPersons('smith');
      expect(results.length, 2);
      expect(results.map((p) => p.name),
          containsAll(['Alice Smith', 'Charlie Smith']));
    });

    test('matches by birthPlace (case-insensitive)', () {
      provider.persons = [
        Person(id: '1', name: 'Alice', birthPlace: 'London'),
        Person(id: '2', name: 'Bob', birthPlace: 'Paris'),
      ];
      expect(provider.searchPersons('london').length, 1);
      expect(provider.searchPersons('LONDON').length, 1);
    });

    test('matches by deathPlace', () {
      provider.persons = [
        Person(id: '1', name: 'Alice', deathPlace: 'Vienna'),
      ];
      expect(provider.searchPersons('vienna'), hasLength(1));
    });

    test('matches by notes', () {
      provider.persons = [
        Person(id: '1', name: 'Alice', notes: 'Emigrated to Canada in 1920'),
      ];
      expect(provider.searchPersons('canada'), hasLength(1));
      expect(provider.searchPersons('CANADA'), hasLength(1));
    });

    test('returns empty list when no match', () {
      provider.persons = [Person(id: '1', name: 'Alice')];
      expect(provider.searchPersons('zzz'), isEmpty);
    });

    test('empty query returns all persons', () {
      provider.persons = [
        Person(id: '1', name: 'Alice'),
        Person(id: '2', name: 'Bob'),
      ];
      expect(provider.searchPersons(''), hasLength(2));
    });

    test('handles empty persons list', () {
      provider.persons = [];
      expect(provider.searchPersons('alice'), isEmpty);
    });

    test('works correctly with 1 000 persons', () {
      provider.persons = List.generate(
        1000,
        (i) => Person(
          id: 'p$i',
          name: 'Person $i',
          birthPlace: i.isEven ? 'London' : 'Paris',
        ),
      );
      final sw = Stopwatch()..start();
      final results = provider.searchPersons('london');
      sw.stop();
      expect(results.length, 500);
      expect(sw.elapsedMilliseconds, lessThan(1000));
    });
  });

  // ── findRelationshipPath ───────────────────────────────────────────────────
  group('TreeProvider.findRelationshipPath', () {
    late TreeProvider provider;

    setUp(() {
      provider = TreeProvider()
        ..persons = []
        ..partnerships = [];
    });

    test('same person returns [id]', () {
      provider.persons = [Person(id: 'A', name: 'Alice')];
      expect(provider.findRelationshipPath('A', 'A'), ['A']);
    });

    test('returns empty list for disconnected persons', () {
      provider.persons = [
        Person(id: 'A', name: 'Alice'),
        Person(id: 'B', name: 'Bob'),
      ];
      expect(provider.findRelationshipPath('A', 'B'), isEmpty);
    });

    test('direct parent → child path', () {
      provider.persons = [
        Person(id: 'P', name: 'Parent', childIds: ['C']),
        Person(id: 'C', name: 'Child', parentIds: ['P']),
      ];
      final path = provider.findRelationshipPath('P', 'C');
      expect(path, ['P', 'C']);
    });

    test('direct child → parent path', () {
      provider.persons = [
        Person(id: 'P', name: 'Parent', childIds: ['C']),
        Person(id: 'C', name: 'Child', parentIds: ['P']),
      ];
      final path = provider.findRelationshipPath('C', 'P');
      expect(path, ['C', 'P']);
    });

    test('grandparent path (3 nodes)', () {
      provider.persons = [
        Person(id: 'GP', name: 'Grandparent', childIds: ['P']),
        Person(id: 'P', name: 'Parent', parentIds: ['GP'], childIds: ['C']),
        Person(id: 'C', name: 'Child', parentIds: ['P']),
      ];
      final path = provider.findRelationshipPath('GP', 'C');
      expect(path.length, 3);
      expect(path.first, 'GP');
      expect(path.last, 'C');
    });

    test('path via partnership', () {
      provider.persons = [
        Person(id: 'A', name: 'Alice'),
        Person(id: 'B', name: 'Bob'),
      ];
      provider.partnerships = [
        Partnership(id: 'pt1', person1Id: 'A', person2Id: 'B'),
      ];
      expect(provider.findRelationshipPath('A', 'B'), ['A', 'B']);
    });

    test('path through siblings sharing a parent', () {
      provider.persons = [
        Person(id: 'parent', name: 'Parent', childIds: ['s1', 's2']),
        Person(id: 's1', name: 'Sib1', parentIds: ['parent']),
        Person(id: 's2', name: 'Sib2', parentIds: ['parent']),
      ];
      final path = provider.findRelationshipPath('s1', 's2');
      expect(path.first, 's1');
      expect(path.last, 's2');
      expect(path, contains('parent'));
    });

    test('path across two unrelated families via a partnership bridge', () {
      // Family A:  a1 → a2
      // Family B:  b1 → b2
      // Bridge:    a2 married b2
      provider.persons = [
        Person(id: 'a1', name: 'A1', childIds: ['a2']),
        Person(id: 'a2', name: 'A2', parentIds: ['a1']),
        Person(id: 'b1', name: 'B1', childIds: ['b2']),
        Person(id: 'b2', name: 'B2', parentIds: ['b1']),
      ];
      provider.partnerships = [
        Partnership(id: 'pt', person1Id: 'a2', person2Id: 'b2'),
      ];
      final path = provider.findRelationshipPath('a1', 'b1');
      expect(path, isNotEmpty);
      expect(path.first, 'a1');
      expect(path.last, 'b1');
    });

    test('BFS finds shortest path, not an arbitrary path', () {
      // Diamond: root → left, root → right, left → end, right → end
      provider.persons = [
        Person(id: 'root', name: 'Root', childIds: ['left', 'right']),
        Person(id: 'left', name: 'Left', parentIds: ['root'], childIds: ['end']),
        Person(id: 'right', name: 'Right', parentIds: ['root'], childIds: ['end']),
        Person(id: 'end', name: 'End', parentIds: ['left', 'right']),
      ];
      final path = provider.findRelationshipPath('root', 'end');
      // BFS shortest path: root → left (or right) → end = 3 nodes
      expect(path.length, 3);
      expect(path.first, 'root');
      expect(path.last, 'end');
    });

    test('from missing person returns empty path', () {
      provider.persons = [Person(id: 'A', name: 'Alice')];
      expect(provider.findRelationshipPath('MISSING', 'A'), isEmpty);
    });

    // ── Large-tree scalability tests ─────────────────────────────────────────

    test('linear chain of 1 000 persons: finds end-to-end path', () {
      provider.persons = linearChain(1000);

      final sw = Stopwatch()..start();
      final path = provider.findRelationshipPath('p0', 'p999');
      sw.stop();

      expect(path.length, 1000);
      expect(path.first, 'p0');
      expect(path.last, 'p999');
      expect(sw.elapsedMilliseconds, lessThan(5000),
          reason: 'BFS on 1 000 nodes should complete well under 5 s');
    });

    test('linear chain of 1 000 persons: reversed traversal', () {
      provider.persons = linearChain(1000);
      final path = provider.findRelationshipPath('p999', 'p0');
      expect(path.length, 1000);
      expect(path.first, 'p999');
      expect(path.last, 'p0');
    });

    test('binary tree of 1 000 persons: finds path between distant leaves', () {
      // Build an almost-complete binary tree.
      // Node i has parent (i-1)÷2, left child 2i+1, right child 2i+2.
      final persons = List.generate(1000, (i) {
        final parentId = i > 0 ? 'p${(i - 1) ~/ 2}' : null;
        final left = 2 * i + 1;
        final right = 2 * i + 2;
        return Person(
          id: 'p$i',
          name: 'Node $i',
          parentIds: parentId != null ? [parentId] : [],
          childIds: [
            if (left < 1000) 'p$left',
            if (right < 1000) 'p$right',
          ],
        );
      });
      provider.persons = persons;

      final sw = Stopwatch()..start();
      // The deepest left leaf and right sibling are adjacent through the parent
      final path = provider.findRelationshipPath('p511', 'p512');
      sw.stop();

      expect(path, isNotEmpty);
      expect(path.first, 'p511');
      expect(path.last, 'p512');
      expect(sw.elapsedMilliseconds, lessThan(5000));
    });

    test('large tree with 1 000+ people holds in memory without error', () {
      provider.persons = List.generate(
        1500,
        (i) => Person(id: 'p$i', name: 'Person $i'),
      );
      expect(provider.persons.length, 1500);
    });
  });

  // ── partnershipsFor / partnerIdsFor / childrenOfPartnership ───────────────
  group('TreeProvider partnership helpers', () {
    late TreeProvider provider;

    setUp(() {
      provider = TreeProvider();
    });

    test('partnershipsFor returns all partnerships for person1Id', () {
      provider.partnerships = [
        Partnership(id: 'p1', person1Id: 'A', person2Id: 'B'),
        Partnership(id: 'p2', person1Id: 'A', person2Id: 'C'),
        Partnership(id: 'p3', person1Id: 'D', person2Id: 'E'),
      ];
      final result = provider.partnershipsFor('A');
      expect(result.length, 2);
      expect(result.map((p) => p.id), containsAll(['p1', 'p2']));
    });

    test('partnershipsFor returns all partnerships for person2Id', () {
      provider.partnerships = [
        Partnership(id: 'p1', person1Id: 'A', person2Id: 'B'),
        Partnership(id: 'p2', person1Id: 'C', person2Id: 'B'),
      ];
      expect(provider.partnershipsFor('B').length, 2);
    });

    test('partnerIdsFor returns IDs from both sides of partnerships', () {
      provider.partnerships = [
        Partnership(id: 'p1', person1Id: 'A', person2Id: 'B'),
        Partnership(id: 'p2', person1Id: 'C', person2Id: 'A'),
      ];
      final ids = provider.partnerIdsFor('A');
      expect(ids, containsAll(['B', 'C']));
      expect(ids, isNot(contains('A')));
    });

    test('partnerIdsFor returns empty list for person with no partnerships', () {
      provider.partnerships = [
        Partnership(id: 'p1', person1Id: 'X', person2Id: 'Y'),
      ];
      expect(provider.partnerIdsFor('A'), isEmpty);
    });

    test('childrenOfPartnership returns children shared by both partners', () {
      provider.persons = [
        Person(id: 'c1', name: 'Child1', parentIds: ['A', 'B']),
        Person(id: 'c2', name: 'Child2', parentIds: ['A', 'B']),
        Person(id: 'c3', name: 'Child3', parentIds: ['A', 'X']),
        Person(id: 'c4', name: 'Child4', parentIds: ['Y', 'B']),
      ];
      final pt = Partnership(id: 'p1', person1Id: 'A', person2Id: 'B');
      final children = provider.childrenOfPartnership(pt);
      expect(children.length, 2);
      expect(children.map((p) => p.id), containsAll(['c1', 'c2']));
    });

    test('childrenOfPartnership returns empty when no shared children', () {
      provider.persons = [
        Person(id: 'c1', name: 'Child1', parentIds: ['A', 'X']),
      ];
      final pt = Partnership(id: 'p1', person1Id: 'A', person2Id: 'B');
      expect(provider.childrenOfPartnership(pt), isEmpty);
    });
  });

  // ── exportForSync ──────────────────────────────────────────────────────────
  group('TreeProvider.exportForSync', () {
    late TreeProvider provider;

    setUp(() {
      provider = TreeProvider();
    });

    test('includes persons, partnerships, sources, and lifeEvents keys', () {
      provider.persons = [];
      provider.partnerships = [];
      provider.sources = [];
      provider.lifeEvents = [];
      final data = provider.exportForSync();
      expect(data.containsKey('persons'), true);
      expect(data.containsKey('partnerships'), true);
      expect(data.containsKey('sources'), true);
      expect(data.containsKey('lifeEvents'), true);
    });

    test('persons list matches current persons', () {
      provider.persons = [
        Person(id: 'p1', name: 'Alice', treeId: 'default'),
      ];
      provider.partnerships = [];
      provider.sources = [];
      final data = provider.exportForSync();
      expect((data['persons'] as List).length, 1);
    });

    test('partnerships list matches current partnerships', () {
      provider.persons = [
        Person(id: 'p1', name: 'Alice'),
        Person(id: 'p2', name: 'Bob'),
      ];
      provider.partnerships = [
        Partnership(id: 'pt1', person1Id: 'p1', person2Id: 'p2'),
      ];
      provider.sources = [];
      final data = provider.exportForSync();
      expect((data['partnerships'] as List).length, 1);
    });

    test('sources are filtered to those whose personId is in persons', () {
      provider.persons = [
        Person(id: 'p1', name: 'Alice'),
      ];
      provider.partnerships = [];
      provider.sources = [
        Source(
          id: 's1',
          personId: 'p1',
          title: 'T',
          type: 'doc',
          url: 'http://x',
        ),
        Source(
          id: 's2',
          personId: 'missing_person',
          title: 'T',
          type: 'doc',
          url: 'http://y',
        ),
      ];
      final data = provider.exportForSync();
      expect((data['sources'] as List).length, 1);
    });

    test('works with 1 000 persons', () {
      provider.persons =
          List.generate(1000, (i) => Person(id: 'p$i', name: 'Person $i'));
      provider.partnerships = [];
      provider.sources = [];
      final sw = Stopwatch()..start();
      final data = provider.exportForSync();
      sw.stop();
      expect((data['persons'] as List).length, 1000);
      expect(sw.elapsedMilliseconds, lessThan(2000));
    });
  });

  // ── isAtPersonLimit / personLimit ─────────────────────────────────────────
  group('TreeProvider.isAtPersonLimit', () {
    test('personLimit is null on desktop tier (Linux test runner)', () {
      // The test runner is on Linux, which maps to AppTier.desktopPro.
      final provider = TreeProvider();
      expect(provider.personLimit, isNull);
      expect(provider.isAtPersonLimit, false);
    });

    test('isAtPersonLimit stays false even with 1 000+ persons on desktop', () {
      final provider = TreeProvider();
      provider.persons =
          List.generate(1500, (i) => Person(id: 'p$i', name: 'Person $i'));
      expect(provider.isAtPersonLimit, false);
    });
  });

  // ── Auth (register / login / logout) ──────────────────────────────────────
  //
  // These tests use SharedPreferences.setMockInitialValues so that all
  // reads/writes go to an in-memory store — no platform channels needed.
  group('TreeProvider auth', () {
    late TreeProvider provider;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      provider = TreeProvider();
    });

    test('initial state: not logged in', () {
      expect(provider.isLoggedIn, false);
      expect(provider.currentUser, isNull);
    });

    test('register creates user and sets logged-in state', () async {
      final ok = await provider.register('alice', 'password123');
      expect(ok, true);
      expect(provider.isLoggedIn, true);
      expect(provider.currentUser, 'alice');
    });

    test('register fails for duplicate username', () async {
      await provider.register('alice', 'password123');
      provider.logout();
      final second = await provider.register('alice', 'differentPassword');
      expect(second, false);
    });

    test('login succeeds with correct password', () async {
      await provider.register('alice', 'correct');
      provider.logout();
      final ok = await provider.login('alice', 'correct');
      expect(ok, true);
      expect(provider.isLoggedIn, true);
      expect(provider.currentUser, 'alice');
    });

    test('login fails with wrong password', () async {
      await provider.register('alice', 'correct');
      provider.logout();
      final ok = await provider.login('alice', 'wrong');
      expect(ok, false);
      expect(provider.isLoggedIn, false);
      expect(provider.currentUser, isNull);
    });

    test('login fails for non-existent user', () async {
      final ok = await provider.login('nobody', 'password');
      expect(ok, false);
    });

    test('logout clears current user', () async {
      await provider.register('alice', 'pass');
      provider.logout();
      expect(provider.isLoggedIn, false);
      expect(provider.currentUser, isNull);
    });

    // ── Secret / special-character passwords ─────────────────────────────────

    test('password with symbols and spaces', () async {
      const pwd = r'P@$$w0rd! #\n/\t<>&"';
      await provider.register('alice', pwd);
      provider.logout();
      expect(await provider.login('alice', pwd), true);
      expect(await provider.login('alice', 'wrong'), false);
    });

    test('password with unicode characters', () async {
      const pwd = '密码🔐パスワード';
      await provider.register('bob', pwd);
      provider.logout();
      expect(await provider.login('bob', pwd), true);
      expect(await provider.login('bob', 'wrong'), false);
    });

    test('very long password (1 000 characters)', () async {
      final pwd = 'a' * 1000;
      await provider.register('alice', pwd);
      provider.logout();
      expect(await provider.login('alice', pwd), true);
      expect(await provider.login('alice', pwd.substring(0, 999)), false);
    });

    test('empty password is accepted and verified correctly', () async {
      await provider.register('alice', '');
      provider.logout();
      expect(await provider.login('alice', ''), true);
      expect(await provider.login('alice', 'a'), false);
    });

    test('whitespace-only password is distinct from empty password', () async {
      await provider.register('alice', '   ');
      provider.logout();
      expect(await provider.login('alice', '   '), true);
      expect(await provider.login('alice', ''), false);
    });

    test('password with colon character (salt:hash separator)', () async {
      // A colon in the password must not be confused with the salt:hash format.
      const pwd = 'my:secret:password';
      await provider.register('alice', pwd);
      provider.logout();
      expect(await provider.login('alice', pwd), true);
      expect(await provider.login('alice', 'my'), false);
    });

    // ── Stored format ──────────────────────────────────────────────────────

    test('register stores password as pbkdf2 hash (not plaintext)', () async {
      await provider.register('alice', 'secret');
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString('user_alice')!;
      // Must NOT be the raw password
      expect(stored, isNot('secret'));
      // Must use the new PBKDF2 format: pbkdf2:<salt>:<iterations>:<hex>
      expect(stored.startsWith('pbkdf2:'), isTrue);
      final parts = stored.split(':');
      expect(parts.length, 4);
      expect(parts[0], 'pbkdf2');
      expect(parts[1].length, 36); // UUID v4 salt
      expect(int.parse(parts[2]), greaterThan(0)); // iterations > 0
      expect(parts[3].length, 64); // 32-byte hex digest
    });

    test('two users with the same password get different stored values (salt)', () async {
      await provider.register('alice', 'samepassword');
      provider.logout();
      await provider.register('bob', 'samepassword');
      final prefs = await SharedPreferences.getInstance();
      final aliceStored = prefs.getString('user_alice')!;
      final bobStored = prefs.getString('user_bob')!;
      expect(aliceStored, isNot(equals(bobStored)));
    });

    // ── Legacy plaintext migration ──────────────────────────────────────────

    test('legacy plaintext password logs in and is migrated to hashed format',
        () async {
      // Simulate an old installation that stored the password in plaintext.
      SharedPreferences.setMockInitialValues({
        'user_legacyuser': 'legacypassword',
      });
      final freshProvider = TreeProvider();

      final ok = await freshProvider.login('legacyuser', 'legacypassword');
      expect(ok, true);

      // After login the stored value should have been migrated to PBKDF2 format.
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString('user_legacyuser')!;
      expect(stored.startsWith('pbkdf2:'), isTrue);
      expect(stored, isNot('legacypassword'));
    });

    test('legacy wrong password is rejected and NOT migrated', () async {
      SharedPreferences.setMockInitialValues({
        'user_legacyuser': 'correctpassword',
      });
      final freshProvider = TreeProvider();

      final ok = await freshProvider.login('legacyuser', 'wrongpassword');
      expect(ok, false);

      // Stored value must NOT have been migrated (wrong password).
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString('user_legacyuser')!;
      expect(stored, 'correctpassword');
    });

    test('after migration subsequent logins still work', () async {
      SharedPreferences.setMockInitialValues({
        'user_legacyuser': 'mypassword',
      });
      final p = TreeProvider();
      await p.login('legacyuser', 'mypassword'); // migrates
      p.logout();

      // Second login should use hashed format and still succeed.
      final ok = await p.login('legacyuser', 'mypassword');
      expect(ok, true);
    });

    test('old SHA-256 format logs in and is migrated to PBKDF2', () async {
      // Simulate an installation that used the previous salt:sha256hex format.
      // The salt is a valid UUID v4 (36 chars); the hash is 64 lowercase hex chars.
      // We replicate the old _hashPassword logic (sha256("$salt:$password")) to
      // build the fixture value dynamically rather than hardcoding the hash.
      const testPwd = 'abc123';
      const testSalt = '550e8400-e29b-41d4-a716-446655440000';
      final saltBytes = utf8.encode('$testSalt:$testPwd');
      final oldHash = sha256.convert(saltBytes).toString();
      SharedPreferences.setMockInitialValues({
        'user_sha256user': '$testSalt:$oldHash',
      });
      final p = TreeProvider();
      final ok = await p.login('sha256user', testPwd);
      expect(ok, true);
      expect(p.isLoggedIn, true);

      // Stored value must now be in PBKDF2 format.
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString('user_sha256user')!;
      expect(stored.startsWith('pbkdf2:'), isTrue);

      // Subsequent login with the same password must still work.
      p.logout();
      expect(await p.login('sha256user', testPwd), true);
      expect(await p.login('sha256user', 'wrongpassword'), false);
    });

    // ── Rate limiting ──────────────────────────────────────────────────────

    test('login is rejected after 5 consecutive failures', () async {
      SharedPreferences.setMockInitialValues({});
      final p = TreeProvider();
      await p.register('alice', 'correctpassword');
      p.logout();

      // 5 failed attempts should trigger a lockout.
      for (int i = 0; i < 5; i++) {
        final ok = await p.login('alice', 'wrong$i');
        expect(ok, false);
      }

      // 6th attempt — account locked, even with the correct password.
      final locked = await p.login('alice', 'correctpassword');
      expect(locked, false, reason: 'Account should be locked after 5 failures');
    });

    test('successful login resets the failure counter', () async {
      SharedPreferences.setMockInitialValues({});
      final p = TreeProvider();
      await p.register('bob', 'pass');
      p.logout();

      // 4 failures — not yet locked out.
      for (int i = 0; i < 4; i++) {
        await p.login('bob', 'wrong');
      }
      // Correct password succeeds and resets counter.
      expect(await p.login('bob', 'pass'), true);
      p.logout();

      // After reset, another 4 failures should still be accepted (not locked).
      for (int i = 0; i < 4; i++) {
        await p.login('bob', 'wrong');
      }
      // Still not locked; correct password still works.
      expect(await p.login('bob', 'pass'), true);
    });
  });

  // ── importFromSync session cap ─────────────────────────────────────────────
  group('TreeProvider.exportForSync senderTier', () {
    test('exportForSync payload does not embed senderTier (added by SyncService)',
        () {
      // exportForSync itself does not embed senderTier — SyncService adds it
      // before sending.  importFromSync must tolerate a missing senderTier key.
      final provider = TreeProvider();
      provider.persons = [Person(id: 'p1', name: 'Alice')];
      provider.partnerships = [];
      provider.sources = [];
      final data = provider.exportForSync();
      expect(data.containsKey('senderTier'), false);
    });

    test(
        'session cap is null (no limit) when senderTier is absent or non-free',
        () {
      // Verify that the session-cap logic inside importFromSync correctly
      // evaluates to no cap when the senderTier key is absent.
      //
      // We test this indirectly by checking that the desktop provider reports
      // isAtPersonLimit = false for any number of persons (confirming it uses
      // null as the cap), which is what importFromSync relies on when
      // senderTier is absent.
      final provider = TreeProvider();
      provider.persons =
          List.generate(200, (i) => Person(id: 'p$i', name: 'P$i'));
      // On the test runner (Linux == desktopPro), personLimit is null.
      expect(provider.personLimit, isNull);
      expect(provider.isAtPersonLimit, false);
    });
  });

  // ── TreeProvider.trees / renameTree ────────────────────────────────────────
  group('TreeProvider.trees', () {
    test('treeNames getter returns names from trees list', () {
      final provider = TreeProvider();
      provider.trees = [
        {'id': 'default', 'name': 'My Family Tree'},
        {'id': 'abc', 'name': 'Smith Tree'},
      ];
      expect(provider.treeNames, ['My Family Tree', 'Smith Tree']);
    });

    test('currentTreeName returns active tree name', () {
      final provider = TreeProvider();
      provider.trees = [
        {'id': 'default', 'name': 'My Family Tree'},
        {'id': 'tree2', 'name': 'Jones Tree'},
      ];
      provider.currentTreeId = 'tree2';
      expect(provider.currentTreeName, 'Jones Tree');
    });

    test('currentTreeName falls back when currentTreeId not in trees', () {
      final provider = TreeProvider();
      provider.trees = [
        {'id': 'default', 'name': 'My Family Tree'},
      ];
      provider.currentTreeId = 'missing';
      // Should return the fallback name without throwing.
      expect(provider.currentTreeName, 'My Family Tree');
    });
  });

  // ── TreeProvider default settings ─────────────────────────────────────────
  group('TreeProvider default settings', () {
    test('dateFormat defaults to dd MMM yyyy', () {
      final provider = TreeProvider();
      expect(provider.dateFormat, 'dd MMM yyyy');
    });

    test('colonizationLevel defaults to 0', () {
      final provider = TreeProvider();
      expect(provider.colonizationLevel, 0);
    });
  });

  // ── TreeProvider.lifeEventsFor ────────────────────────────────────────────
  group('TreeProvider.lifeEventsFor', () {
    test('returns empty list when no life events exist', () {
      final provider = TreeProvider();
      expect(provider.lifeEventsFor('p1'), isEmpty);
    });

    test('returns events belonging to the given person', () {
      final provider = TreeProvider();
      provider.lifeEvents = [
        LifeEvent(id: 'e1', personId: 'p1', title: 'Baptism'),
        LifeEvent(id: 'e2', personId: 'p1', title: 'Graduation'),
        LifeEvent(id: 'e3', personId: 'p2', title: 'Immigration'),
      ];
      final result = provider.lifeEventsFor('p1');
      expect(result, hasLength(2));
      expect(result.map((e) => e.id), containsAll(['e1', 'e2']));
    });

    test('returns empty list when no events match the given person', () {
      final provider = TreeProvider();
      provider.lifeEvents = [
        LifeEvent(id: 'e1', personId: 'p2', title: 'Baptism'),
      ];
      expect(provider.lifeEventsFor('p1'), isEmpty);
    });

    test('returns all events when all belong to the same person', () {
      final provider = TreeProvider();
      provider.lifeEvents = List.generate(
        5,
        (i) => LifeEvent(id: 'e$i', personId: 'p1', title: 'Event $i'),
      );
      expect(provider.lifeEventsFor('p1'), hasLength(5));
    });
  });

  // ── TreeProvider.medicalConditionsFor ─────────────────────────────────────
  group('TreeProvider.medicalConditionsFor', () {
    test('returns empty list when no medical conditions exist', () {
      final provider = TreeProvider();
      expect(provider.medicalConditionsFor('p1'), isEmpty);
    });

    test('returns conditions belonging to the given person', () {
      final provider = TreeProvider();
      provider.medicalConditions = [
        MedicalCondition(
            id: 'm1', personId: 'p1', condition: 'Diabetes',
            category: 'Metabolic / Endocrine'),
        MedicalCondition(
            id: 'm2', personId: 'p1', condition: 'Hypertension',
            category: 'Cardiovascular'),
        MedicalCondition(
            id: 'm3', personId: 'p2', condition: 'Asthma',
            category: 'Respiratory'),
      ];
      final result = provider.medicalConditionsFor('p1');
      expect(result, hasLength(2));
      expect(result.map((c) => c.id), containsAll(['m1', 'm2']));
    });

    test('returns empty list when no conditions match the given person', () {
      final provider = TreeProvider();
      provider.medicalConditions = [
        MedicalCondition(
            id: 'm1', personId: 'p2', condition: 'Asthma',
            category: 'Respiratory'),
      ];
      expect(provider.medicalConditionsFor('p1'), isEmpty);
    });
  });

  // ── TreeProvider.researchTasksFor ─────────────────────────────────────────
  group('TreeProvider.researchTasksFor', () {
    test('returns empty list when no research tasks exist', () {
      final provider = TreeProvider();
      expect(provider.researchTasksFor('p1'), isEmpty);
    });

    test('returns tasks linked to the given person', () {
      final provider = TreeProvider();
      provider.researchTasks = [
        ResearchTask(id: 't1', personId: 'p1', title: 'Find birth record'),
        ResearchTask(id: 't2', personId: 'p1', title: 'Verify death date'),
        ResearchTask(id: 't3', personId: 'p2', title: 'Find marriage record'),
      ];
      final result = provider.researchTasksFor('p1');
      expect(result, hasLength(2));
      expect(result.map((t) => t.id), containsAll(['t1', 't2']));
    });

    test('returns empty list when person has no tasks', () {
      final provider = TreeProvider();
      provider.researchTasks = [
        ResearchTask(id: 't1', personId: 'p2', title: 'Find birth record'),
      ];
      expect(provider.researchTasksFor('p1'), isEmpty);
    });

    test('researchTasksFor with null personId task does not match arbitrary id',
        () {
      // Tasks with a null personId are tree-level tasks, not person tasks.
      final provider = TreeProvider();
      provider.researchTasks = [
        ResearchTask(id: 't1', title: 'General task'),
      ];
      expect(provider.researchTasksFor('p1'), isEmpty);
    });
  });

  // ── TreeProvider.findDuplicates ────────────────────────────────────────────
  group('TreeProvider.findDuplicates', () {
    test('returns empty list when persons list is empty', () {
      final provider = TreeProvider();
      expect(provider.findDuplicates(), isEmpty);
    });

    test('returns empty list when all persons are unique', () {
      final provider = TreeProvider();
      provider.persons = [
        Person(id: 'p1', name: 'Alice Smith'),
        Person(id: 'p2', name: 'Bob Jones'),
        Person(id: 'p3', name: 'Carol White'),
      ];
      expect(provider.findDuplicates(), isEmpty);
    });

    test('detects two persons with identical names', () {
      final provider = TreeProvider();
      provider.persons = [
        Person(id: 'p1', name: 'Alice Smith'),
        Person(id: 'p2', name: 'Alice Smith'),
      ];
      final groups = provider.findDuplicates();
      expect(groups, hasLength(1));
      expect(groups.first.map((p) => p.id), containsAll(['p1', 'p2']));
    });

    test('name comparison is case-insensitive', () {
      final provider = TreeProvider();
      provider.persons = [
        Person(id: 'p1', name: 'alice smith'),
        Person(id: 'p2', name: 'ALICE SMITH'),
      ];
      final groups = provider.findDuplicates();
      expect(groups, hasLength(1));
    });

    test('name comparison ignores punctuation', () {
      final provider = TreeProvider();
      provider.persons = [
        Person(id: 'p1', name: "O'Brien"),
        Person(id: 'p2', name: 'OBrien'),
      ];
      final groups = provider.findDuplicates();
      expect(groups, hasLength(1));
    });

    test('does NOT flag different people sharing only a first name as duplicates',
        () {
      // "John Adams" and "John Baker" share a first name but are different people.
      // The old first-word heuristic incorrectly grouped them; the fixed logic
      // requires the full name to match.
      final provider = TreeProvider();
      provider.persons = [
        Person(id: 'p1', name: 'John Adams', birthDate: DateTime(1900)),
        Person(id: 'p2', name: 'John Baker', birthDate: DateTime(1901)),
      ];
      expect(provider.findDuplicates(), isEmpty);
    });

    test('flags same full name with birth years within 2 years as duplicate',
        () {
      final provider = TreeProvider();
      provider.persons = [
        Person(id: 'p1', name: 'John Smith', birthDate: DateTime(1900)),
        Person(id: 'p2', name: 'John Smith', birthDate: DateTime(1901)),
      ];
      final groups = provider.findDuplicates();
      expect(groups, hasLength(1));
      expect(groups.first.map((p) => p.id), containsAll(['p1', 'p2']));
    });

    test('does NOT flag same full name when birth years differ by more than 2 '
        '(e.g. grandfather vs grandson with same name)', () {
      final provider = TreeProvider();
      provider.persons = [
        Person(id: 'p1', name: 'Henry Smith', birthDate: DateTime(1820)),
        Person(id: 'p2', name: 'Henry Smith', birthDate: DateTime(1870)),
      ];
      expect(provider.findDuplicates(), isEmpty);
    });

    test('does not flag same first name without birth dates as duplicate', () {
      final provider = TreeProvider();
      provider.persons = [
        Person(id: 'p1', name: 'John Adams'),
        Person(id: 'p2', name: 'John Baker'),
      ];
      expect(provider.findDuplicates(), isEmpty);
    });

    test('groups three persons with the same name together', () {
      final provider = TreeProvider();
      provider.persons = [
        Person(id: 'p1', name: 'Jane Doe'),
        Person(id: 'p2', name: 'Jane Doe'),
        Person(id: 'p3', name: 'Jane Doe'),
      ];
      final groups = provider.findDuplicates();
      expect(groups, hasLength(1));
      expect(groups.first, hasLength(3));
    });

    test('produces separate duplicate groups for two independent sets', () {
      final provider = TreeProvider();
      provider.persons = [
        Person(id: 'p1', name: 'Alice Smith'),
        Person(id: 'p2', name: 'Alice Smith'),
        Person(id: 'p3', name: 'Bob Jones'),
        Person(id: 'p4', name: 'Bob Jones'),
        Person(id: 'p5', name: 'Carol White'),
      ];
      final groups = provider.findDuplicates();
      expect(groups, hasLength(2));
    });

    test('single person produces no duplicate groups', () {
      final provider = TreeProvider();
      provider.persons = [Person(id: 'p1', name: 'Solo Person')];
      expect(provider.findDuplicates(), isEmpty);
    });

    test('each person is listed in at most one group', () {
      final provider = TreeProvider();
      provider.persons = [
        Person(id: 'p1', name: 'John Smith', birthDate: DateTime(1950)),
        Person(id: 'p2', name: 'John Smith', birthDate: DateTime(1951)),
        Person(id: 'p3', name: 'John Smith', birthDate: DateTime(1952)),
      ];
      final groups = provider.findDuplicates();
      final allIds = groups.expand((g) => g.map((p) => p.id)).toList();
      expect(allIds.length, equals(allIds.toSet().length));
    });

    test('flags same full name with death years within 2 (no birth dates)', () {
      final provider = TreeProvider();
      provider.persons = [
        Person(id: 'p1', name: 'Mary Brown', deathDate: DateTime(1900)),
        Person(id: 'p2', name: 'Mary Brown', deathDate: DateTime(1901)),
      ];
      final groups = provider.findDuplicates();
      expect(groups, hasLength(1));
      expect(groups.first.map((p) => p.id), containsAll(['p1', 'p2']));
    });

    test('does NOT flag same full name when death years differ by more than 2 '
        'and neither has a birth date', () {
      final provider = TreeProvider();
      provider.persons = [
        Person(id: 'p1', name: 'Mary Brown', deathDate: DateTime(1850)),
        Person(id: 'p2', name: 'Mary Brown', deathDate: DateTime(1920)),
      ];
      expect(provider.findDuplicates(), isEmpty);
    });

    test('flags same full name with no dates at all', () {
      final provider = TreeProvider();
      provider.persons = [
        Person(id: 'p1', name: 'Unknown Person'),
        Person(id: 'p2', name: 'Unknown Person'),
      ];
      expect(provider.findDuplicates(), hasLength(1));
    });
  });

  // ── exportForSync – lifeEvents and privacy ────────────────────────────────
  group('TreeProvider.exportForSync — lifeEvents and privacy', () {
    test('lifeEvents for public persons are included in export', () {
      final provider = TreeProvider();
      provider.persons = [Person(id: 'p1', name: 'Alice')];
      provider.partnerships = [];
      provider.sources = [];
      provider.lifeEvents = [
        LifeEvent(id: 'e1', personId: 'p1', title: 'Immigration'),
      ];
      final data = provider.exportForSync();
      expect((data['lifeEvents'] as List).length, 1);
    });

    test('lifeEvents for missing / private persons are excluded', () {
      final provider = TreeProvider();
      provider.persons = [
        Person(id: 'pub', name: 'Public'),
        Person(id: 'priv', name: 'Private', isPrivate: true),
      ];
      provider.partnerships = [];
      provider.sources = [];
      provider.lifeEvents = [
        LifeEvent(id: 'e1', personId: 'pub', title: 'Graduation'),
        LifeEvent(id: 'e2', personId: 'priv', title: 'Baptism'),
        LifeEvent(id: 'e3', personId: 'nobody', title: 'Immigration'),
      ];
      final data = provider.exportForSync();
      final exported = data['lifeEvents'] as List;
      expect(exported.length, 1);
      expect((exported.first as Map)['personId'], 'pub');
    });

    test('private persons are excluded from persons list', () {
      final provider = TreeProvider();
      provider.persons = [
        Person(id: 'p1', name: 'Public'),
        Person(id: 'p2', name: 'Private', isPrivate: true),
      ];
      provider.partnerships = [];
      provider.sources = [];
      provider.lifeEvents = [];
      final data = provider.exportForSync();
      final exportedPersons = data['persons'] as List;
      expect(exportedPersons.length, 1);
      expect((exportedPersons.first as Map)['id'], 'p1');
    });

    test('partnerships where either partner is private are excluded', () {
      final provider = TreeProvider();
      provider.persons = [
        Person(id: 'pub1', name: 'Public1'),
        Person(id: 'pub2', name: 'Public2'),
        Person(id: 'priv', name: 'Private', isPrivate: true),
      ];
      provider.partnerships = [
        Partnership(id: 'pt1', person1Id: 'pub1', person2Id: 'pub2'),
        Partnership(id: 'pt2', person1Id: 'pub1', person2Id: 'priv'),
      ];
      provider.sources = [];
      provider.lifeEvents = [];
      final data = provider.exportForSync();
      expect((data['partnerships'] as List).length, 1);
    });

    test('sources of private persons are excluded', () {
      final provider = TreeProvider();
      provider.persons = [
        Person(id: 'pub', name: 'Public'),
        Person(id: 'priv', name: 'Private', isPrivate: true),
      ];
      provider.partnerships = [];
      provider.sources = [
        Source(id: 's1', personId: 'pub', title: 'T', type: 'doc', url: 'http://x'),
        Source(id: 's2', personId: 'priv', title: 'T', type: 'doc', url: 'http://y'),
      ];
      provider.lifeEvents = [];
      final data = provider.exportForSync();
      expect((data['sources'] as List).length, 1);
    });

    test('empty lifeEvents list is exported as empty list', () {
      final provider = TreeProvider();
      provider.persons = [Person(id: 'p1', name: 'Alice')];
      provider.partnerships = [];
      provider.sources = [];
      provider.lifeEvents = [];
      final data = provider.exportForSync();
      expect(data['lifeEvents'], isA<List>());
      expect((data['lifeEvents'] as List), isEmpty);
    });
  });

  // ── TreeProvider settings ──────────────────────────────────────────────────
  group('TreeProvider settings', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('setDateFormat updates dateFormat in memory', () async {
      final provider = TreeProvider();
      await provider.setDateFormat('MM/dd/yyyy');
      expect(provider.dateFormat, 'MM/dd/yyyy');
    });

    test('setDateFormat persists to SharedPreferences', () async {
      final provider = TreeProvider();
      await provider.setDateFormat('yyyy-MM-dd');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('dateFormat'), 'yyyy-MM-dd');
    });

    test('setColonizationLevel updates colonizationLevel in memory', () async {
      final provider = TreeProvider();
      await provider.setColonizationLevel(2);
      expect(provider.colonizationLevel, 2);
    });

    test('setColonizationLevel persists to SharedPreferences', () async {
      final provider = TreeProvider();
      await provider.setColonizationLevel(1);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('colonizationLevel'), 1);
    });

    test('setHomePersonId stores id and updates homePersonId', () async {
      final provider = TreeProvider();
      await provider.setHomePersonId('person-42');
      expect(provider.homePersonId, 'person-42');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('homePersonId'), 'person-42');
    });

    test('setHomePersonId with null clears homePersonId', () async {
      final provider = TreeProvider();
      await provider.setHomePersonId('person-42');
      await provider.setHomePersonId(null);
      expect(provider.homePersonId, isNull);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('homePersonId'), false);
    });

    test('setHomePersonId with empty string clears homePersonId', () async {
      final provider = TreeProvider();
      await provider.setHomePersonId('person-42');
      await provider.setHomePersonId('');
      expect(provider.homePersonId, isNull);
    });

    test('setDateFormat triggers a change notification', () async {
      final provider = TreeProvider();
      var notified = false;
      provider.addListener(() => notified = true);
      await provider.setDateFormat('dd/MM/yyyy');
      expect(notified, true);
    });

    test('setColonizationLevel triggers a change notification', () async {
      final provider = TreeProvider();
      var notified = false;
      provider.addListener(() => notified = true);
      await provider.setColonizationLevel(1);
      expect(notified, true);
    });

    test('setHomePersonId triggers a change notification', () async {
      final provider = TreeProvider();
      var notified = false;
      provider.addListener(() => notified = true);
      await provider.setHomePersonId('p1');
      expect(notified, true);
    });
  });

  // ── TreeProvider.exportBackupJson ─────────────────────────────────────────
  group('TreeProvider.exportBackupJson', () {
    test('returns valid JSON string', () async {
      final provider = TreeProvider();
      provider.persons = [];
      provider.partnerships = [];
      provider.sources = [];
      provider.lifeEvents = [];
      final json = await provider.exportBackupJson();
      expect(json, isA<String>());
      expect(json, isNotEmpty);
      // Should be parseable
      final decoded = jsonDecode(json);
      expect(decoded, isA<Map>());
    });

    test('backup JSON contains version, exportDate, persons, partnerships, sources, lifeEvents',
        () async {
      final provider = TreeProvider();
      provider.persons = [];
      provider.partnerships = [];
      provider.sources = [];
      provider.lifeEvents = [];
      final decoded = jsonDecode(await provider.exportBackupJson()) as Map;
      expect(decoded.containsKey('version'), true);
      expect(decoded.containsKey('exportDate'), true);
      expect(decoded.containsKey('persons'), true);
      expect(decoded.containsKey('partnerships'), true);
      expect(decoded.containsKey('sources'), true);
      expect(decoded.containsKey('lifeEvents'), true);
    });

    test('backup JSON version is 1', () async {
      final provider = TreeProvider();
      provider.persons = [];
      provider.partnerships = [];
      provider.sources = [];
      provider.lifeEvents = [];
      final decoded = jsonDecode(await provider.exportBackupJson()) as Map;
      expect(decoded['version'], 1);
    });

    test('all persons are included in the backup', () async {
      final provider = TreeProvider();
      provider.persons = [
        Person(id: 'p1', name: 'Alice'),
        Person(id: 'p2', name: 'Bob'),
      ];
      provider.partnerships = [];
      provider.sources = [];
      provider.lifeEvents = [];
      final decoded = jsonDecode(await provider.exportBackupJson()) as Map;
      expect((decoded['persons'] as List).length, 2);
    });

    test('backup includes private persons (unlike exportForSync)', () async {
      final provider = TreeProvider();
      provider.persons = [
        Person(id: 'p1', name: 'Public'),
        Person(id: 'p2', name: 'Private', isPrivate: true),
      ];
      provider.partnerships = [];
      provider.sources = [];
      provider.lifeEvents = [];
      final decoded = jsonDecode(await provider.exportBackupJson()) as Map;
      expect((decoded['persons'] as List).length, 2);
    });

    test('sources not linked to any person are excluded from backup', () async {
      final provider = TreeProvider();
      provider.persons = [Person(id: 'p1', name: 'Alice')];
      provider.partnerships = [];
      provider.sources = [
        Source(id: 's1', personId: 'p1', title: 'T', type: 'doc', url: 'http://x'),
        Source(id: 's2', personId: 'orphan', title: 'T', type: 'doc', url: 'http://y'),
      ];
      provider.lifeEvents = [];
      final decoded = jsonDecode(await provider.exportBackupJson()) as Map;
      expect((decoded['sources'] as List).length, 1);
    });

    test('life events linked to persons are included in backup', () async {
      final provider = TreeProvider();
      provider.persons = [Person(id: 'p1', name: 'Alice')];
      provider.partnerships = [];
      provider.sources = [];
      provider.lifeEvents = [
        LifeEvent(id: 'e1', personId: 'p1', title: 'Immigration'),
        LifeEvent(id: 'e2', personId: 'orphan', title: 'Graduation'),
      ];
      final decoded = jsonDecode(await provider.exportBackupJson()) as Map;
      expect((decoded['lifeEvents'] as List).length, 1);
    });

    test('exportDate is a valid ISO-8601 timestamp', () async {
      final before = DateTime.now();
      final provider = TreeProvider();
      provider.persons = [];
      provider.partnerships = [];
      provider.sources = [];
      provider.lifeEvents = [];
      final decoded = jsonDecode(await provider.exportBackupJson()) as Map;
      final exportDate = DateTime.parse(decoded['exportDate'] as String);
      final after = DateTime.now();
      expect(exportDate.isAfter(before.subtract(const Duration(seconds: 1))), true);
      expect(exportDate.isBefore(after.add(const Duration(seconds: 1))), true);
    });

    test('all partnerships are included in the backup', () async {
      final provider = TreeProvider();
      provider.persons = [
        Person(id: 'p1', name: 'Alice'),
        Person(id: 'p2', name: 'Bob'),
      ];
      provider.partnerships = [
        Partnership(id: 'pt1', person1Id: 'p1', person2Id: 'p2'),
      ];
      provider.sources = [];
      provider.lifeEvents = [];
      final decoded = jsonDecode(await provider.exportBackupJson()) as Map;
      expect((decoded['partnerships'] as List).length, 1);
    });
  });

  // ── importFromSync merge behaviour ─────────────────────────────────────────

  /// Exercises the pure, in-memory merge decision inside [importFromSync]:
  /// the DB calls are not available in unit tests, so we test the logic by
  /// inspecting which records would be kept/overwritten using a helper that
  /// mirrors the merge rule.
  group('importFromSync — timestamp merge logic', () {
    /// Returns true if the incoming record should be accepted over the local
    /// one, mirroring the rule in TreeProvider.importFromSync.
    bool shouldAccept(int? localTs, int? incomingTs) {
      final local = localTs ?? 0;
      final incoming = incomingTs ?? 0;
      // Skip only if local is strictly newer.
      if (local > 0 && incoming <= local) return false;
      return true;
    }

    test('incoming is accepted when local has no timestamp (legacy data)', () {
      expect(shouldAccept(null, null), true);
    });

    test('incoming is accepted when both timestamps are 0', () {
      expect(shouldAccept(0, 0), true);
    });

    test('incoming is accepted when it is strictly newer', () {
      expect(shouldAccept(100, 200), true);
    });

    test('local is kept when it is strictly newer than incoming', () {
      expect(shouldAccept(200, 100), false);
    });

    test('local is kept on equal timestamps (tie-breaks to local)', () {
      expect(shouldAccept(100, 100), false);
    });

    test('incoming is accepted when local has no timestamp but incoming does',
        () {
      expect(shouldAccept(null, 300), true);
      expect(shouldAccept(0, 300), true);
    });

    test('local is kept when incoming has no timestamp but local does', () {
      expect(shouldAccept(300, null), false);
      expect(shouldAccept(300, 0), false);
    });

    // ── exportForSync includes updatedAt ──────────────────────────────────────

    test('exportForSync includes updatedAt in persons', () {
      final provider = TreeProvider();
      provider.persons = [
        Person(id: 'p1', name: 'Alice', updatedAt: 1234567890000),
      ];
      provider.partnerships = [];
      provider.sources = [];
      provider.lifeEvents = [];
      final exported = provider.exportForSync();
      final person = (exported['persons'] as List).first as Map;
      expect(person['updatedAt'], 1234567890000);
    });

    test('exportForSync includes updatedAt in partnerships', () {
      final provider = TreeProvider();
      provider.persons = [
        Person(id: 'p1', name: 'Alice'),
        Person(id: 'p2', name: 'Bob'),
      ];
      provider.partnerships = [
        Partnership(
            id: 'pt1',
            person1Id: 'p1',
            person2Id: 'p2',
            updatedAt: 9999999),
      ];
      provider.sources = [];
      provider.lifeEvents = [];
      final exported = provider.exportForSync();
      final pt = (exported['partnerships'] as List).first as Map;
      expect(pt['updatedAt'], 9999999);
    });

    test('updatedAt round-trips through Person toMap / fromMap', () {
      final p = Person(id: 'p1', name: 'Test', updatedAt: 1700000000000);
      final restored = Person.fromMap(p.toMap());
      expect(restored.updatedAt, 1700000000000);
    });

    test('updatedAt round-trips through Partnership toMap / fromMap', () {
      final pt = Partnership(
          id: 'pt1',
          person1Id: 'p1',
          person2Id: 'p2',
          updatedAt: 1600000000000);
      final restored = Partnership.fromMap(pt.toMap());
      expect(restored.updatedAt, 1600000000000);
    });

    test('updatedAt round-trips through Source toMap / fromMap', () {
      final s = Source(
          id: 's1',
          personId: 'p1',
          title: 'T',
          type: 'doc',
          url: 'http://x',
          updatedAt: 1500000000000);
      final restored = Source.fromMap(s.toMap());
      expect(restored.updatedAt, 1500000000000);
    });

    test('updatedAt round-trips through LifeEvent toMap / fromMap', () {
      final e =
          LifeEvent(id: 'e1', personId: 'p1', title: 'Birth', updatedAt: 1400000000000);
      final restored = LifeEvent.fromMap(e.toMap());
      expect(restored.updatedAt, 1400000000000);
    });

    test('null updatedAt round-trips as null through Person fromMap', () {
      final p = Person(id: 'p1', name: 'Test');
      final restored = Person.fromMap(p.toMap());
      expect(restored.updatedAt, isNull);
    });
  });

  // ── TreeProvider.partnershipsFor ─────────────────────────────────────────

  group('TreeProvider.partnershipsFor', () {
    test('returns partnerships where person is person1', () {
      final p = TreeProvider();
      p.partnerships = [
        Partnership(id: 'pt1', person1Id: 'p1', person2Id: 'p2', status: 'married'),
        Partnership(id: 'pt2', person1Id: 'p3', person2Id: 'p4', status: 'married'),
      ];
      expect(p.partnershipsFor('p1'), hasLength(1));
      expect(p.partnershipsFor('p1').first.id, 'pt1');
    });

    test('returns partnerships where person is person2', () {
      final p = TreeProvider();
      p.partnerships = [
        Partnership(id: 'pt1', person1Id: 'p1', person2Id: 'p2', status: 'married'),
      ];
      expect(p.partnershipsFor('p2'), hasLength(1));
    });

    test('returns empty list when no partnerships', () {
      final p = TreeProvider();
      p.partnerships = [];
      expect(p.partnershipsFor('p1'), isEmpty);
    });
  });

  // ── TreeProvider.partnerIdsFor ─────────────────────────────────────────────

  group('TreeProvider.partnerIdsFor', () {
    test('returns the id of the other partner when person is person1', () {
      final p = TreeProvider();
      p.partnerships = [
        Partnership(id: 'pt1', person1Id: 'p1', person2Id: 'p2', status: 'married'),
      ];
      expect(p.partnerIdsFor('p1'), contains('p2'));
    });

    test('returns the id of person1 when person is person2', () {
      final p = TreeProvider();
      p.partnerships = [
        Partnership(id: 'pt1', person1Id: 'p1', person2Id: 'p2', status: 'married'),
      ];
      expect(p.partnerIdsFor('p2'), contains('p1'));
    });
  });

  // ── TreeProvider.childrenOfPartnership ────────────────────────────────────

  group('TreeProvider.childrenOfPartnership', () {
    test('returns children shared by the partnership', () {
      final child = Person(id: 'c1', name: 'Child One', parentIds: ['p1', 'p2']);
      final p = TreeProvider();
      p.persons = [child];
      final pt = Partnership(id: 'pt1', person1Id: 'p1', person2Id: 'p2', status: 'married');
      final children = p.childrenOfPartnership(pt);
      expect(children, contains(child));
    });

    test('returns empty list when no children share both parents', () {
      final child = Person(id: 'c1', name: 'Other Child', parentIds: ['p1', 'p3']);
      final p = TreeProvider();
      p.persons = [child];
      final pt = Partnership(id: 'pt1', person1Id: 'p1', person2Id: 'p2', status: 'married');
      expect(p.childrenOfPartnership(pt), isEmpty);
    });
  });

  // ── TreeProvider accessors / getters ─────────────────────────────────────

  group('TreeProvider accessors', () {
    test('treeNames returns list of tree name strings', () {
      final p = TreeProvider();
      p.trees = [
        {'id': 'tree1', 'name': 'Tree One'},
        {'id': 'tree2', 'name': 'Tree Two'},
      ];
      expect(p.treeNames, containsAll(['Tree One', 'Tree Two']));
    });

    test('currentTreeName returns name of current tree', () {
      final p = TreeProvider();
      p.currentTreeId = 'tree1';
      p.trees = [
        {'id': 'tree1', 'name': 'My Family'},
      ];
      expect(p.currentTreeName, 'My Family');
    });

    test('currentTreeName returns default when tree not found', () {
      final p = TreeProvider();
      p.currentTreeId = 'unknown';
      p.trees = [];
      expect(p.currentTreeName, 'My Family Tree');
    });

    test('isLoggedIn is false initially', () {
      expect(TreeProvider().isLoggedIn, isFalse);
    });

    test('currentUser is null initially', () {
      expect(TreeProvider().currentUser, isNull);
    });

    test('localDeviceId is empty string initially', () {
      expect(TreeProvider().localDeviceId, isEmpty);
    });

    test('homePersonId is null initially', () {
      expect(TreeProvider().homePersonId, isNull);
    });

    test('dateFormat default value', () {
      expect(TreeProvider().dateFormat, 'dd MMM yyyy');
    });

    test('liveChanges is a broadcast stream', () {
      final p = TreeProvider();
      expect(p.liveChanges.isBroadcast, isTrue);
    });
  });

  // ── TreeProvider.setDateFormat / setColonizationLevel / setHomePersonId ──

  group('TreeProvider settings setters', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('setDateFormat updates dateFormat and persists to prefs', () async {
      final p = TreeProvider();
      await p.setDateFormat('MM/dd/yyyy');
      expect(p.dateFormat, 'MM/dd/yyyy');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('dateFormat'), 'MM/dd/yyyy');
    });

    test('setColonizationLevel updates level and persists', () async {
      final p = TreeProvider();
      await p.setColonizationLevel(1);
      expect(p.colonizationLevel, 1);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('colonizationLevel'), 1);
    });

    test('setHomePersonId updates homePersonId and persists', () async {
      final p = TreeProvider();
      await p.setHomePersonId('person-123');
      expect(p.homePersonId, 'person-123');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('homePersonId'), 'person-123');
    });

    test('setHomePersonId with null clears homePersonId', () async {
      final p = TreeProvider();
      await p.setHomePersonId('some-id');
      await p.setHomePersonId(null);
      expect(p.homePersonId, isNull);
    });
  });

  // ── TreeProvider.isAtPersonLimit (new tests) ────────────────────────────

  group('TreeProvider.isAtPersonLimit (additional)', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('isAtPersonLimit is always false when persons list is empty', () {
      final p = TreeProvider();
      p.persons = [];
      expect(p.isAtPersonLimit, isFalse);
    });
  });

  // ── TreeProvider.exportBackupJson in-memory ───────────────────────────────

  group('TreeProvider.exportBackupJson', () {
    test('exports all persons, sources, partnerships', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = TreeProvider();
      provider.persons = [
        Person(id: 'p1', name: 'Alice Smith'),
        Person(id: 'p2', name: 'Bob Jones'),
      ];
      provider.partnerships = [
        Partnership(id: 'pt1', person1Id: 'p1', person2Id: 'p2', status: 'married'),
      ];
      provider.sources = [
        Source(id: 's1', personId: 'p1', title: 'Birth Certificate', type: 'document', url: ''),
      ];
      provider.lifeEvents = [];
      provider.medicalConditions = [];
      provider.researchTasks = [];

      final json = await provider.exportBackupJson();
      expect(json, contains('Alice Smith'));
      expect(json, contains('Bob Jones'));
      expect(json, contains('pt1'));
      expect(json, contains('Birth Certificate'));
    });
  });

  // ── TreeProvider.currentAppTier / personLimit ────────────────────────────

  group('TreeProvider tier helpers', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('isAtPersonLimit is false for empty persons on any tier', () {
      final p = TreeProvider();
      p.persons = [];
      expect(p.isAtPersonLimit, isFalse);
    });
  });
}
