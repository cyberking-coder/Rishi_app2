import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Dictation, wrapped so the rest of the app never touches the plugin.
///
/// Recognition happens on the handset — Android's SpeechRecognizer, iOS's
/// SFSpeechRecognizer. No audio is uploaded, no transcription API is
/// billed, and whatever languages the phone already handles are the
/// languages this handles. On a phone set to Hindi, Hindi comes back.
///
/// Everything here fails soft. A device with no recogniser, a denied
/// microphone, a network drop mid-sentence: all of them end with the
/// button returning to its resting state and a sentence the user can
/// read, never with a stuck listening state or a crash.
class SpeechService {
  final SpeechToText _speech = SpeechToText();

  bool _initialised = false;

  /// Set when initialisation has already been tried and failed, so a
  /// second tap doesn't re-run the whole permission dance to reach the
  /// same answer.
  bool _unavailable = false;

  bool get isListening => _speech.isListening;

  /// True once the platform has confirmed a recogniser and permission.
  Future<bool> _ensureReady({required void Function(String) onError}) async {
    if (_initialised) return true;
    if (_unavailable) return false;

    try {
      _initialised = await _speech.initialize(
        // The plugin reports transient trouble here as well as fatal
        // trouble, so errors are surfaced to the caller rather than
        // being treated as the end of the session.
        onError: (e) {
          debugPrint('Speech error: ${e.errorMsg} (permanent: ${e.permanent})');
          if (e.permanent) onError(_describe(e.errorMsg));
        },
        onStatus: (status) => debugPrint('Speech status: $status'),
      );
    } catch (e) {
      debugPrint('Speech initialise threw: $e');
      _initialised = false;
    }

    if (!_initialised) {
      _unavailable = true;
      onError(
        'Voice input is not available on this device. You can still type '
        'your question.',
      );
    }
    return _initialised;
  }

  /// Starts listening, streaming text back as it is recognised.
  ///
  /// [onText] fires repeatedly with the best transcription so far, so the
  /// field fills in as the user speaks rather than sitting empty until
  /// they stop. [onDone] fires when the platform closes the session,
  /// whether because the user stopped it, they fell silent, or the time
  /// limit ran out — the caller uses it to put the button back.
  Future<void> start({
    required void Function(String text) onText,
    required VoidCallback onDone,
    required void Function(String message) onError,
  }) async {
    if (!await _ensureReady(onError: onError)) {
      onDone();
      return;
    }

    try {
      await _speech.listen(
        onResult: (result) => onText(result.recognizedWords),
        listenOptions: SpeechListenOptions(
          partialResults: true,
          // Dictation, not a command: the transcript should be punctuated
          // and readable rather than a bare keyword.
          listenMode: ListenMode.dictation,
          cancelOnError: true,
        ),
        // A question to a meditation guide is a sentence or two. A long
        // ceiling here mostly means a forgotten open microphone.
        listenFor: const Duration(seconds: 45),
        // How long a pause ends the sentence. Three seconds is
        // deliberately generous — people pause mid-thought when they are
        // describing how they feel, and cutting them off at the default
        // makes the feature feel impatient.
        pauseFor: const Duration(seconds: 3),
      );
    } catch (e) {
      debugPrint('Speech listen failed: $e');
      onError('Could not start listening. Please try again.');
      onDone();
    }
  }

  Future<void> stop() async {
    try {
      await _speech.stop();
    } catch (e) {
      debugPrint('Speech stop failed: $e');
    }
  }

  /// Called when the screen goes away mid-sentence. cancel() rather than
  /// stop(), because a half-finished transcript has nowhere to be
  /// delivered once the field it was filling is gone.
  Future<void> dispose() async {
    try {
      if (_speech.isListening) await _speech.cancel();
    } catch (e) {
      debugPrint('Speech cancel failed: $e');
    }
  }

  /// Turns the platform's error codes into something worth reading.
  String _describe(String code) {
    if (code.contains('permission') || code.contains('denied')) {
      return 'Microphone access is off. Turn it on in your phone settings '
          'to speak your question.';
    }
    if (code.contains('network')) {
      return 'Voice input needs a connection right now. Try typing instead.';
    }
    if (code.contains('speech_timeout') || code.contains('no_match')) {
      return 'I did not catch that. Try again, or type your question.';
    }
    return 'Voice input stopped. You can try again or type your question.';
  }
}
