import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Opens the Now Playing screen exactly once.
///
/// Home, Browse, the mini player and the lesson launcher can each push
/// `/now-playing`, and a fast double-tap — or two of them firing close
/// together — used to stack two identical player screens on top of each
/// other. This centralises the navigation with two guards:
///
///   1. It does nothing if the player is already the current route.
///   2. It ignores a second call while a push is still in flight (the
///      module-level lock), which closes the window between the tap and the
///      route actually becoming current.
///
/// Deep links deliberately do NOT use this: `/audio/:id` opens the player
/// with `pushReplacement` so Back does not return to a loading screen, which
/// is a different intent from a tap inside the app.
bool _openingNowPlaying = false;

Future<void> openNowPlaying(BuildContext context) async {
  if (_openingNowPlaying) return;
  if (GoRouterState.of(context).matchedLocation == '/now-playing') return;

  _openingNowPlaying = true;
  try {
    await context.push('/now-playing');
  } finally {
    _openingNowPlaying = false;
  }
}
