import 'package:flutter_test/flutter_test.dart';
import 'package:vetviona_app/config/build_metadata.dart';

void main() {
  group('BuildMetadata', () {
    test('appName is Vetviona', () {
      expect(BuildMetadata.appName, 'Vetviona');
    });

    test('appVersion is non-empty', () {
      expect(BuildMetadata.appVersion, isNotEmpty);
    });

    test('syncTechName is RootLoop', () {
      expect(BuildMetadata.syncTechName, 'RootLoop');
    });

    test('syncTechVersion is non-empty', () {
      expect(BuildMetadata.syncTechVersion, isNotEmpty);
    });

    test('companyName is KoshkiKode', () {
      expect(BuildMetadata.companyName, 'KoshkiKode');
    });

    test('websiteDomain is non-empty and contains a dot', () {
      expect(BuildMetadata.websiteDomain, isNotEmpty);
      expect(BuildMetadata.websiteDomain, contains('.'));
    });

    test('rootLoopAutoTier is non-empty', () {
      expect(BuildMetadata.rootLoopAutoTier, isNotEmpty);
    });

    test('rootLoopManualTier is non-empty', () {
      expect(BuildMetadata.rootLoopManualTier, isNotEmpty);
    });

    test('rootLoopAutoTier and rootLoopManualTier are different', () {
      expect(BuildMetadata.rootLoopAutoTier,
          isNot(equals(BuildMetadata.rootLoopManualTier)));
    });
  });
}
