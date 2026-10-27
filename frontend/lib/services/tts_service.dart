// One shared text-to-speech voice for the whole app.
// Uses flutter_tts, which works on Web (Chrome/Edge/Safari) and Android.
// Call Speak.I.word('Hello') or Speak.I.sentence('...') from any screen.
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../services/api.dart';

class Speak {
  Speak._();
  static final Speak I = Speak._();

  final FlutterTts _tts = FlutterTts();
  bool _ready = false;

  Future<void> _ensure() async {
    if (_ready) return;
    try {
      await _tts.awaitSpeakCompletion(true);
      await _tts.setSpeechRate(0.45);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      _ready = true;
    } catch (e) {
      debugPrint('TTS init failed: $e');
    }
  }

  Future<void> _lang() async {
    // Match the user's profile language. Urdu falls back to English on
    // platforms where the Urdu voice is not installed.
    final want = Api.I.language == 'ur' ? 'ur-PK' : 'en-US';
    try {
      final ok = await _tts.setLanguage(want);
      if (ok != true && want == 'ur-PK') await _tts.setLanguage('en-US');
    } catch (_) {
      try {
        await _tts.setLanguage('en-US');
      } catch (_) {}
    }
  }

  /// Speak a single vocabulary word. Cancels any previous utterance first.
  Future<void> word(String text) async {
    final t = text.trim();
    if (t.isEmpty) return;
    await _ensure();
    try {
      await _tts.stop();
    } catch (_) {}
    await _lang();
    try {
      await _tts.speak(t);
    } catch (e) {
      debugPrint('TTS speak failed: $e');
    }
  }

  /// Speak a whole sentence (same as [word], kept separate for readability at call sites).
  Future<void> sentence(String text) => word(text);

  Future<void> stop() async {
    if (!_ready) return;
    try {
      await _tts.stop();
    } catch (_) {}
  }
}
