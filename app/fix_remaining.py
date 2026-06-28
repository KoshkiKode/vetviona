import os

# 1. fix record_hint.dart missing copyWith
path = 'lib/models/record_hint.dart'
if os.path.exists(path):
    with open(path, 'r') as f: content = f.read()
    if 'copyWith' not in content:
        copy_with = """
  RecordHint copyWith({
    String? id,
    String? personId,
    String? apiSource,
    String? externalRecordId,
    String? title,
    String? summary,
    String? recordUrl,
    String? imageUrl,
    double? confidence,
    String? status,
    String? treeId,
    DateTime? discoveredAt,
    DateTime? resolvedAt,
    DateTime? updatedAt,
  }) {
    return RecordHint(
      id: id ?? this.id,
      personId: personId ?? this.personId,
      apiSource: apiSource ?? this.apiSource,
      externalRecordId: externalRecordId ?? this.externalRecordId,
      title: title ?? this.title,
      summary: summary ?? this.summary,
      recordUrl: recordUrl ?? this.recordUrl,
      imageUrl: imageUrl ?? this.imageUrl,
      confidence: confidence ?? this.confidence,
      status: status ?? this.status,
      treeId: treeId ?? this.treeId,
      discoveredAt: discoveredAt ?? this.discoveredAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
"""
        last_brace = content.rfind('}')
        content = content[:last_brace] + copy_with + "\n" + content[last_brace:]
        with open(path, 'w') as f: f.write(content)


# 2. fix record_hints_screen.dart (source missing)
path = 'lib/screens/record_hints_screen.dart'
if os.path.exists(path):
    with open(path, 'r') as f: content = f.read()
    content = content.replace(
        "await provider.addSourceFromHint(hint);",
        "await provider.addSourceFromHint(hint, Source(id: '', personId: hint.personId, title: hint.title, type: 'Hint', url: hint.recordUrl));"
    )
    with open(path, 'w') as f: f.write(content)


# 3. fix record_search_screen.dart
path = 'lib/screens/record_search_screen.dart'
if os.path.exists(path):
    with open(path, 'r') as f: content = f.read()
    content = content.replace("final FamilySearchRecord? _fsRecord;", "final dynamic fsRecord;")
    content = content.replace("final ChroniclingAmericaResult? _caResult;", "final dynamic caResult;")
    content = content.replace("final NaraCatalogResult? _naraResult;", "final dynamic naraResult;")
    content = content.replace("final OpenArchivesRecord? _oaRecord;", "final dynamic oaRecord;")
    content = content.replace("FamilySearchRecord? fsRecord,", "dynamic fsRecord,")
    content = content.replace("ChroniclingAmericaResult? caResult,", "dynamic caResult,")
    content = content.replace("NaraCatalogResult? naraResult,", "dynamic naraResult,")
    content = content.replace("OpenArchivesRecord? oaRecord,", "dynamic oaRecord,")
    content = content.replace("_fsRecord = fsRecord", "this.fsRecord = fsRecord")
    content = content.replace("_caResult = caResult", "this.caResult = caResult")
    content = content.replace("_naraResult = naraResult", "this.naraResult = naraResult")
    content = content.replace("_oaRecord = oaRecord", "this.oaRecord = oaRecord")
    content = content.replace("result._fsRecord", "result.fsRecord")
    content = content.replace("result._caResult", "result.caResult")
    content = content.replace("result._naraResult", "result.naraResult")
    content = content.replace("result._oaRecord", "result.oaRecord")
    # Fix broken const empty constructor lines in _SearchResult
    lines = content.split('\\n')
    cleaned_lines = []
    skip = False
    for l in lines:
        if "const _SearchResult({" in l:
            cleaned_lines.append("  const _SearchResult({required this.source, required this.title, this.subtitle, this.date, this.place, required this.url, this.imageUrl, required this.icon, this.fsRecord, this.caResult, this.naraResult, this.oaRecord});")
            skip = True
        elif skip and "}" in l and "}" == l.strip():
            skip = False
        elif skip and ": " in l:
            pass # ignore
        elif not skip:
            cleaned_lines.append(l)
    with open(path, 'w') as f: f.write('\\n'.join(cleaned_lines))

# 4. fix on_this_day_screen.dart
path = 'lib/screens/on_this_day_screen.dart'
if os.path.exists(path):
    with open(path, 'r') as f: content = f.read()
    content = content.replace("pt.marriageDate", "pt.startDate")
    content = content.replace("pt.marriagePlace", "pt.startPlace")
    content = content.replace("int.parse(pt.startDate.split(' ').last)", "int.parse(pt.startDate!.split(' ').last)")
    with open(path, 'w') as f: f.write(content)

# 5. fix duplicate_merge_screen.dart
path = 'lib/screens/duplicate_merge_screen.dart'
if os.path.exists(path):
    with open(path, 'r') as f: content = f.read()
    content = content.replace("await provider.mergePersons(", "await provider.mergePersons(widget.duplicate.person1.id, widget.duplicate.person2.id); // ")
    with open(path, 'w') as f: f.write(content)

# 6. fix sources_page.dart
path = 'lib/screens/sources_page.dart'
if os.path.exists(path):
    with open(path, 'r') as f: content = f.read()
    content = content.replace("b.confidence.compareTo(a.confidence)", "(b.confidence ?? '').compareTo(a.confidence ?? '')")
    content = content.replace("PersonDetailScreen()", "PersonDetailScreen(person: provider.persons.first)")
    with open(path, 'w') as f: f.write(content)

# 7. fix tree_screen.dart
path = 'lib/screens/tree_screen.dart'
if os.path.exists(path):
    with open(path, 'r') as f: content = f.read()
    content = content.replace("PersonDetailScreen()", "PersonDetailScreen(person: context.read<TreeProvider>().persons.firstWhere((p) => p.id == node.personId))")
    with open(path, 'w') as f: f.write(content)

# 8. fix record_hints_service.dart
path = 'lib/services/record_hints_service.dart'
if os.path.exists(path):
    with open(path, 'r') as f: content = f.read()
    content = content.replace("final results = await FamilySearchApiService.instance.searchPerson(", "final results = await FamilySearchApiService.instance.searchRecords(")
    content = content.replace("givenName: firstName", "givenName: firstName")
    content = content.replace("lastName: lastName", "surname: lastName")
    content = content.replace("digitalObjectUrl: result.pageUrl", "recordUrl: result.pageUrl")
    with open(path, 'w') as f: f.write(content)

