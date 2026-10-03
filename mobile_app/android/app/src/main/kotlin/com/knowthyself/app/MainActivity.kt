package com.knowthyself.app

import com.ryanheise.audioservice.AudioServiceActivity

// Must extend AudioServiceActivity (not FlutterActivity) — this is how the
// audio_service plugin binds the running media/foreground service to the UI.
// Without it the background media notification does not appear and audio does
// not reliably continue when the app is backgrounded or swiped away.
class MainActivity : AudioServiceActivity()
