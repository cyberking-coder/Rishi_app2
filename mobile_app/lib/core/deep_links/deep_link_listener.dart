import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/router/app_router.dart';
import '../../features/lms/application/lms_providers.dart';

/// Listens for `meditationapp://` links and routes them.
///
/// Right now this only handles `payment-success` — the course checkout
/// web page opens that link once Razorpay confirms a payment, so paying
/// returns the user straight to their (now-unlocked) course instead of
/// leaving them stranded in the browser with no way back. Password-reset
/// links use the same scheme but are handled by Supabase's own auth
/// listener, not here.
class DeepLinkListener extends ConsumerStatefulWidget {
  final Widget child;

  const DeepLinkListener({super.key, required this.child});

  @override
  ConsumerState<DeepLinkListener> createState() => _DeepLinkListenerState();
}

class _DeepLinkListenerState extends ConsumerState<DeepLinkListener> {
  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _subscription;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // Cold start: the app was launched BY tapping the link.
    try {
      final initial = await _appLinks.getInitialAppLink();
      if (initial != null) _handle(initial);
    } catch (_) {
      // Platform channel can throw on some devices; a missed cold-start
      // link isn't worth crashing over.
    }

    // Warm: the app was already running (foreground or background).
    _subscription = _appLinks.uriLinkStream.listen(_handle, onError: (_) {});
  }

  void _handle(Uri uri) {
    if (uri.scheme != 'meditationapp' || uri.host != 'payment-success') {
      return;
    }

    final courseId = uri.queryParameters['course_id'];
    if (courseId == null || courseId.isEmpty) return;

    // Course access is decided by the course row's own purchase state
    // (has_course_access), not the subscription — so without this the
    // cached catalog/detail would still show the course locked right
    // after a successful payment.
    ref.invalidate(coursesProvider);
    ref.invalidate(courseDetailProvider(courseId));

    ref.read(goRouterProvider).push('/course/$courseId');
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
