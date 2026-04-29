import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/note.dart';
import '../services/note_service.dart';
import '../utils/date_utils.dart';
import '../widgets/app_page_container.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_state.dart';
import '../widgets/settings_action.dart';
import 'note_editor_page.dart';

enum _NoteSortType {
  updatedAt,
  createdAt,
  title,
}

class NotePage extends StatefulWidget {
  const NotePage({super.key});

  @override
  State<NotePage> createState() => _NotePageState();
}

class _NotePageState extends State<NotePage> {
  final _searchController = TextEditingController();

  List<Note> _notes = [];
  bool _isLoading = true;
  String? _errorMessage;

  _NoteSortType _sortType = _NoteSortType.updatedAt;
  bool _sortAscending = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {});
    });
    Future.microtask(_loadNotes);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadNotes() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final notes = await context.read<NoteService>().getNotes();

      if (!mounted) return;

      setState(() {
        _notes = notes;
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

  List<Note> get _filteredAndSortedNotes {
    final query = _searchController.text.trim().toLowerCase();
    final filteredNotes = _notes.where((note) {
      if (query.isEmpty) return true;
      return note.title.toLowerCase().contains(query) ||
          note.content.toLowerCase().contains(query);
    }).toList();

    filteredNotes.sort(_compareNotes);
    return filteredNotes;
  }

  int _compareNotes(Note a, Note b) {
    late int result;

    switch (_sortType) {
      case _NoteSortType.updatedAt:
        result = a.updatedAt.compareTo(b.updatedAt);
        break;
      case _NoteSortType.createdAt:
        result = a.createdAt.compareTo(b.createdAt);
        break;
      case _NoteSortType.title:
        result = a.title.toLowerCase().compareTo(b.title.toLowerCase());
        break;
    }

    if (!_sortAscending) {
      result = -result;
    }

    if (result != 0) return result;
    return b.id.compareTo(a.id);
  }

  void _onSortSelected(_NoteSortType sortType) {
    setState(() {
      if (_sortType == sortType) {
        _sortAscending = !_sortAscending;
      } else {
        _sortType = sortType;
        _sortAscending = sortType == _NoteSortType.title;
      }
    });
  }

  String _sortLabel(_NoteSortType sortType) {
    switch (sortType) {
      case _NoteSortType.updatedAt:
        return '更新順';
      case _NoteSortType.createdAt:
        return '作成順';
      case _NoteSortType.title:
        return 'タイトル順';
    }
  }

  String get _currentSortLabel {
    return '${_sortLabel(_sortType)}・${_sortAscending ? '昇順' : '降順'}';
  }

  Future<void> _openEditor({Note? note}) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => NoteEditorPage(note: note),
      ),
    );

    if (result == true) {
      await _loadNotes();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ノート'),
        actions: const [SettingsAction()],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditor(),
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
          onRetry: _loadNotes,
        ),
      );
    }

    if (_notes.isEmpty) {
      return AppPageContainer(
        child: EmptyState(
          icon: Icons.note_add_outlined,
          title: 'ノートはまだありません',
          message: '右下の＋ボタンから、メモやアイデアを保存できます。',
          actionLabel: 'ノートを追加',
          onAction: () => _openEditor(),
        ),
      );
    }

    final visibleNotes = _filteredAndSortedNotes;

    return AppPageContainer(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: 'ノートを検索',
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
              PopupMenuButton<_NoteSortType>(
                tooltip: '並び替え',
                onSelected: _onSortSelected,
                itemBuilder: (context) {
                  return _NoteSortType.values.map((sortType) {
                    final isSelected = _sortType == sortType;
                    return PopupMenuItem<_NoteSortType>(
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
            child: visibleNotes.isEmpty
                ? const EmptyState(
                    icon: Icons.search_off,
                    title: '一致するノートがありません',
                    message: '別のキーワードで検索してください。',
                  )
                : ListView.separated(
                    itemCount: visibleNotes.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final note = visibleNotes[index];
                      return _NoteCard(
                        note: note,
                        onTap: () => _openEditor(note: note),
                        onDelete: () => _deleteNote(note),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteNote(Note note) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('ノートを削除しますか？'),
          content: Text('「${note.title}」を削除します。'),
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
      await context.read<NoteService>().deleteNote(note.id);
      await _loadNotes();
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

class _NoteCard extends StatelessWidget {
  const _NoteCard({
    required this.note,
    required this.onTap,
    required this.onDelete,
  });

  final Note note;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final preview = note.content.trim().isEmpty ? '本文なし' : note.content.trim();
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      note.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      preview,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '更新: ${formatDateTime(note.updatedAt)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: '削除',
                icon: const Icon(Icons.delete_outline),
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
