import 'package:flutter_test/flutter_test.dart';
import 'package:vetviona_app/models/person.dart';
import 'package:vetviona_app/screens/relationship_finder_screen.dart';

Person makePerson(
  String id, {
  List<String> parents = const [],
  List<String> children = const [],
}) =>
    Person(id: id, name: id, parentIds: parents, childIds: children);

void main() {
  // grandma -> mom -> me; mom -> sib; grandma -> aunt -> cousin;
  // me -> child <- coparent; spouse <- spouseMom; spouse -> stepChild.
  // spouse has no parent or child link to me.
  final grandma = makePerson('grandma', children: ['mom', 'aunt']);
  final mom = makePerson('mom', parents: ['grandma'], children: ['me', 'sib']);
  final me = makePerson('me', parents: ['mom'], children: ['child']);
  final sib = makePerson('sib', parents: ['mom']);
  final aunt = makePerson('aunt', parents: ['grandma'], children: ['cousin']);
  final cousin = makePerson('cousin', parents: ['aunt']);
  final child = makePerson('child', parents: ['me', 'coparent']);
  final coparent = makePerson('coparent');
  final spouse = makePerson(
    'spouse',
    parents: ['spouseMom'],
    children: ['stepChild'],
  );
  final spouseMom = makePerson('spouseMom', children: ['spouse']);
  final stepChild = makePerson('stepChild', parents: ['spouse']);
  final everyone = [
    grandma,
    mom,
    me,
    sib,
    aunt,
    cousin,
    child,
    coparent,
    spouse,
    spouseMom,
    stepChild,
  ];

  // describeRelationship labels only the path; from and to are unused.
  String label(List<String> path) =>
      describeRelationship(me, mom, everyone, path);

  group('describeRelationship', () {
    test('names blood-line ancestor, sibling and cousin paths', () {
      expect(label(['me', 'mom', 'grandma']), 'Grandparent');
      expect(label(['me', 'mom', 'sib']), 'Sibling');
      expect(label(['me', 'mom', 'grandma', 'aunt']), 'Aunt/Uncle');
      expect(label(['me', 'mom', 'grandma', 'aunt', 'cousin']), '1st Cousin');
    });

    test('names a direct partner link as Partner/Spouse', () {
      expect(label(['me', 'spouse']), 'Partner/Spouse');
    });

    test('labels a partner parent as Relative, not Parent', () {
      expect(label(['me', 'spouse', 'spouseMom']), 'Relative');
    });

    test('labels a stepchild as Relative, not Child', () {
      expect(label(['me', 'spouse', 'stepChild']), 'Relative');
    });

    test('labels a child other parent as Relative, not Sibling', () {
      expect(label(['me', 'child', 'coparent']), 'Relative');
    });

    test('labels an unknown person id as Relative', () {
      expect(label(['me', 'ghost']), 'Relative');
    });
  });
}
