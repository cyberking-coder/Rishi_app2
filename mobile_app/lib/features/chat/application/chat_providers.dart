import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/supabase_client_provider.dart';
import '../data/chat_datasource.dart';
import '../domain/entities/chat_message.dart';

final chatDataSourceProvider = Provider<ChatDataSource>((ref) {
  return ChatDataSource(ref.watch(supabaseClientProvider));
});

class ChatState {
  final List<ChatMessage> messages;

  /// Loading the stored conversation on open. Distinct from [sending]
  /// because they render nothing alike: one is an empty screen, the
  /// other is a thinking bubble under a message that's already there.
  final bool loading;
  final bool sending;

  /// Set when the day's allowance is spent. Blocks the composer, unlike
  /// an ordinary failure, which leaves it open so the message can be
  /// sent again.
  final String? limitMessage;

  /// Only ever shown near the end of the allowance — see the screen.
  final int? remaining;

  const ChatState({
    this.messages = const [],
    this.loading = true,
    this.sending = false,
    this.limitMessage,
    this.remaining,
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? loading,
    bool? sending,
    String? limitMessage,
    int? remaining,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      loading: loading ?? this.loading,
      sending: sending ?? this.sending,
      // Deliberately not `?? this.limitMessage`: passing null has to be
      // able to clear it, or the composer stays locked after midnight.
      limitMessage: limitMessage,
      remaining: remaining ?? this.remaining,
    );
  }
}

class ChatController extends Notifier<ChatState> {
  @override
  ChatState build() {
    // Kick the history load off from build() rather than from the
    // screen's initState, so a rebuild of the screen doesn't refetch and
    // a second entry point later can't forget to.
    _load();
    return const ChatState();
  }

  ChatDataSource get _source => ref.read(chatDataSourceProvider);

  Future<void> _load() async {
    try {
      final messages = await _source.history();
      state = state.copyWith(messages: messages, loading: false);
    } catch (_) {
      // An unreadable history is not worth an error screen — the person
      // came here to ask something, and they still can.
      state = state.copyWith(loading: false);
    }
  }

  Future<void> send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.sending) return;

    final sent = ChatMessage.user(trimmed);
    state = state.copyWith(
      messages: [...state.messages, sent],
      sending: true,
      limitMessage: null,
    );

    try {
      final reply = await _source.send(trimmed);
      state = state.copyWith(
        messages: [...state.messages, reply.message],
        sending: false,
        remaining: reply.remaining,
      );
    } on ChatLimitReached catch (e) {
      // The question is taken back off the screen: it was never asked,
      // never stored, and leaving it sitting there under a "you're out
      // of questions" notice reads as though it might still be answered.
      state = state.copyWith(
        messages: state.messages.sublist(0, state.messages.length - 1),
        sending: false,
        limitMessage: e.message,
        remaining: 0,
      );
    } catch (e) {
      final failed = sent.copyWith(error: _describe(e));
      state = state.copyWith(
        messages: [
          ...state.messages.sublist(0, state.messages.length - 1),
          failed,
        ],
        sending: false,
      );
    }
  }

  /// Re-sends the last message after a failure.
  Future<void> retry() async {
    final messages = state.messages;
    if (messages.isEmpty || messages.last.error == null) return;
    final text = messages.last.text;
    state = state.copyWith(
      messages: messages.sublist(0, messages.length - 1),
    );
    await send(text);
  }

  Future<void> clear() async {
    final previous = state.messages;
    state = state.copyWith(messages: const []);
    try {
      await _source.clear();
    } catch (_) {
      // Put it back. A conversation that disappears from the screen and
      // returns on the next open is worse than one that never left.
      state = state.copyWith(messages: previous);
    }
  }

  String _describe(Object e) {
    final text = e.toString();
    return text.startsWith('Exception: ') ? text.substring(11) : text;
  }
}

final chatControllerProvider =
    NotifierProvider<ChatController, ChatState>(ChatController.new);
