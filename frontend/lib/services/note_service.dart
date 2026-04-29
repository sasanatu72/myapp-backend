import 'dart:convert';

import '../models/note.dart';
import 'api_client.dart';

class NoteService {
  NoteService({
    required this.apiClient,
  });

  final ApiClient apiClient;

  Future<List<Note>> getNotes() async {
    final response = await apiClient.get('/notes');

    if (response.statusCode != 200) {
      throw Exception(_extractErrorMessage(response.body, 'Note取得に失敗しました'));
    }

    final List<dynamic> data = jsonDecode(response.body);
    return data.map((e) => Note.fromJson(e)).toList();
  }

  Future<Note> createNote({
    required String title,
    required String content,
  }) async {
    final response = await apiClient.postJson(
      '/notes',
      {
        'title': title,
        'content': content,
      },
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(_extractErrorMessage(response.body, 'Note作成に失敗しました'));
    }

    return Note.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<Note> updateNote({
    required int id,
    required String title,
    required String content,
  }) async {
    final response = await apiClient.putJson(
      '/notes/$id',
      {
        'title': title,
        'content': content,
      },
    );

    if (response.statusCode != 200) {
      throw Exception(_extractErrorMessage(response.body, 'Note更新に失敗しました'));
    }

    return Note.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> deleteNote(int id) async {
    final response = await apiClient.delete('/notes/$id');

    if (response.statusCode != 200) {
      throw Exception(_extractErrorMessage(response.body, 'Note削除に失敗しました'));
    }
  }

  String _extractErrorMessage(String body, String fallback) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic> && decoded['detail'] != null) {
        return decoded['detail'].toString();
      }
    } catch (_) {}
    return fallback;
  }
}
