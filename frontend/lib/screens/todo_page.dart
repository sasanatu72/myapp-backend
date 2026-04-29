import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/todo.dart';
import '../services/todo_service.dart';
import '../utils/date_utils.dart';
import '../widgets/app_page_container.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_state.dart';
import '../widgets/settings_action.dart';

enum _TodoSortType {
  incomplete,
  completed,
  name,
  dueDate,
}

class TodoPage extends StatefulWidget {
  const TodoPage({super.key});

  @override
  State<TodoPage> createState() => _TodoPageState();
}

class _TodoPageState extends State<TodoPage> {
  final _searchController = TextEditingController();

  List<Todo> _todos = [];
  bool _isLoading = true;
  String? _errorMessage;

  _TodoSortType _sortType = _TodoSortType.incomplete;
  bool _sortAscending = true;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {});
    });
    Future.microtask(_loadTodos);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTodos() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final todos = await context.read<TodoService>().getTodos();

      if (!mounted) return;

      setState(() {
        _todos = todos;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  List<Todo> get _filteredAndSortedTodos {
    final query = _searchController.text.trim().toLowerCase();
    final filteredTodos = _todos.where((todo) {
      if (query.isEmpty) return true;
      return todo.title.toLowerCase().contains(query);
    }).toList();

    filteredTodos.sort(_compareTodos);
    return filteredTodos;
  }

  int _compareTodos(Todo a, Todo b) {
    late int result;

    switch (_sortType) {
      case _TodoSortType.incomplete:
        result = _compareIncompleteFirst(a, b);
        break;
      case _TodoSortType.completed:
        result = _compareCompletedFirst(a, b);
        break;
      case _TodoSortType.name:
        result = a.title.toLowerCase().compareTo(b.title.toLowerCase());
        break;
      case _TodoSortType.dueDate:
        result = _compareDueDate(a, b);
        if (result != 0) return result;
        return a.id.compareTo(b.id);
    }

    if (!_sortAscending) {
      result = -result;
    }

    if (result != 0) return result;
    return a.id.compareTo(b.id);
  }

  int _compareIncompleteFirst(Todo a, Todo b) {
    if (a.isDone == b.isDone) return 0;
    return a.isDone ? 1 : -1;
  }

  int _compareCompletedFirst(Todo a, Todo b) {
    if (a.isDone == b.isDone) return 0;
    return a.isDone ? -1 : 1;
  }

  int _compareDueDate(Todo a, Todo b) {
    final aDueDate = a.dueDate;
    final bDueDate = b.dueDate;

    if (aDueDate == null && bDueDate == null) return 0;
    if (aDueDate == null) return 1;
    if (bDueDate == null) return -1;

    final result = aDueDate.compareTo(bDueDate);
    return _sortAscending ? result : -result;
  }

  void _onSortSelected(_TodoSortType sortType) {
    setState(() {
      if (_sortType == sortType) {
        _sortAscending = !_sortAscending;
      } else {
        _sortType = sortType;
        _sortAscending = true;
      }
    });
  }

  String _sortLabel(_TodoSortType sortType) {
    switch (sortType) {
      case _TodoSortType.incomplete:
        return '未完了';
      case _TodoSortType.completed:
        return '完了';
      case _TodoSortType.name:
        return '名前順';
      case _TodoSortType.dueDate:
        return '期限順';
    }
  }

  String get _currentSortLabel {
    return '${_sortLabel(_sortType)}・${_sortAscending ? '昇順' : '降順'}';
  }

  Future<void> _showTodoDialog({Todo? todo}) async {
    final isEdit = todo != null;
    final controller = TextEditingController(text: todo?.title ?? '');
    DateTime? dueDate = todo?.dueDate;

    try {
      final result = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: Text(isEdit ? 'タスク編集' : 'タスク追加'),
                content: SizedBox(
                  width: 420,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: controller,
                        autofocus: true,
                        decoration: const InputDecoration(
                          labelText: 'タイトル',
                          prefixIcon: Icon(Icons.check_circle_outline),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Card(
                        child: ListTile(
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 12),
                          leading: const Icon(Icons.calendar_today),
                          title: const Text('期限'),
                          subtitle: Text(
                            dueDate == null ? '未設定' : formatDate(dueDate!),
                          ),
                          trailing: dueDate == null
                              ? const Icon(Icons.chevron_right)
                              : IconButton(
                                  tooltip: '期限を削除',
                                  onPressed: () {
                                    setDialogState(() {
                                      dueDate = null;
                                    });
                                  },
                                  icon: const Icon(Icons.close),
                                ),
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: dialogContext,
                              initialDate: dueDate ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100),
                            );

                            if (picked != null) {
                              setDialogState(() {
                                dueDate = picked;
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: const Text('キャンセル'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    child: Text(isEdit ? '保存' : '追加'),
                  ),
                ],
              );
            },
          );
        },
      );

      if (result != true) return;

      final title = controller.text.trim();
      if (title.isEmpty) return;

      try {
        if (isEdit) {
          await context.read<TodoService>().updateTodo(
                id: todo.id,
                title: title,
                dueDate: dueDate,
                clearDueDate: todo.dueDate != null && dueDate == null,
              );
        } else {
          await context.read<TodoService>().createTodo(
                title: title,
                dueDate: dueDate,
              );
        }

        await _loadTodos();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      controller.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('タスク'),
        actions: const [SettingsAction()],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showTodoDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return AppPageContainer(
        child: ErrorState(
          message: _errorMessage!,
          onRetry: _loadTodos,
        ),
      );
    }

    if (_todos.isEmpty) {
      return AppPageContainer(
        child: EmptyState(
          icon: Icons.check_circle_outline,
          title: 'タスクはまだありません',
          message: '右下の＋ボタンから、新しいタスクを追加できます。',
          actionLabel: 'タスクを追加',
          onAction: () => _showTodoDialog(),
        ),
      );
    }

    final visibleTodos = _filteredAndSortedTodos;
    final completedCount = _todos.where((todo) => todo.isDone).length;
    final totalCount = _todos.length;

    return AppPageContainer(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                '完了済み $completedCount/$totalCount',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: 'タスクを検索',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isEmpty
                        ? null
                        : IconButton(
                            onPressed: _searchController.clear,
                            icon: const Icon(Icons.close),
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<_TodoSortType>(
                tooltip: '並び替え',
                onSelected: _onSortSelected,
                itemBuilder: (context) {
                  return _TodoSortType.values.map((sortType) {
                    final isSelected = _sortType == sortType;
                    return PopupMenuItem<_TodoSortType>(
                      value: sortType,
                      child: Row(
                        children: [
                          Icon(
                            isSelected
                                ? (_sortAscending
                                    ? Icons.arrow_upward
                                    : Icons.arrow_downward)
                                : Icons.sort,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Text(_sortLabel(sortType)),
                        ],
                      ),
                    );
                  }).toList();
                },
                child: Tooltip(
                  message: '現在: $_currentSortLabel',
                  child: Container(
                    height: 56,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.sort),
                        const SizedBox(width: 4),
                        Text(
                          _sortLabel(_sortType),
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: visibleTodos.isEmpty
                ? const EmptyState(
                    icon: Icons.search_off,
                    title: '一致するタスクがありません',
                    message: '別のキーワードで検索してください。',
                  )
                : ListView.separated(
                    itemCount: visibleTodos.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final todo = visibleTodos[index];
                      return _TodoCard(
                        todo: todo,
                        onChanged: (value) => _toggleTodo(todo, value ?? false),
                        onEdit: () => _showTodoDialog(todo: todo),
                        onDelete: () => _deleteTodo(todo),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleTodo(Todo todo, bool isDone) async {
    try {
      await context.read<TodoService>().updateTodo(
            id: todo.id,
            isDone: isDone,
          );
      await _loadTodos();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  Future<void> _deleteTodo(Todo todo) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('タスクを削除しますか？'),
          content: Text('「${todo.title}」を削除します。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('削除'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) return;

    try {
      await context.read<TodoService>().deleteTodo(todo.id);
      await _loadTodos();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }
}

class _TodoCard extends StatelessWidget {
  const _TodoCard({
    required this.todo,
    required this.onChanged,
    required this.onEdit,
    required this.onDelete,
  });

  final Todo todo;
  final ValueChanged<bool?> onChanged;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final titleStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          decoration: todo.isDone ? TextDecoration.lineThrough : null,
          color: todo.isDone ? colorScheme.onSurfaceVariant : colorScheme.onSurface,
        );

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          width: 36,
                          height: 36,
                          child: Checkbox(
                            value: todo.isDone,
                            onChanged: onChanged,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            todo.title,
                            style: titleStyle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 42, top: 2),
                      child: Text(
                        todo.dueDate != null
                            ? '期限: ${formatDate(todo.dueDate!)}'
                            : '期限なし',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: '編集',
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: onEdit,
                  ),
                  IconButton(
                    tooltip: '削除',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: onDelete,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
