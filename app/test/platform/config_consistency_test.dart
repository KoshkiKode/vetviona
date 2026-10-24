import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the per-OS shells (Android, iOS, macOS, Windows, Linux) and the
/// CI/release contract without needing any device or SDK.
///
/// CI no longer builds every platform on every push, so configuration drift
/// (wrong bundle ids, stale binary names, missing entitlements...) would only
/// surface at release time. These checks run in the normal unit-test suite.

const String _appId = 'com.koshkikode.vetviona';
const String _linuxAppId = 'com.koshkikode.Vetviona';
const String _displayName = 'Vetviona';
const String _binaryName = 'vetviona';
const String _oldBinaryName = 'vetviona_app';

final Directory _root = _findRepoRoot();

Directory _findRepoRoot() {
  var dir = Directory.current.absolute;
  for (var i = 0; i < 6; i++) {
    if (File('${dir.path}/app/pubspec.yaml').existsSync()) return dir;
    dir = dir.parent;
  }
  throw StateError(
      'Could not locate the repository root from ${Directory.current.path}');
}

File _file(String relPath) => File('${_root.path}/$relPath');

String _read(String relPath) {
  final f = _file(relPath);
  if (!f.existsSync()) fail('Missing required file: $relPath');
  return f.readAsStringSync();
}

Map<String, String> _attrs(String tagBody) => {
      for (final m in RegExp(r'([\w:.\-]+)\s*=\s*"([^"]*)"').allMatches(tagBody))
        m.group(1)!: m.group(2)!,
    };

List<Map<String, String>> _elements(String xml, String tag) => [
      for (final m
          in RegExp('<$tag\\b([^>]*?)/?>', dotAll: true).allMatches(xml))
        _attrs(m.group(1)!),
    ];

String? _plistString(String plist, String key) =>
    RegExp('<key>${RegExp.escape(key)}</key>\\s*<string>([^<]*)</string>')
        .firstMatch(plist)
        ?.group(1);

Set<String> _plistKeys(String plist) => RegExp(r'<key>([^<]+)</key>')
    .allMatches(plist)
    .map((m) => m.group(1)!)
    .toSet();

String _pubspecVersion() {
  final m = RegExp(r'^version:\s*([0-9]+\.[0-9]+\.[0-9]+)', multiLine: true)
      .firstMatch(_read('app/pubspec.yaml'));
  if (m == null) fail('Could not read version from app/pubspec.yaml');
  return m.group(1)!;
}

void main() {
  group('pubspec', () {
    test('package name and semantic version are present', () {
      final pubspec = _read('app/pubspec.yaml');
      expect(pubspec, contains('name: vetviona_app'));
      expect(_pubspecVersion(), matches(RegExp(r'^\d+\.\d+\.\d+$')));
    });

    test('MSIX identity matches the canonical app id', () {
      expect(_read('app/pubspec.yaml'), contains('identity_name: $_appId'));
    });
  });

  group('Android', () {
    test('namespace, applicationId and MainActivity package agree', () {
      final gradle = _read('app/android/app/build.gradle.kts');
      expect(gradle, contains('namespace = "$_appId"'));
      expect(gradle, contains('applicationId = "$_appId"'));

      final newPath =
          'app/android/app/src/main/kotlin/${_appId.replaceAll('.', '/')}/MainActivity.kt';
      final activity = _read(newPath);
      expect(activity, contains('package $_appId'));
      expect(
        _file('app/android/app/src/main/kotlin/com/example').existsSync(),
        isFalse,
        reason: 'A stale com.example MainActivity means the manifest '
            '(.MainActivity, resolved via the namespace) points at a class '
            'that does not exist, which crashes on launch.',
      );
    });

    test('minSdk is pinned in Gradle (no CI patching)', () {
      expect(_read('app/android/app/build.gradle.kts'),
          matches(RegExp(r'minSdk\s*=\s*24\b')));
    });

    test('release builds cannot silently fall back to the debug key in CI', () {
      expect(_read('app/android/app/build.gradle.kts'),
          contains('REQUIRE_RELEASE_SIGNING'));
    });

    group('manifest', () {
      late String manifest;
      setUpAll(() => manifest =
          _read('app/android/app/src/main/AndroidManifest.xml'));

      test('has a human label and disables auto-backup', () {
        expect(manifest, contains('android:label="$_displayName"'));
        expect(manifest, contains('android:allowBackup="false"'));
        expect(manifest, contains('android:dataExtractionRules='));
        expect(manifest, contains('android:fullBackupContent='));
        expect(
            _file('app/android/app/src/main/res/xml/data_extraction_rules.xml')
                .existsSync(),
            isTrue);
        expect(
            _file('app/android/app/src/main/res/xml/backup_rules.xml')
                .existsSync(),
            isTrue);
      });

      test('requests no legacy storage permissions', () {
        final perms = _elements(manifest, 'uses-permission')
            .map((a) => a['android:name'])
            .toSet();
        expect(
            perms, isNot(contains('android.permission.READ_EXTERNAL_STORAGE')));
        expect(perms,
            isNot(contains('android.permission.WRITE_EXTERNAL_STORAGE')));
      });

      test('legacy Bluetooth/location permissions are capped at API 30', () {
        final perms = {
          for (final a in _elements(manifest, 'uses-permission'))
            a['android:name']!: a,
        };
        for (final name in [
          'android.permission.BLUETOOTH',
          'android.permission.BLUETOOTH_ADMIN',
          'android.permission.ACCESS_FINE_LOCATION',
          'android.permission.ACCESS_COARSE_LOCATION',
        ]) {
          expect(perms[name]?['android:maxSdkVersion'], '30',
              reason: '$name must be limited with maxSdkVersion=30');
        }
      });

      test('BLE scan is declared as never deriving location', () {
        final scan = _elements(manifest, 'uses-permission').firstWhere(
            (a) => a['android:name'] == 'android.permission.BLUETOOTH_SCAN',
            orElse: () => <String, String>{});
        expect(scan['android:usesPermissionFlags'], 'neverForLocation');
      });

      test('optional hardware does not hide the app from other devices', () {
        final features = {
          for (final a in _elements(manifest, 'uses-feature'))
            a['android:name']!: a['android:required'],
        };
        for (final name in [
          'android.hardware.nfc',
          'android.hardware.bluetooth_le',
          'android.hardware.camera',
          'android.hardware.camera.autofocus',
        ]) {
          expect(features[name], 'false',
              reason: '$name must be declared with required="false"');
        }
      });
    });
  });

  group('iOS', () {
    late String pbxproj;
    setUpAll(
        () => pbxproj = _read('app/ios/Runner.xcodeproj/project.pbxproj'));

    test('bundle identifiers use the canonical id', () {
      final ids = RegExp(r'PRODUCT_BUNDLE_IDENTIFIER = ([^;]+);')
          .allMatches(pbxproj)
          .map((m) => m.group(1)!)
          .toList();
      expect(ids, isNotEmpty);
      expect(ids.where((id) => id.contains('com.example')), isEmpty);
      expect(ids.where((id) => id == _appId).length, 3);
      expect(ids.where((id) => id == '$_appId.RunnerTests').length, 3);
    });

    test('deployment target is 15.5 everywhere and matches the Podfile', () {
      final targets = RegExp(r'IPHONEOS_DEPLOYMENT_TARGET = ([0-9.]+);')
          .allMatches(pbxproj)
          .map((m) => m.group(1)!)
          .toSet();
      expect(targets, {'15.5'});
      expect(_read('app/ios/Podfile'),
          matches(RegExp(r"^platform :ios, '15\.5'", multiLine: true)));
    });

    test('NFC entitlement exists and is wired into every Runner config', () {
      final entitlements = _read('app/ios/Runner/Runner.entitlements');
      expect(entitlements,
          contains('com.apple.developer.nfc.readersession.formats'));
      expect(entitlements, contains('<string>NDEF</string>'));
      expect(entitlements, contains('<string>TAG</string>'));
      expect(entitlements, contains('keychain-access-groups'));

      final wired = RegExp(r'CODE_SIGN_ENTITLEMENTS = ([^;]+);')
          .allMatches(pbxproj)
          .map((m) => m.group(1)!)
          .toList();
      expect(wired.length, 3);
      expect(wired.toSet(), {'Runner/Runner.entitlements'});
    });

    test('Info.plist has product names and every privacy string', () {
      final plist = _read('app/ios/Runner/Info.plist');
      expect(_plistString(plist, 'CFBundleDisplayName'), _displayName);
      expect(_plistString(plist, 'CFBundleName'), _displayName);
      for (final key in [
        'NSCameraUsageDescription',
        'NSBluetoothAlwaysUsageDescription',
        'NSLocalNetworkUsageDescription',
        'NFCReaderUsageDescription',
        'NSPhotoLibraryUsageDescription',
      ]) {
        expect(_plistString(plist, key), isNotNull,
            reason: 'Info.plist is missing $key');
      }
      expect(plist, contains('_vetviona._tcp'));
    });
  });

  group('macOS', () {
    test('AppInfo.xcconfig uses the canonical id, name and copyright', () {
      final cfg = _read('app/macos/Runner/Configs/AppInfo.xcconfig');
      expect(cfg, contains('PRODUCT_BUNDLE_IDENTIFIER = $_appId'));
      expect(cfg, contains('PRODUCT_NAME = $_displayName'));
      expect(cfg, isNot(contains('com.example')));
    });

    test('Xcode project has no placeholder ids', () {
      final pbx = _read('app/macos/Runner.xcodeproj/project.pbxproj');
      expect(pbx, isNot(contains('com.example')));
      expect(pbx, contains('$_appId.RunnerTests'));
    });

    for (final name in ['Release', 'DebugProfile']) {
      test('$name.entitlements is least-privilege and keychain-capable', () {
        final keys = _plistKeys(_read('app/macos/Runner/$name.entitlements'));
        expect(
            keys,
            containsAll([
              'com.apple.security.app-sandbox',
              'com.apple.security.network.client',
              'com.apple.security.network.server',
              'com.apple.security.device.bluetooth',
              'com.apple.security.files.user-selected.read-write',
            ]));
        // Keychain access requires signing; it is mandatory for release but
        // omitted from debug so unsigned local debug builds still work.
        if (name == 'Release') {
          expect(keys, contains('keychain-access-groups'));
        }
        // The QR scanner is mobile-only and nothing records audio.
        expect(keys, isNot(contains('com.apple.security.device.camera')));
        expect(keys, isNot(contains('com.apple.security.device.audio-input')));
      });
    }

    test('Info.plist declares Bonjour + local-network usage', () {
      final plist = _read('app/macos/Runner/Info.plist');
      expect(plist, contains('NSBonjourServices'));
      expect(plist, contains('_vetviona._tcp'));
      expect(_plistString(plist, 'NSLocalNetworkUsageDescription'), isNotNull);
      expect(
          _plistString(plist, 'NSBluetoothAlwaysUsageDescription'), isNotNull);
    });

    test('entitlements have a single source of truth', () {
      expect(_file('packaging/macos/entitlements.plist').existsSync(), isFalse,
          reason: 'Runner/*.entitlements are authoritative; a packaging copy '
              'would be overwritten into the project by CI and drift.');
    });
  });

  group('Windows', () {
    test('binary name and project strings say Vetviona', () {
      expect(_read('app/windows/CMakeLists.txt'),
          contains('set(BINARY_NAME "$_binaryName")'));

      final rc = _read('app/windows/runner/Runner.rc');
      expect(rc, isNot(contains(_oldBinaryName)));
      expect(rc, contains('VALUE "ProductName", "$_displayName"'));
      expect(rc, contains('VALUE "OriginalFilename", "$_binaryName.exe"'));
      expect(rc, contains('VALUE "CompanyName", "KoshkiKode LLC"'));

      expect(_read('app/windows/runner/main.cpp'),
          contains('window.Create(L"$_displayName"'));
    });

    test('MSI authoring references the final exe and opens the firewall', () {
      final wxs = _read('packaging/windows/vetviona.wxs');
      expect(wxs, contains('$_binaryName.exe'));
      expect(wxs, isNot(contains(_oldBinaryName)));
      expect(wxs.toLowerCase(), contains('firewall'));
    });
  });

  group('Linux', () {
    test('GTK application id matches the Flatpak app-id', () {
      expect(_read('app/linux/CMakeLists.txt'),
          contains('set(APPLICATION_ID "$_linuxAppId")'));
      expect(_read('app/linux/CMakeLists.txt'),
          contains('set(BINARY_NAME "$_binaryName")'));
      expect(_read('packaging/linux/flatpak/$_linuxAppId.yml'),
          contains('app-id: $_linuxAppId'));
    });

    group('Flatpak', () {
      late String yml;
      setUpAll(() => yml = _read('packaging/linux/flatpak/$_linuxAppId.yml'));

      test('uses a GTK-capable runtime and the final command', () {
        expect(yml, contains('runtime: org.gnome.Platform'));
        expect(yml, contains('sdk: org.gnome.Sdk'));
        expect(yml, contains('command: $_binaryName'));
      });

      test('grants only what RootLoop and secure storage need', () {
        expect(yml, contains('--talk-name=org.freedesktop.secrets'));
        expect(yml, contains('--system-talk-name=org.bluez'));
        expect(yml, contains('--system-talk-name=org.freedesktop.Avahi'));
        expect(yml, contains('--share=network'));
        expect(yml, isNot(contains('--filesystem=home')));
      });

      test('ships desktop entry, metainfo and icon', () {
        for (final f in [
          'packaging/linux/flatpak/$_linuxAppId.desktop',
          'packaging/linux/flatpak/$_linuxAppId.metainfo.xml',
        ]) {
          expect(_file(f).existsSync(), isTrue, reason: 'missing $f');
        }
        expect(yml, contains('$_linuxAppId.desktop'));
        expect(yml, contains('$_linuxAppId.metainfo.xml'));
      });

      test('desktop entry launches the final binary and handles .ged', () {
        final desktop = _read('packaging/linux/flatpak/$_linuxAppId.desktop');
        expect(desktop, contains('Exec=$_binaryName'));
        expect(desktop, contains('Icon=$_linuxAppId'));
        expect(desktop, contains('application/x-gedcom'));
      });
    });

    test('Snap grants keyring + mDNS access and tracks the pubspec version', () {
      final snap = _read('packaging/linux/snap/snapcraft.yaml');
      expect(snap, contains('command: $_binaryName'));
      expect(snap, contains('password-manager-service'));
      expect(snap, contains('avahi-observe'));
      expect(snap, contains('avahi-control'));
      expect(snap, contains("version: '${_pubspecVersion()}'"));
    });

    test('Debian package declares runtime deps and tracks the version', () {
      final control = _read('packaging/linux/deb/control');
      expect(control, contains('Version: ${_pubspecVersion()}'));
      final depends = RegExp(r'^Depends:\s*(.+)$', multiLine: true)
          .firstMatch(control)
          ?.group(1);
      expect(depends, isNotNull, reason: 'control has no Depends: line');
      expect(depends, contains('libgtk-3-0'));
      expect(depends, contains('libsecret-1-0'));

      final script = _read('packaging/linux/deb/build_deb.sh');
      expect(script, contains('--root-owner-group'));
      expect(script, contains('exec /usr/lib/vetviona/$_binaryName'));
      expect(script, isNot(contains(_oldBinaryName)));
    });
  });

  group('CI / release contract', () {
    test('everyday CI exists and old duplicate workflows are gone', () {
      expect(_file('.github/workflows/ci.yml').existsSync(), isTrue);
      expect(_file('.github/workflows/test.yml').existsSync(), isFalse);
      expect(_file('.github/workflows/build-all.yml').existsSync(), isFalse);
    });

    test('platform builds run only for release tags or manual dispatch', () {
      final release = _read('.github/workflows/release.yml');
      final onBlock = RegExp(r'^on:\n((?:[ \t]+.*\n|\n)+?)(?=^\S)',
              multiLine: true)
          .firstMatch(release)
          ?.group(1);
      expect(onBlock, isNotNull, reason: 'release.yml has no on: block');
      expect(onBlock, contains("tags: ['v*']"));
      expect(onBlock, contains('workflow_dispatch'));
      expect(onBlock, isNot(contains('pull_request')));
      expect(onBlock, isNot(contains('branches')));
    });

    test('release workflow uses the final binary names', () {
      final release = _read('.github/workflows/release.yml');
      expect(release, isNot(contains('$_oldBinaryName.exe')));
      expect(release, isNot(contains('$_oldBinaryName.app')));
      expect(release, isNot(contains('packaging/macos/entitlements.plist')));
    });
  });
}
