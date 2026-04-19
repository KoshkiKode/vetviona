import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/person.dart';
import '../models/research_task.dart';
import '../providers/tree_provider.dart';

/// Full research task manager — list, filter, add, edit, and mark tasks done.
class ResearchTasksScreen extends StatefulWidget {
  /// When [person] is provided the screen pre-filters to that person's tasks.
  final Person? person;

  const ResearchTasksScreen({super.key, this.person});

  @override
  State<ResearchTasksScreen> createState() => _ResearchTasksScreenState();
}

class _ResearchTasksScreenState extends State<ResearchTasksScreen> {
  String _statusFilter = 'all'; // 'all' | 'todo' | 'in_progress' | 'done'
  String _priorityFilter = 'all'; // 'all' | 'low' | 'normal' | 'high'

  List<ResearchTask> _applyFilters(List<ResearchTask> tasks) {
    var result = tasks;
    if (widget.person != null) {
      result = result.where((t) => t.personId == widget.person!.id).toList();
    }
    if (_statusFilter != 'all') {
      result = result.where((t) => t.status == _statusFilter).toList();
    }
    if (_priorityFilter != 'all') {
      result = result.where((t) => t.priority == _priorityFilter).toList();
    }
    // Sort: high priority first, then by status (todo → in_progress → done)
    result.sort((a, b) {
      const priorityOrder = {'high': 0, 'normal': 1, 'low': 2};
      const statusOrder = {'todo': 0, 'in_progress': 1, 'done': 2};
      final pCmp = (priorityOrder[a.priority] ?? 1)
          .compareTo(priorityOrder[b.priority] ?? 1);
      if (pCmp != 0) return pCmp;
      return (statusOrder[a.status] ?? 0)
          .compareTo(statusOrder[b.status] ?? 0);
    });
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TreeProvider>();
    final tasks = _applyFilters(provider.researchTasks);
    final colorScheme = Theme.of(context).colorScheme;
    final title = widget.person != null
        ? '${widget.person!.name} — Research Tasks'
        : 'Research Tasks';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: _FilterBar(
            statusFilter: _statusFilter,
            priorityFilter: _priorityFilter,
            onStatusChanged: (v) => setState(() => _statusFilter = v),
            onPriorityChanged: (v) => setState(() => _priorityFilter = v),
          ),
        ),
      ),
      body: tasks.isEmpty
          ? _EmptyState(
              hasAnyTasks: provider.researchTasks.isEmpty,
              isFiltered: _statusFilter != 'all' || _priorityFilter != 'all',
            )
          : Column(
              children: [
                _SummaryBar(tasks: provider.researchTasks, colorScheme: colorScheme),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 80),
                    itemCount: tasks.length,
                    itemBuilder: (context, i) => _TaskCard(
                      task: tasks[i],
                      provider: provider,
                    ),
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add_task),
        label: const Text('Add Task'),
        onPressed: () => _openTaskSheet(
            context, provider, widget.person?.id, null),
      ),
    );
  }

  static void _openTaskSheet(
    BuildContext context,
    TreeProvider provider,
    String? preselectedPersonId,
    ResearchTask? existing,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _TaskSheet(
        provider: provider,
        preselectedPersonId: preselectedPersonId,
        existing: existing,
      ),
    );
  }
}

// ── Summary bar ──────────────────────────────────────────────────────────────

class _SummaryBar extends StatelessWidget {
  final List<ResearchTask> tasks;
  final ColorScheme colorScheme;

  const _SummaryBar({required this.tasks, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    final todo = tasks.where((t) => t.status == 'todo').length;
    final inProg = tasks.where((t) => t.status == 'in_progress').length;
    final done = tasks.where((t) => t.status == 'done').length;

    return Container(
      color: colorScheme.primaryContainer.withValues(alpha: 0.25),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _StatusChip(
            label: 'To Do',
            count: todo,
            color: colorScheme.error,
          ),
          const SizedBox(width: 8),
          _StatusChip(
            label: 'In Progress',
            count: inProg,
            color: colorScheme.tertiary,
          ),
          const SizedBox(width: 8),
          _StatusChip(
            label: 'Done',
            count: done,
            color: colorScheme.primary,
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _StatusChip(
      {required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$count ',
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.bold, color: color),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: color),
          ),
        ],
      ),
    );
  }
}

// ── Filter bar ───────────────────────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  final String statusFilter;
  final String priorityFilter;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<String> onPriorityChanged;

  const _FilterBar({
    required this.statusFilter,
    required this.priorityFilter,
    required this.onStatusChanged,
    required this.onPriorityChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            _filterChip('All', 'all', statusFilter, onStatusChanged),
            const SizedBox(width: 6),
            _filterChip('To Do', 'todo', statusFilter, onStatusChanged),
            const SizedBox(width: 6),
            _filterChip(
                'In Progress', 'in_progress', statusFilter, onStatusChanged),
            const SizedBox(width: 6),
            _filterChip('Done', 'done', statusFilter, onStatusChanged),
            const SizedBox(width: 12),
            _filterChip(
                'High', 'high', priorityFilter, onPriorityChanged),
            const SizedBox(width: 6),
            _filterChip(
                'Normal', 'normal', priorityFilter, onPriorityChanged),
            const SizedBox(width: 6),
            _filterChip('Low', 'low', priorityFilter, onPriorityChanged),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(
    String label,
    String value,
    String current,
    ValueChanged<String> onChanged,
  ) =>
      FilterChip(
        label: Text(label),
        selected: current == value,
        onSelected: (_) => onChanged(value),
      );
}

// ── Task card ────────────────────────────────────────────────────────────────

class _TaskCard extends StatelessWidget {
  final ResearchTask task;
  final TreeProvider provider;

  const _TaskCard({required this.task, required this.provider});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final statusColor = _statusColor(task.status, colorScheme);
    final person = task.personId != null
        ? provider.persons
            .where((p) => p.id == task.personId)
            .firstOrNull
        : null;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        leading: _StatusIcon(status: task.status, color: statusColor),
        title: Text(
          task.title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            decoration:
                task.status == 'done' ? TextDecoration.lineThrough : null,
            color: task.status == 'done'
                ? colorScheme.onSurfaceVariant
                : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (person != null)
              Row(
                children: [
                  Icon(Icons.person_outline,
                      size: 12, color: colorScheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(person.name,
                      style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant)),
                ],
              ),
            if (task.notes != null && task.notes!.isNotEmpty)
              Text(
                task.notes!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                    fontSize: 12),
              ),
            const SizedBox(height: 4),
            Row(
              children: [
                _PriorityBadge(priority: task.priority),
                const SizedBox(width: 6),
                _StatusBadge(status: task.status, color: statusColor),
              ],
            ),
          ],
        ),
        isThreeLine: true,
        trailing: PopupMenuButton<String>(
          onSelected: (action) => _handleAction(context, action),
          itemBuilder: (_) => [
            if (task.status != 'todo')
              const PopupMenuItem(
                  value: 'todo',
                  child: ListTile(
                      leading: Icon(Icons.radio_button_unchecked),
                      title: Text('Mark To Do'),
                      contentPadding: EdgeInsets.zero)),
            if (task.status != 'in_progress')
              const PopupMenuItem(
                  value: 'in_progress',
                  child: ListTile(
                      leading: Icon(Icons.pending_outlined),
                      title: Text('Mark In Progress'),
                      contentPadding: EdgeInsets.zero)),
            if (task.status != 'done')
              const PopupMenuItem(
                  value: 'done',
                  child: ListTile(
                      leading: Icon(Icons.check_circle_outline),
                      title: Text('Mark Done'),
                      contentPadding: EdgeInsets.zero)),
            const PopupMenuItem(
                value: 'edit',
                child: ListTile(
                    leading: Icon(Icons.edit_outlined),
                    title: Text('Edit'),
                    contentPadding: EdgeInsets.zero)),
            const PopupMenuItem(
                value: 'delete',
                child: ListTile(
                    leading: Icon(Icons.delete_outline),
                    title: Text('Delete'),
                    contentPadding: EdgeInsets.zero)),
          ],
        ),
      ),
    );
  }

  void _handleAction(BuildContext context, String action) {
    switch (action) {
      case 'todo':
      case 'in_progress':
      case 'done':
        final updated = ResearchTask(
          id: task.id,
          personId: task.personId,
          title: task.title,
          notes: task.notes,
          status: action,
          priority: task.priority,
          treeId: task.treeId,
        );
        provider.updateResearchTask(updated);
      case 'edit':
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (_) => _TaskSheet(
            provider: provider,
            preselectedPersonId: task.personId,
            existing: task,
          ),
        );
      case 'delete':
        provider.deleteResearchTask(task.id);
    }
  }

  Color _statusColor(String status, ColorScheme cs) => switch (status) {
        'done' => cs.primary,
        'in_progress' => cs.tertiary,
        _ => cs.error,
      };
}

class _StatusIcon extends StatelessWidget {
  final String status;
  final Color color;
  const _StatusIcon({required this.status, required this.color});

  @override
  Widget build(BuildContext context) {
    final icon = switch (status) {
      'done' => Icons.check_circle,
      'in_progress' => Icons.pending,
      _ => Icons.radio_button_unchecked,
    };
    return Icon(icon, color: color, size: 28);
  }
}

class _PriorityBadge extends StatelessWidget {
  final String priority;
  const _PriorityBadge({required this.priority});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = switch (priority) {
      'high' => colorScheme.error,
      'low' => colorScheme.onSurfaceVariant,
      _ => colorScheme.tertiary,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        ResearchTask.priorityLabel(priority),
        style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  final Color color;
  const _StatusBadge({required this.status, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        ResearchTask.statusLabel(status),
        style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ── Empty state ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool hasAnyTasks;
  final bool isFiltered;
  const _EmptyState({required this.hasAnyTasks, required this.isFiltered});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final message = isFiltered
        ? 'No tasks match the current filters.'
        : 'No research tasks yet.\nTap + to add your first task.';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.assignment_outlined,
                  size: 40, color: colorScheme.onPrimaryContainer),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Add / Edit sheet ─────────────────────────────────────────────────────────

class _TaskSheet extends StatefulWidget {
  final TreeProvider provider;
  final String? preselectedPersonId;
  final ResearchTask? existing;

  const _TaskSheet({
    required this.provider,
    required this.preselectedPersonId,
    required this.existing,
  });

  @override
  State<_TaskSheet> createState() => _TaskSheetState();
}

class _TaskSheetState extends State<_TaskSheet> {
  late TextEditingController _titleController;
  late TextEditingController _notesController;
  String? _selectedPersonId;
  String _status = 'todo';
  String _priority = 'normal';

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _titleController = TextEditingController(text: e?.title ?? '');
    _notesController = TextEditingController(text: e?.notes ?? '');
    _selectedPersonId = e?.personId ?? widget.preselectedPersonId;
    _status = e?.status ?? 'todo';
    _priority = e?.priority ?? 'normal';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a task title.')),
      );
      return;
    }
    final task = ResearchTask(
      id: widget.existing?.id ?? const Uuid().v4(),
      personId: _selectedPersonId,
      title: _titleController.text.trim(),
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      status: _status,
      priority: _priority,
      treeId: widget.existing?.treeId,
    );
    if (widget.existing == null) {
      await widget.provider.addResearchTask(task);
    } else {
      await widget.provider.updateResearchTask(task);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final persons = [...widget.provider.persons]
      ..sort((a, b) => a.name.compareTo(b.name));

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  widget.existing == null ? 'Add Research Task' : 'Edit Task',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Task',
                hintText: 'e.g. Find baptism record for Maria Kowalski',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              decoration: const InputDecoration(
                labelText: 'Linked Person (optional)',
                border: OutlineInputBorder(),
              ),
              initialValue: _selectedPersonId,
              items: [
                const DropdownMenuItem<String?>(
                    value: null, child: Text('— Tree-level task —')),
                ...persons.map((p) =>
                    DropdownMenuItem<String?>(value: p.id, child: Text(p.name))),
              ],
              onChanged: (v) => setState(() => _selectedPersonId = v),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      border: OutlineInputBorder(),
                    ),
                    initialValue: _status,
                    items: ResearchTask.statuses
                        .map((s) => DropdownMenuItem(
                            value: s,
                            child: Text(ResearchTask.statusLabel(s))))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _status = v ?? _status),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Priority',
                      border: OutlineInputBorder(),
                    ),
                    initialValue: _priority,
                    items: ResearchTask.priorities
                        .map((p) => DropdownMenuItem(
                            value: p,
                            child: Text(ResearchTask.priorityLabel(p))))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _priority = v ?? _priority),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                border: OutlineInputBorder(),
              ),
              minLines: 2,
              maxLines: 4,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.save),
                label: const Text('Save Task'),
                onPressed: _save,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
