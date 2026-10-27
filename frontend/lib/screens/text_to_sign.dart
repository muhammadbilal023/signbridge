import 'dart:async';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../data.dart';
import '../services/api.dart';
import '../services/tts_service.dart';
import '../ui.dart';

class TextToSignScreen extends StatefulWidget {
  const TextToSignScreen({super.key});
  @override
  State<TextToSignScreen> createState() => _TextToSignScreenState();
}

class _TextToSignScreenState extends State<TextToSignScreen> {
  final _c = TextEditingController();
  final List<(String, bool)> _items = [];
  Timer? _t, _mic;
  int _i = 0, _gen = 0;
  bool _playing = false, _listening = false;

  List<String> get _known => [for (final (w, k) in _items) if (k) w];

  bool _busy = false;
  String? _error;

  Future<void> _translate() async {
    _pause();
    final text = _c.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final r = await Api.I.textToSign(text); // backend maps the words to signs and saves it in History
      final out = <(String, bool)>[for (final p in (r['playlist'] as List)) (p['word'] as String, p['known'] as bool)];
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(out);
        _i = 0;
        _gen++;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _play() {
    if (_known.isEmpty) return;
    _t?.cancel();
    setState(() {
      _playing = true;
      _i = 0;
    });
    _t = Timer.periodic(const Duration(milliseconds: 1500), (t) {
      if (_i >= _known.length - 1) {
        t.cancel();
        setState(() => _playing = false);
      } else {
        setState(() => _i++);
      }
    });
  }

  void _pause() {
    _t?.cancel();
    if (_playing) setState(() => _playing = false);
  }

  final SpeechToText _stt = SpeechToText();
  bool _sttReady = false;

  /// Microphone -> text with the browser / phone speech recogniser (Urdu or English, from your profile language).
  Future<void> _listen() async {
    if (_listening) {
      await _stt.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }
    if (!_sttReady) {
      _sttReady = await _stt.initialize(
        onError: (e) {
          if (mounted) {
            setState(() {
              _listening = false;
              _error = 'Speech recognition: ${e.errorMsg}';
            });
          }
        },
        onStatus: (st) {
          if ((st == 'done' || st == 'notListening') && mounted && _listening) {
            setState(() => _listening = false);
            if (_c.text.trim().isNotEmpty) _translate();
          }
        },
      );
    }
    if (!_sttReady) {
      setState(() => _error = 'Speech recognition is not available. Use Chrome and allow the microphone (or check the app permission).');
      return;
    }
    setState(() {
      _listening = true;
      _error = null;
    });
    await _stt.listen(
      onResult: (r) {
        if (mounted) setState(() => _c.text = r.recognizedWords);
      },
      localeId: Api.I.language == 'ur' ? 'ur_PK' : 'en_US',
    );
  }

  @override
  void dispose() {
    _t?.cancel();
    _mic?.cancel();
    _stt.stop();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final known = _known;
    final word = known.isEmpty ? '' : known[_i.clamp(0, known.length - 1)];
    return Scaffold(
      body: SafeArea(
        child: Centered(
          maxWidth: 760,
          child: LenisScroll(
            builder: (ctx, ctrl, physics) => ListView(
              controller: ctrl,
              physics: physics,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
              children: [
                const TopBar(title: 'Speech / Text → Sign'),
                FadeIn(
                  child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                    Expanded(child: TextField(controller: _c, minLines: 2, maxLines: 3, style: b(16, color: C.text), decoration: const InputDecoration(labelText: 'Type a sentence'))),
                    const SizedBox(width: 10),
                    SizedBox(width: 76, height: 76, child: Stack(alignment: Alignment.center, children: [if (_listening) const Ripples(size: 76), RoundBtn(icon: Icons.mic_rounded, size: 52, active: _listening, onTap: _listen)])),
                  ]),
                ),
                const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 8, children: [for (final p in kPhrases) GestureDetector(onTap: () => _c.text = p, child: MouseRegion(cursor: SystemMouseCursors.click, child: Pill(text: p, icon: Icons.bolt_rounded)))]),
                const SizedBox(height: 16),
                GlowButton(label: _busy ? 'Translating...' : 'Translate to sign', icon: Icons.translate_rounded, onTap: _busy ? null : _translate),
                const SizedBox(height: 8),
                GlowButton(label: 'Speak sentence', icon: Icons.volume_up_rounded, secondary: true, onTap: _c.text.trim().isEmpty ? null : () => Speak.I.sentence(_c.text.trim())),
                if (_error != null)
                  Padding(padding: const EdgeInsets.only(top: 10), child: Text(_error!, textAlign: TextAlign.center, style: b(13, color: const Color(0xFFFF5D73), w: FontWeight.w600))),
                const SizedBox(height: 20),
                if (_items.isNotEmpty) ...[
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (var i = 0; i < _items.length; i++)
                      FadeIn(
                          key: ValueKey('$_gen-$i'),
                          delay: i * 70,
                          dy: 10,
                          child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => Speak.I.word(_items[i].$1),
                              child: Pill(text: _items[i].$1, icon: _items[i].$2 ? Icons.check_circle_rounded : Icons.text_fields_rounded, hi: _items[i].$2))),
                  ]),
                  const SizedBox(height: 6),
                  Text('Words without a sign clip are shown as text only.', style: b(12)),
                  const SizedBox(height: 14),
                  BorderBeam(
                    radius: 26,
                    child: Glass(
                      radius: 26,
                      padding: const EdgeInsets.all(20),
                      child: Column(children: [
                        SizedBox(
                          height: 190,
                          child: Stack(alignment: Alignment.center, children: [
                            Icon(Icons.sign_language, size: 150, color: C.text.withValues(alpha: .05)),
                            if (known.isEmpty)
                              Text('No matching sign clips', style: b(15))
                            else
                              Column(mainAxisSize: MainAxisSize.min, children: [
                                AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 350),
                                    transitionBuilder: (c, a) => FadeTransition(opacity: a, child: SlideTransition(position: Tween(begin: const Offset(0, .2), end: Offset.zero).animate(a), child: c)),
                                    child: GradientText(word, key: ValueKey(word), style: h(46))),
                                const SizedBox(height: 6),
                                Text('Sign clip (mock)', style: b(12)),
                              ]),
                          ]),
                        ),
                        if (known.isNotEmpty) ...[
                          Row(children: [
                            for (var k = 0; k < known.length; k++)
                              Expanded(child: AnimatedContainer(duration: const Duration(milliseconds: 300), height: 4, margin: const EdgeInsets.symmetric(horizontal: 2), decoration: BoxDecoration(borderRadius: BorderRadius.circular(4), gradient: k <= _i ? kGrad : null, color: k <= _i ? null : C.text.withValues(alpha: .12)))),
                          ]),
                          const SizedBox(height: 16),
                          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            RoundBtn(icon: Icons.skip_previous_rounded, onTap: () => setState(() => _i = (_i - 1).clamp(0, known.length - 1))),
                            const SizedBox(width: 16),
                            RoundBtn(icon: _playing ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 64, active: true, onTap: _playing ? _pause : _play),
                            const SizedBox(width: 16),
                            RoundBtn(icon: Icons.skip_next_rounded, onTap: () => setState(() => _i = (_i + 1).clamp(0, known.length - 1))),
                          ]),
                        ],
                      ]),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                const SizedBox.shrink(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
