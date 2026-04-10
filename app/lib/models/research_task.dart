class ResearchTask {
  String id;

  /// Optionally linked to a specific person; null means the task applies
  /// to the tree in general.
  String? personId;
  String title;
  String? notes;

  /// One of `todo`, `in_progress`, `done`.
  String status;

  /// One of `low`, `normal`, `high`.
  String priority;
  String? treeId;

  static const List<String> statuses = ['todo', 'in_progress', 'done'];
  static const List<String> priorities = ['low', 'normal', 'high'];

  static String statusLabel(String status) => switch (status) {
        'in_progress' => 'In Progress',
        'done' => 'Done',
        _ => 'To Do',
      };

  static String priorityLabel(String priority) => switch (priority) {
        'high' => 'High',
        'low' => 'Low',
        _ => 'Normal',
      };

  ResearchTask({
    required this.id,
    this.personId,
    required this.title,
    this.notes,
    this.status = 'todo',
    this.priority = 'normal',
    this.treeId,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'personId': personId,
        'title': title,
        'notes': notes,
        'status': status,
        'priority': priority,
        'treeId': treeId,
      };

  factory ResearchTask.fromMap(Map<String, dynamic> map) => ResearchTask(
        id: map['id'] as String,
        personId: map['personId'] as String?,
        title: map['title'] as String,
        notes: map['notes'] as String?,
        status: map['status'] as String? ?? 'todo',
        priority: map['priority'] as String? ?? 'normal',
        treeId: map['treeId'] as String?,
      );
}
