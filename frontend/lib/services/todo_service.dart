import 'dart:convert';

import '../models/todo.dart';
import 'api_client.dart';

class TodoService {
  TodoService({
    required this.apiClient,
  });

  final ApiClient apiClient;

  Future<List<Todo>> getTodos() async {
    final response = await apiClient.get('/todos');

    if (response.statusCode != 200) {
      throw Exception(_extractErrorMessage(response.body, 'Todo取得に失敗しました'));
    }

    final List<dynamic> data = jsonDecode(response.body);
    return data.map((e) => Todo.fromJson(e)).toList();
  }

  Future<void> createTodo({
    required String title,
    DateTime? dueDate,
  }) async {
    final response = await apiClient.postJson(
      '/todos',
      {
        'title': title,
        'due_date': dueDate?.toIso8601String().split('T').first,
      },
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(_extractErrorMessage(response.body, 'Todo作成に失敗しました'));
    }
  }

  Future<void> updateTodo({
    required int id,
    String? title,
    bool? isDone,
    DateTime? dueDate,
    bool clearDueDate = false,
  }) async {
    final body = <String, dynamic>{};

    if (title != null) body['title'] = title;
    if (isDone != null) body['is_done'] = isDone;

    if (clearDueDate) {
      body['due_date'] = null;
    } else if (dueDate != null) {
      body['due_date'] = dueDate.toIso8601String().split('T').first;
    }

    final response = await apiClient.putJson('/todos/$id', body);

    if (response.statusCode != 200) {
      throw Exception(_extractErrorMessage(response.body, 'Todo更新に失敗しました'));
    }
  }

  Future<void> deleteTodo(int id) async {
    final response = await apiClient.delete('/todos/$id');

    if (response.statusCode != 200) {
      throw Exception(_extractErrorMessage(response.body, 'Todo削除に失敗しました'));
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
