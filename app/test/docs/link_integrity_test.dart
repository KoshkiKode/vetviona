import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final RegExp _markdownLinkPattern = RegExp(r'\[[^\]]+\]\(([^)]+)\)');
final RegExp _headingPattern = RegExp(r'^\s{0,3}#{1,6}\s+(.+?)\s*$');
final RegExp _explicitIdPattern = RegExp(r'\s*\{#([A-Za-z0-9_-]+)\}\s*$');

void main() {
  final Directory repoRoot = Directory.current.parent;
  final Directory wikiDir = Directory('${repoRoot.path}/wiki');
  final File homeFile = File('${wikiDir.path}/Home.md');
  final File websiteFile = File('${repoRoot.path}/website/index.html');

  group('wiki self-references', () {
    test('all linked wiki pages and anchors resolve', () {
      final Map<String, File> wikiFilesByStem = {
        for (final file in wikiDir.listSync().whereType<File>())
          if (file.path.endsWith('.md'))
            _fileStem(file): file,
      };

      final Map<String, Set<String>> anchorsByPage = {
        for (final entry in wikiFilesByStem.entries)
          entry.key: _extractAnchors(entry.value.readAsStringSync()),
      };

      for (final entry in wikiFilesByStem.entries) {
        final String sourcePage = entry.key;
        final String sourceText = entry.value.readAsStringSync();

        for (final Match match in _markdownLinkPattern.allMatches(sourceText)) {
          final String rawTarget = match.group(1)!.trim();
          if (rawTarget.isEmpty ||
              rawTarget.startsWith('http://') ||
              rawTarget.startsWith('https://') ||
              rawTarget.startsWith('mailto:')) {
            continue;
          }

          final (String pagePart, String? anchorPart) = _splitTarget(rawTarget);
          final String resolvedPage =
              pagePart.isEmpty ? sourcePage : pagePart.replaceAll('.md', '');

          expect(
            wikiFilesByStem.containsKey(resolvedPage),
            isTrue,
            reason: 'Missing wiki page "$rawTarget" referenced from $sourcePage',
          );

          if (anchorPart != null && anchorPart.isNotEmpty) {
            final Set<String> anchors = anchorsByPage[resolvedPage] ?? <String>{};
            expect(
              anchors.contains(anchorPart) || anchors.contains(_slugify(anchorPart)),
              isTrue,
              reason:
                  'Missing wiki anchor "#$anchorPart" in $resolvedPage referenced from $sourcePage',
            );
          }
        }
      }
    });

    test('Home links to every wiki document', () {
      final Set<String> allPages = wikiDir
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.md'))
          .map(_fileStem)
          .toSet();
      allPages.remove('Home');

      final String homeText = homeFile.readAsStringSync();
      final Set<String> linkedPages = <String>{};
      for (final Match match in _markdownLinkPattern.allMatches(homeText)) {
        final String rawTarget = match.group(1)!.trim();
        if (rawTarget.startsWith('http://') ||
            rawTarget.startsWith('https://') ||
            rawTarget.startsWith('mailto:')) {
          continue;
        }
        final (String pagePart, _) = _splitTarget(rawTarget);
        if (pagePart.isNotEmpty) {
          linkedPages.add(pagePart.replaceAll('.md', ''));
        }
      }

      expect(
        linkedPages.containsAll(allPages),
        isTrue,
        reason: 'Home.md does not reference all wiki pages',
      );
    });
  });

  group('website checks', () {
    test('internal section anchors resolve to real ids', () {
      final String html = websiteFile.readAsStringSync();
      final Set<String> ids =
          RegExp(r'id="([^"]+)"').allMatches(html).map((m) => m.group(1)!).toSet();
      final Iterable<String> internalAnchors = RegExp(r'href="#([^"]+)"')
          .allMatches(html)
          .map((m) => m.group(1)!);

      expect(internalAnchors, isNotEmpty);
      for (final anchor in internalAnchors) {
        expect(
          ids.contains(anchor),
          isTrue,
          reason: 'Missing section id "$anchor" referenced in website/index.html',
        );
      }
    });

    test('external website links use secure absolute URLs', () {
      final String html = websiteFile.readAsStringSync();
      final Iterable<String> externalLinks = RegExp(r'href="(https?://[^"]+)"')
          .allMatches(html)
          .map((m) => m.group(1)!);

      expect(externalLinks, isNotEmpty);
      for (final link in externalLinks) {
        final Uri uri = Uri.parse(link);
        expect(uri.hasScheme && uri.hasAuthority, isTrue);
        expect(uri.scheme, 'https', reason: 'Insecure external link: $link');
      }
    });
  });
}

Set<String> _extractAnchors(String markdown) {
  final Set<String> anchors = <String>{};
  for (final line in markdown.split('\n')) {
    final Match? heading = _headingPattern.firstMatch(line);
    if (heading == null) {
      continue;
    }

    String headingText = heading.group(1)!.trim();
    final Match? explicitId = _explicitIdPattern.firstMatch(headingText);
    if (explicitId != null) {
      anchors.add(explicitId.group(1)!);
      headingText = headingText.replaceFirst(_explicitIdPattern, '').trim();
    }
    anchors.add(_slugify(_stripInlineMarkdown(headingText)));
  }
  return anchors;
}

String _stripInlineMarkdown(String text) {
  return text
      .replaceAll(RegExp(r'`([^`]+)`'), r'$1')
      .replaceAll(RegExp(r'\[([^\]]+)\]\([^)]+\)'), r'$1');
}

String _slugify(String value) {
  final String lower = value.toLowerCase();
  final String normalized = lower
      .replaceAll(RegExp(r'[^a-z0-9 _-]'), '')
      .replaceAll(RegExp(r'\s+'), '-')
      .replaceAll(RegExp(r'-+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return normalized;
}

(String, String?) _splitTarget(String rawTarget) {
  if (!rawTarget.contains('#')) {
    return (rawTarget, null);
  }
  final int hashIndex = rawTarget.indexOf('#');
  final String page = rawTarget.substring(0, hashIndex);
  final String anchor = rawTarget.substring(hashIndex + 1);
  return (page, anchor);
}

String _fileStem(File file) {
  final String name = file.uri.pathSegments.last;
  if (!name.endsWith('.md')) {
    return name;
  }
  return name.substring(0, name.length - '.md'.length);
}
