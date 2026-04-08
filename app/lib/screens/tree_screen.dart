                    ElevatedButton(
                      onPressed: () => _viewSources(context, person),
                      child: const Text('View Sources'),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: () => _linkRelationships(context, person),
                      child: const Text('Link Relationships'),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: () => _addSibling(context, person),
                      child: const Text('Add Sibling'),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: () => _editPerson(context, person),
                      child: const Text('Edit'),
                    ),
