import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';
import '../domain/entities/help_entities.dart';

/// Reads FAQs and reads/writes the caller's tickets, messages and
/// feedback.
///
/// RLS scopes every one of these to the caller, so none of the queries
/// filters on user_id defensively — except where an index wants it.
class HelpRemoteDataSource {
  final SupabaseClient _client;

  HelpRemoteDataSource(this._client);

  /// Every published FAQ, in the order an admin arranged them.
  ///
  /// The whole list, once. There are dozens, not thousands, and search
  /// then happens in the app — which means it is instant, works while a
  /// query is being typed, and keeps working when the connection does
  /// not. A query per keystroke would be worse in all three ways.
  Future<List<Faq>> getFaqs() async {
    final rows = await _client
        .from('faqs')
        .select('id, category, question, answer, keywords')
        .eq('is_published', true)
        .order('category')
        .order('sort_order');

    return [
      for (final row in rows as List)
        Faq.fromMap(Map<String, dynamic>.from(row as Map)),
    ];
  }

  Future<List<SupportTicket>> getMyTickets() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    final rows = await _client
        .from('support_tickets')
        .select('id, reference, category, subject, status, created_at, updated_at')
        .eq('user_id', userId)
        .order('updated_at', ascending: false);

    return [
      for (final row in rows as List)
        SupportTicket.fromMap(Map<String, dynamic>.from(row as Map)),
    ];
  }

  Future<List<SupportMessage>> getMessages(String ticketId) async {
    final rows = await _client
        .from('support_messages')
        .select('id, body, from_staff, created_at')
        .eq('ticket_id', ticketId)
        .order('created_at');

    return [
      for (final row in rows as List)
        SupportMessage.fromMap(Map<String, dynamic>.from(row as Map)),
    ];
  }

  /// Creates a ticket and its opening message.
  ///
  /// Two writes, not one, and deliberately in this order: the message is
  /// the child, so a failure between them leaves a ticket with no body —
  /// visible, answerable, and obviously incomplete — rather than an
  /// orphaned message pointing at nothing. Support can still see who
  /// wrote it and ask.
  ///
  /// Note what is NOT sent: status and priority. The column grant in the
  /// migration refuses them, so a client cannot open its own ticket at
  /// high priority or pre-resolved.
  Future<String> createTicket({
    required HelpCategory category,
    required String subject,
    required String body,
    String? contentId,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('You need to be signed in to contact support.');
    }

    final inserted = await _client
        .from('support_tickets')
        .insert({
          'user_id': userId,
          'category': category.wire,
          'subject': subject,
          'content_id': contentId,
          'client_context': await collectClientContext(),
        })
        .select('id')
        .single();

    final ticketId = inserted['id'] as String;
    await sendMessage(ticketId: ticketId, body: body);
    return ticketId;
  }

  Future<void> sendMessage({
    required String ticketId,
    required String body,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    // from_staff and is_internal are not sent — the column grant does not
    // permit them, which is what stops a member's message arriving in a
    // support inbox dressed as a reply from support.
    await _client.from('support_messages').insert({
      'ticket_id': ticketId,
      'sender_id': userId,
      'body': body,
    });
  }

  Future<void> submitFeedback({
    required FeedbackType type,
    required String message,
    int? rating,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('You need to be signed in to send feedback.');
    }

    await _client.from('feedback').insert({
      'user_id': userId,
      'type': type.wire,
      'message': message,
      'rating': rating,
    });
  }

  /// The facts that make a report reproducible, gathered rather than
  /// asked for.
  ///
  /// A member should not be made to find their OS version to report a
  /// crash — they usually cannot, and the report is worth less without
  /// it. What goes in is limited to app version, platform, OS version and
  /// device model.
  ///
  /// What never goes in: card details, passwords, tokens, or anything
  /// else that would turn a support table into a place worth breaking
  /// into. If you add a field here, ask what it would cost to leak.
  ///
  /// Never throws. A ticket that arrives without context is far better
  /// than one that could not be created because a plugin failed.
  Future<Map<String, dynamic>> collectClientContext() async {
    final context = <String, dynamic>{
      'app': AppConfig.appName,
      'app_version': AppConfig.appVersion,
    };

    try {
      final plugin = DeviceInfoPlugin();
      if (Platform.isIOS) {
        final info = await plugin.iosInfo;
        context['platform'] = 'ios';
        context['os_version'] = info.systemVersion;
        context['device'] = info.utsname.machine;
      } else if (Platform.isAndroid) {
        final info = await plugin.androidInfo;
        context['platform'] = 'android';
        context['os_version'] = 'Android ${info.version.release}';
        context['device'] = '${info.manufacturer} ${info.model}';
      }
    } catch (_) {
      context['platform'] = Platform.operatingSystem;
    }

    return context;
  }
}
