import re

# Fix home_screen.dart
path = '/Users/dylancmoore/vetviona/app/lib/screens/home_screen.dart'
with open(path, 'r') as f:
    content = f.read()

content = content.replace("PersonDetailScreen()", "PersonDetailScreen(person: provider.persons.first)")
with open(path, 'w') as f:
    f.write(content)


# Fix on_this_day_screen.dart
path = '/Users/dylancmoore/vetviona/app/lib/screens/on_this_day_screen.dart'
with open(path, 'r') as f:
    content = f.read()

content = content.replace("pt.marriageDate", "pt.startDate")
content = content.replace("pt.marriagePlace", "pt.startPlace")
content = content.replace("int.parse(pt.startDate.split(' ').last)", "int.parse(pt.startDate!.split(' ').last)")
with open(path, 'w') as f:
    f.write(content)


# Fix pedigree_screen.dart
path = '/Users/dylancmoore/vetviona/app/lib/screens/pedigree_screen.dart'
with open(path, 'r') as f:
    content = f.read()

content = content.replace("PersonDetailScreen(person: person)", "PersonDetailScreen(person: person!)")
with open(path, 'w') as f:
    f.write(content)


# Fix tree_screen.dart
path = '/Users/dylancmoore/vetviona/app/lib/screens/tree_screen.dart'
with open(path, 'r') as f:
    content = f.read()

content = content.replace("PersonDetailScreen()", "PersonDetailScreen(person: person)")
with open(path, 'w') as f:
    f.write(content)


# Fix record_search_screen.dart (unused args, nullability)
path = '/Users/dylancmoore/vetviona/app/lib/screens/record_search_screen.dart'
with open(path, 'r') as f:
    content = f.read()

content = content.replace("final FamilySearchRecord? _fsRecord;", "final dynamic _fsRecord;")
content = content.replace("final ChroniclingAmericaResult? _caResult;", "final dynamic _caResult;")
content = content.replace("final NaraCatalogResult? _naraResult;", "final dynamic _naraResult;")
content = content.replace("final OpenArchivesRecord? _oaRecord;", "final dynamic _oaRecord;")
content = content.replace("FamilySearchRecord? fsRecord,", "dynamic fsRecord,")
content = content.replace("ChroniclingAmericaResult? caResult,", "dynamic caResult,")
content = content.replace("NaraCatalogResult? naraResult,", "dynamic naraResult,")
content = content.replace("OpenArchivesRecord? oaRecord,", "dynamic oaRecord,")
with open(path, 'w') as f:
    f.write(content)

# Fix record_hints_service.dart
path = '/Users/dylancmoore/vetviona/app/lib/services/record_hints_service.dart'
with open(path, 'r') as f:
    content = f.read()

content = content.replace(
    "final results = await FamilySearchApiService.instance.searchPerson(",
    "final results = await FamilySearchApiService.instance.searchRecords("
)
content = content.replace(
    "firstName: firstName,",
    "givenName: firstName,"
)
content = content.replace(
    "lastName: lastName,",
    "surname: lastName,"
)
content = content.replace(
    "digitalObjectUrl: result.pageUrl,",
    "recordUrl: result.pageUrl,"
)
with open(path, 'w') as f:
    f.write(content)

# Fix wall_chart_screen.dart
path = '/Users/dylancmoore/vetviona/app/lib/screens/wall_chart_screen.dart'
with open(path, 'r') as f:
    content = f.read()

content = content.replace("matrix.translate(center.dx, center.dy);", "matrix.translateByVector3(Vector3(center.dx, center.dy, 0.0));")
content = content.replace("matrix.scale(factor, factor, 1.0);", "matrix.scaleByVector3(Vector3(factor, factor, 1.0));")
content = content.replace("matrix.translate(-center.dx, -center.dy);", "matrix.translateByVector3(Vector3(-center.dx, -center.dy, 0.0));")
content = "import 'package:vector_math/vector_math_64.dart';\n" + content
with open(path, 'w') as f:
    f.write(content)
