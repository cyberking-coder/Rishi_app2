/// A link the assistant offered to somewhere in the app.
///
/// The model writes these as markdown — `[Morning Stillness](app://audio/…)`
/// — and they are pulled out of the text before it reaches the screen.
/// Inline tappable spans were the alternative; chips won because a link
/// buried in a paragraph is a small target on a phone, and because a
/// RichText full of gesture recognisers has to dispose of every one of
/// them.
class ChatLink {
  final String label;

  /// 'audio' or 'course'. Anything else is dropped at parse time rather
  /// than carried to the router to fail there.
  final String kind;
  final String id;

  const ChatLink({
    required this.label,
    required this.kind,
    required this.id,
  });

  /// Where tapping this goes. Both routes already exist: /audio/:id is
  /// where the daily notification lands, /course/:id is the course page.
  String get route => kind == 'course' ? '/course/$id' : '/audio/$id';
}

enum ChatRole { user, assistant }

class ChatMessage {
  final ChatRole role;

  /// The body with the markdown link syntax removed — the label survives
  /// in place, so a sentence still reads as a sentence.
  final String text;

  final List<ChatLink> links;

  /// True while a reply is in flight, so the screen can show the message
  /// as sent and the answer as thinking without inventing a second list.
  final bool pending;

  /// Set when the turn failed. The message stays on screen with the
  /// reason attached rather than vanishing, which is what makes "try
  /// again" mean anything.
  final String? error;

  const ChatMessage({
    required this.role,
    required this.text,
    this.links = const [],
    this.pending = false,
    this.error,
  });

  factory ChatMessage.user(String text) =>
      ChatMessage(role: ChatRole.user, text: text);

  /// Parses an assistant reply, splitting the app links out of the prose.
  factory ChatMessage.assistant(String raw) {
    final links = <ChatLink>[];

    final text = raw.replaceAllMapped(_linkPattern, (m) {
      final label = m.group(1)!;
      links.add(ChatLink(label: label, kind: m.group(2)!, id: m.group(3)!));
      return label;
    });

    return ChatMessage(
      role: ChatRole.assistant,
      text: text.trim(),
      // The same track named twice in one answer is one chip, not two.
      links: {for (final l in links) '${l.kind}/${l.id}': l}.values.toList(),
    );
  }

  ChatMessage copyWith({bool? pending, String? error}) => ChatMessage(
        role: role,
        text: text,
        links: links,
        pending: pending ?? this.pending,
        error: error,
      );

  /// Deliberately strict about the id: a uuid shape, nothing else. A
  /// looser pattern would happily accept a hallucinated slug and hand it
  /// to a route that then shows an empty screen.
  static final RegExp _linkPattern = RegExp(
    r'\[([^\]\n]+)\]\(app://(audio|course)/'
    r'([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
    r'[0-9a-fA-F]{4}-[0-9a-fA-F]{12})\)',
  );
}
