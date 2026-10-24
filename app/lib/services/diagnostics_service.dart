import 'dart:collection';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// One line in the diagnostics log.
class DiagnosticEntry {
  DiagnosticEntry(this.time, this.category, this.message);

  final DateTime time;
  final String category;
  final String message;

  @override
  String toString() => '${time.toUtc().toIso8601String()} [$category] $message';
}

/// A small, privacy-first error log.
///
/// * Never leaves the device on its own: there is no network code here. The
///   user can copy the report from Settings and decide whom to send it to.
/// * Redacts the most common personal data (user names in file paths, e-mail
///   addresses, IP addresses, UUIDs, long tokens) before anything is stored.
/// * Keeps the last [maxEntries] entries in memory and mirrors them to a
///   size-capped file so a crash can still be investigated after a restart.
class DiagnosticsService {
  DiagnosticsService({this.maxEntries = 200, this.maxFileBytes = 256 * 1024});

  /// App-wide instance used by `main.dart`.
  static final DiagnosticsService instance = DiagnosticsService();

  final int maxEntries;
  final int maxFileBytes;
  final ListQueue<DiagnosticEntry> _entries = ListQueue();
  File? _file;

  List<DiagnosticEntry> get entries => List.unmodifiable(_entries);

  /// Starts mirroring entries to `<dir>/diagnostics.log` (rotated to
  /// `diagnostics.log.1` when it grows past [maxFileBytes]).
  Future<void> attachFile(Directory dir) async {
    try {
      await dir.create(recursive: true);
      _file = File('${dir.path}${Platform.pathSeparator}diagnostics.log');
    } catch (_) {
      _file = null; // Diagnostics must never take the app down.
    }
  }

  /// Records a plain informational message.
  void info(String category, String message) =>
      _add(category, redact(message));

  /// Records an error with a shortened, redacted stack trace.
  void error(String category, Object error, [StackTrace? stack]) {
    final buffer = StringBuffer(redact(error.toString()));
    if (stack != null) {
      final lines = stack.toString().split('\n').where((l) => l.trim().isNotEmpty);
      for (final line in lines.take(12)) {
        buffer.write('\n    ${redact(line.trim())}');
      }
    }
    _add(category, buffer.toString());
  }

  void _add(String category, String message) {
    final entry = DiagnosticEntry(DateTime.now(), category, message);
    _entries.addLast(entry);
    while (_entries.length > maxEntries) {
      _entries.removeFirst();
    }
    _append(entry);
  }

  void _append(DiagnosticEntry entry) {
    final file = _file;
    if (file == null) return;
    try {
      if (file.existsSync() && file.lengthSync() > maxFileBytes) {
        final rotated = File('${file.path}.1');
        if (rotated.existsSync()) rotated.deleteSync();
        file.renameSync(rotated.path);
      }
      file.writeAsStringSync('$entry\n', mode: FileMode.append, flush: true);
    } catch (_) {
      // Ignore I/O failures: logging must never throw.
    }
  }

  void clear() {
    _entries.clear();
    final file = _file;
    try {
      if (file != null && file.existsSync()) file.deleteSync();
    } catch (_) {}
  }

  /// A report the user can copy and share manually.
  String exportReport({String? appVersion}) {
    final header = StringBuffer()
      ..writeln('Vetviona diagnostics')
      ..writeln('App version: ${appVersion ?? 'unknown'}')
      ..writeln('Platform: ${defaultTargetPlatform.name}')
      ..writeln('Entries: ${_entries.length} (personal data is redacted; '
          'review before sharing)')
      ..writeln();
    return header.toString() + _entries.map((e) => e.toString()).join('\n');
  }

  /// Removes personal data from [text].
  @visibleForTesting
  static String redact(String text) {
    var out = text;
    out = out.replaceAllMapped(
        RegExp(r'([A-Za-z]:\\Users\\)[^\\\s]+'), (m) => '${m[1]}<user>');
    out = out.replaceAllMapped(
        RegExp(r'(/(?:Users|home)/)[^/\s]+'), (m) => '${m[1]}<user>');
    out = out.replaceAll(
        RegExp(r'[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}'), '<email>');
    out = out.replaceAll(
        RegExp(
            r'\b[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\b'),
        '<id>');
    out = out.replaceAll(RegExp(r'\b\d{1,3}(?:\.\d{1,3}){3}\b'), '<ip>');
    out = out.replaceAll(RegExp(r'\b[A-Za-z0-9+/_\-]{32,}={0,2}'), '<token>');
    return out;
  }
}
