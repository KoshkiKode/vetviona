import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Method channel `path_provider` uses for documents, support and temp
/// directories.
const String pathProviderChannel = 'plugins.flutter.io/path_provider';

/// Sends every documents-directory lookup to [directory].
///
/// Tests that open the database must pass a fresh temporary directory. Returning
/// `inMemoryDatabasePath` instead creates a persistent *file* named
/// `:memory:/vetviona.db`, which keeps rows and triggers between runs.
void redirectDocumentsDirectory(String Function() directory) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel(pathProviderChannel),
    (call) async => directory(),
  );
}
