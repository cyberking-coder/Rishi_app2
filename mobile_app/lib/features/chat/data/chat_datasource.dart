import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/entities/chat_message.dart';

/// Thrown when the day's allowance is spent. Separate from a general
/// failure because it is not an error the user should retry — it is an
/// answer, and the screen says so instead of offering "try again".
class ChatLimitReached implements Exception {
  final String message;
  const ChatLimitReached(this.message);

  @override
  String toString() => message;
}

class ChatReply {
  final ChatMessage message;

  /// Questions left today. Shown only as it runs low; a counter on
  /// screen from the first message makes a conversation feel metered.
  final int remaining;

  const ChatReply({required this.message, required this.remaining});
}

class ChatDataSource {
  final SupabaseClient _client;

  ChatDataSource(this._client);

  /// The conversation so far, oldest first.
  ///
  /// Read straight from the table rather than through the function: this
  /// is the user's own data under RLS, and routing a plain select
  /// through an edge function would add a cold start to opening a screen.
  Future<List<ChatMessage>> history({int limit = 60}) async {
    final rows = await _client
        .from('chat_messages')
        .select('role, content')
        .order('created_at', ascending: false)
        .limit(limit);

    return [
      for (final row in (rows as List).reversed)
        (row as Map)['role'] == 'user'
            ? ChatMessage.user(row['content'] as String)
            : ChatMessage.assistant(row['content'] as String),
    ];
  }

  Future<ChatReply> send(String message) async {
    try {
      final response = await _client.functions.invoke(
        'chat',
        body: {'message': message},
      );

      final data = response.data as Map<String, dynamic>;
      return ChatReply(
        message: ChatMessage.assistant(data['reply'] as String),
        remaining: (data['remaining'] as num?)?.toInt() ?? 0,
      );
    } on FunctionException catch (e) {
      final details = e.details;
      final written = (details is Map && details['error'] is String)
          ? details['error'] as String
          : null;

      if (e.status == 429) {
        throw ChatLimitReached(
          written ?? 'You have reached today\'s questions.',
        );
      }
      throw Exception(written ?? 'The guide is unavailable right now.');
    }
  }

  /// Wipes the conversation. RLS scopes the delete to the caller, so the
  /// missing where-clause here is not the accident it looks like — there
  /// is no row this statement could reach that isn't theirs.
  Future<void> clear() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    await _client.from('chat_messages').delete().eq('user_id', userId);
  }
}
