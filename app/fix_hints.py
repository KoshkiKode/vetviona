import re

path = '/Users/dylancmoore/vetviona/app/lib/screens/record_hints_screen.dart'
with open(path, 'r') as f: content = f.read()

content = content.replace(
    "await provider.addSourceFromHint(hint, Source(id: '', title: hint.title, personId: hint.personId));",
    "await provider.addSourceFromHint(hint, Source(id: '', title: hint.title, personId: hint.personId, type: 'Record Hint', url: hint.recordUrl));"
)

with open(path, 'w') as f: f.write(content)
