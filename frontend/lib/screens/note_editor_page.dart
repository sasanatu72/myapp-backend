import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/note.dart';
import '../services/note_service.dart';
import '../widgets/app_page_container.dart';

class NoteEditorPage extends StatefulWidget {
  const NoteEditorPage({
    super.key,
    this.note,
  });

  final Note? note;

  bool get isEdit => note != null;

  @override
  State<NoteEditorPage> createState() => _NoteEditorPageState();
}

class _NoteEditorPageState extends State<NoteEditorPage> {
  static const Duration _autoSaveDelay = Duration(milliseconds: 900);

  late final TextEditingController _titleController;
  late final TextEditingController _contentController;

  Timer? _autoSaveTimer;
  int? _noteId;

  bool _isSaving = false;
  bool _hasSavedChanges = false;
  bool _isPopping = false;
  String? _saveErrorMessage;

  late String _lastSavedTitle;
  late String _lastSavedContent;

  @override
  void initState() {
    super.initState();

    _noteId = widget.note?.id;
    _lastSavedTitle = widget.note?.title ?? '';
    _lastSavedContent = widget.note?.content ?? '';

    _titleController = TextEditingController(text: _lastSavedTitle);
    _contentController = TextEditingController(text: _lastSavedContent);

    _titleController.addListener(_scheduleAutoSave);
    _contentController.addListener(_scheduleAutoSave);
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  bool get _hasUnsavedChanges {
    return _normalizedTitle != _lastSavedTitle ||
        _contentController.text != _lastSavedContent;
  }

  String get _normalizedTitle {
    final title = _titleController.text.trim();
    return title.isEmpty ? '無題' : title;
  }

  bool get _isCompletelyEmpty {
    return _titleController.text.trim().isEmpty &&
        _contentController.text.trim().isEmpty;
  }

  void _scheduleAutoSave() {
    _autoSaveTimer?.cancel();

    if (_isPopping) return;

    setState(() {
      _saveErrorMessage = null;
    });

    _autoSaveTimer = Timer(_autoSaveDelay, () {
      _saveNow();
    });
  }

  Future<bool> _saveNow() async {
    if (_isSaving) return false;
    if (!_hasUnsavedChanges) return true;

    // 新規ノートでタイトルも本文も空なら、空のノートは作らない。
    if (_noteId == null && _isCompletelyEmpty) return true;

    setState(() {
      _isSaving = true;
      _saveErrorMessage = null;
    });

    try {
      final service = context.read<NoteService>();
      final title = _normalizedTitle;
      final content = _contentController.text;

      final savedNote = _noteId == null
          ? await service.createNote(
              title: title,
              content: content,
            )
          : await service.updateNote(
              id: _noteId!,
              title: title,
              content: content,
            );

      if (!mounted) return false;

      setState(() {
        _noteId = savedNote.id;
        _lastSavedTitle = savedNote.title;
        _lastSavedContent = savedNote.content;
        _hasSavedChanges = true;
        _isSaving = false;
      });

      return true;
    } catch (e) {
      if (!mounted) return false;

      setState(() {
        _saveErrorMessage = e.toString().replaceFirst('Exception: ', '');
        _isSaving = false;
      });

      return false;
    }
  }

  Future<void> _finishAndPop() async {
    if (_isPopping) return;

    _isPopping = true;
    _autoSaveTimer?.cancel();

    final canPop = await _saveNow();

    if (!mounted) return;

    if (!canPop) {
      setState(() {
        _isPopping = false;
      });
      return;
    }

    Navigator.pop(context, _hasSavedChanges);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return WillPopScope(
      onWillPop: () async {
        await _finishAndPop();
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _finishAndPop,
          ),
          title: Text(widget.isEdit ? 'ノート編集' : 'ノート作成'),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: _SaveStatusLabel(
                  isSaving: _isSaving,
                  hasUnsavedChanges: _hasUnsavedChanges,
                  hasError: _saveErrorMessage != null,
                ),
              ),
            ),
          ],
        ),
        body: AppPageContainer(
          maxWidth: 720,
          child: Column(
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  child: TextField(
                    controller: _titleController,
                    textInputAction: TextInputAction.next,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                    decoration: const InputDecoration(
                      hintText: 'タイトル',
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ),
              if (_saveErrorMessage != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 18,
                      color: colorScheme.error,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _saveErrorMessage!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.error,
                            ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 14),
              Expanded(
                child: TextField(
                  controller: _contentController,
                  expands: true,
                  minLines: null,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  textAlignVertical: TextAlignVertical.top,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        height: 1.6,
                      ),
                  decoration: const InputDecoration(
                    hintText: '本文を入力',
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    alignLabelWithHint: false,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SaveStatusLabel extends StatelessWidget {
  const _SaveStatusLabel({
    required this.isSaving,
    required this.hasUnsavedChanges,
    required this.hasError,
  });

  final bool isSaving;
  final bool hasUnsavedChanges;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (hasError) {
      return Text(
        '保存失敗',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.error,
              fontWeight: FontWeight.w600,
            ),
      );
    }

    if (isSaving) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 6),
          Text(
            '保存中',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      );
    }

    return Text(
      hasUnsavedChanges ? '未保存' : '保存済み',
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
    );
  }
}
