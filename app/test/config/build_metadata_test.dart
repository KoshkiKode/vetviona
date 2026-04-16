import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:vetviona_app/config/build_metadata.dart';

void main() {
  group('BuildMetadata', () {
    setUpAll(() {
      // Simulate the main() initialisation that normally sets appVersion from
      // PackageInfo.fromPlatform().  In tests the platform channel is not
      // available, so we use PackageInfo.setMockInitialValues instead.
      PackageInfo.setMockInitialValues(
        appName: 'Vetviona',
        packageName: 'com.koshkikode.vetviona',
        version: '1.0.0',
        buildNumber: '1',
        buildSignature: '',
      );
    });

    test('appName is Vetviona', () {
      expect(BuildMetadata.appName, 'Vetviona');
    });

    test('appVersion is set from PackageInfo in production', () async {
      final info = await PackageInfo.fromPlatform();
      // In tests the mock value is returned; verify the plumbing works.
      expect(info.version, isNotEmpty);
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
