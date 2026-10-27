import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../services/api.dart';
import '../services/sign_camera.dart';
import '../ui.dart';

const _links = [
  [0, 1], [1, 2], [2, 3], [3, 4], [0, 5], [5, 6], [6, 7], [7, 8], [5, 9], [9, 10], [10, 11], [11, 12],
  [9, 13], [13, 14], [14, 15], [15, 16], [13, 17], [17, 18], [18, 19], [19, 20], [0, 17],
];
const _dark = Color(0xFF16284A);

class SignToTextScreen extends StatefulWidget {
  const SignToTextScreen({super.key});
  @override
  State<SignToTextScreen> createState() => _SignToTextScreenState();
}

class _SignToTextScreenState extends State<SignToTextScreen> {
  SignCamera? _cam;
  WebSocketChannel? _ws;
  StreamSubscription? _sub;
  final FlutterTts _tts = FlutterTts();

  bool _on = false, _starting = false, _mirror = true, _autoSpeak = true;
  String? _error;
  String _mode = '', _note = '', _sentence = '';
  final List<String> _words = [];
  List<Offset> _left = [], _right = [];

  // ---------------- start / stop ----------------
  Future<void> _start() async {
    if (Api.I.token == null) {
      setState(() => _error = 'Please sign in again.');
      return;
    }
    setState(() {
      _starting = true;
      _error = null;
      _note = '';
    });
    try {
      // Camera via the platform-specific SignCamera (web: dart:html, Android: flutter_webrtc)
      _cam = createSignCamera();
      await _cam!.start();

      // WebSocket to backend
      final ws = WebSocketChannel.connect(Uri.parse('${Api.I.wsUrl('/ws/sign')}?token=${Api.I.token}&lang=${Api.I.language}'));
      try {
        await ws.ready;
      } catch (_) {
        await _stopCamera();
        throw 'Cannot reach the server at ${Api.baseUrl}. Is the backend running?';
      }
      _sub = ws.stream.listen(_onMessage, onError: (_) => _stop(error: 'Lost the connection to the server.'), onDone: () {
        if (_on) _stop(error: 'The server closed the connection.');
      });
      if (!mounted) return;
      setState(() {
        _ws = ws;
        _on = true;
        _words.clear();
        _sentence = '';
      });
      _loop();
    } catch (e) {
      if (mounted) setState(() => _error = 'Camera problem: $e. Allow camera access for this site and try again.');
      await _stopCamera();
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<void> _stopCamera() async {
    await _cam?.stop();
    _cam = null;
  }

  Future<void> _stop({String? error}) async {
    _on = false;
    await _sub?.cancel();
    _sub = null;
    try {
      await _ws?.sink.close();
    } catch (_) {}
    _ws = null;
    await _stopCamera();
    if (mounted) {
      setState(() {
        _left = [];
        _right = [];
        if (error != null) _error = error;
      });
    }
  }

  /// Captures a JPEG frame from the live preview ~5 times/second.
  Future<Uint8List?> _captureFrame() async {
    final c = _cam;
    if (c == null) return null;
    return c.capture();
  }

  Future<void> _loop() async {
    while (mounted && _on && _ws != null) {
      final t0 = DateTime.now();
      try {
        final bytes = await _captureFrame();
        if (bytes != null && _on) _ws?.sink.add(bytes);
      } catch (_) {/* skip frame */}
      final wait = 190 - DateTime.now().difference(t0).inMilliseconds;
      if (wait > 0) await Future.delayed(Duration(milliseconds: wait));
    }
  }

  // ---------------- server messages ----------------
  List<Offset> _hand(List pts, int from) {
    var any = false;
    final out = <Offset>[];
    for (var i = 0; i < 21; i++) {
      final x = (pts[from + i * 3] as num).toDouble(), y = (pts[from + i * 3 + 1] as num).toDouble();
      if (x != 0 || y != 0) any = true;
      out.add(Offset(x, y));
    }
    return any ? out : [];
  }

  void _onMessage(dynamic raw) {
    if (raw is! String || !mounted) return;
    final m = jsonDecode(raw) as Map<String, dynamic>;
    switch (m['type']) {
      case 'ready':
        setState(() => _mode = (m['mode'] as String?) ?? '');
        break;
      case 'hands':
        final p = m['points'] as List;
        setState(() {
          _left = _hand(p, 0);
          _right = _hand(p, 63);
        });
        break;
      case 'word':
        setState(() {
          _words.add(m['word'] as String);
          _note = '${m['word']}  ${(((m['confidence'] as num) * 100).round())}%';
        });
        break;
      case 'uncertain':
        setState(() => _note = 'Not sure (${m['best']}, ${(((m['confidence'] as num) * 100).round())}%)');
        break;
      case 'sentence':
        final s = (m['sentence'] as String?) ?? '';
        if (s.isEmpty) break;
        setState(() {
          _sentence = s;
          _words.clear();
        });
        if (_autoSpeak) _speak(s);
        break;
      case 'error':
        setState(() => _error = m['message'] as String?);
        break;
    }
  }

  Future<void> _speak(String text) async {
    try {
      await _tts.setLanguage(Api.I.language == 'ur' ? 'ur-PK' : 'en-US');
      await _tts.speak(text);
    } catch (_) {}
  }

  void _send(String type) => _ws?.sink.add(jsonEncode({'type': type}));

  @override
  void dispose() {
    _on = false;
    _sub?.cancel();
    _ws?.sink.close();
    _stopCamera();
    _tts.stop();
    super.dispose();
  }

  // ---------------- UI ----------------
  Widget _cameraArea() {
    if (!_on || _cam == null) {
      return AspectRatio(
        aspectRatio: 4 / 3,
        child: Container(
          decoration: BoxDecoration(color: _dark, borderRadius: BorderRadius.circular(22)),
          child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.videocam_off_rounded, color: Colors.white54, size: 48),
            const SizedBox(height: 8),
            Text(_starting ? 'Starting camera...' : 'Camera is off', style: b(14, color: Colors.white70)),
          ])),
        ),
      );
    }
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 460),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: AspectRatio(
            aspectRatio: 4 / 3,
            child: Stack(fit: StackFit.expand, children: [
              _cam!.buildView(mirror: _mirror),
              CustomPaint(painter: _HandsPainter(_left, _right, _mirror)),
              Positioned(left: 12, top: 12, child: Row(children: [const PulseDot(color: Color(0xFFFF4D6A), size: 7), Text('LIVE', style: b(11, color: Colors.white, w: FontWeight.w800))])),
              if (_note.isNotEmpty)
                Positioned(left: 12, bottom: 12, child: Glass(radius: 14, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), child: Text(_note, style: b(13, color: C.text, w: FontWeight.w700)))),
            ]),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Centered(
            maxWidth: 760,
            child: LenisScroll(
              builder: (ctx, ctrl, physics) => ListView(
                controller: ctrl,
                physics: physics,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                children: [
                  const TopBar(title: 'Sign → Text & Speech'),
                  if (_mode == 'demo')
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Glass(
                          radius: 16,
                          padding: const EdgeInsets.all(12),
                          child: Text('Demo mode: the camera and hand tracking are real, but the sign-recognition model is not installed on the server yet, so the words below are placeholders.',
                              style: b(12.5, color: C.amber, w: FontWeight.w600))),
                    ),
                  if (_error != null)
                    Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(_error!, textAlign: TextAlign.center, style: b(13, color: const Color(0xFFC0392B), w: FontWeight.w600))),
                  FadeIn(child: _cameraArea()),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: _toggle('Mirror hands', _mirror, (v) => setState(() => _mirror = v))),
                    const SizedBox(width: 12),
                    Expanded(child: _toggle('Speak sentences', _autoSpeak, (v) => setState(() => _autoSpeak = v))),
                  ]),
                  const SizedBox(height: 12),
                  FadeIn(
                      delay: 100,
                      child: GlowButton(
                          label: _starting ? 'Starting...' : (_on ? 'Stop camera' : 'Start camera'),
                          icon: _on ? Icons.stop_rounded : Icons.videocam_rounded,
                          onTap: _starting ? null : (_on ? () => _stop() : _start))),
                  const SizedBox(height: 16),
                  FadeIn(
                    delay: 200,
                    child: Glass(
                      radius: 24,
                      padding: const EdgeInsets.all(18),
                      child: SizedBox(
                        width: double.infinity,
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('WORDS', style: b(11, color: C.blue, w: FontWeight.w800)),
                          const SizedBox(height: 10),
                          if (_words.isEmpty)
                            Text('Sign one word, pause a moment, then sign the next.', style: b(15))
                          else
                            Wrap(spacing: 8, runSpacing: 8, children: [
                              for (var i = 0; i < _words.length; i++)
                                FadeIn(
                                    key: ValueKey('w$i${_words[i]}'),
                                    dy: 8,
                                    child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), color: C.blue.withValues(alpha: .08), border: Border.all(color: C.blue.withValues(alpha: .3))),
                                        child: Text(_words[i], style: b(16, color: C.text, w: FontWeight.w700)))),
                            ]),
                          const SizedBox(height: 16),
                          Text('SENTENCE', style: b(11, color: C.blue, w: FontWeight.w800)),
                          const SizedBox(height: 8),
                          Text(_sentence.isEmpty ? 'Appears when you lower your hands for a moment.' : _sentence, style: _sentence.isEmpty ? b(15) : h(24)),
                        ]),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: GlowButton(label: 'Finish', icon: Icons.check_rounded, secondary: true, onTap: _on ? () => _send('finish') : null)),
                    const SizedBox(width: 10),
                    Expanded(child: GlowButton(label: 'Speak', icon: Icons.volume_up_rounded, secondary: true, onTap: _sentence.isEmpty ? null : () => _speak(_sentence))),
                    const SizedBox(width: 10),
                    Expanded(
                        child: GlowButton(
                            label: 'Clear',
                            icon: Icons.delete_outline_rounded,
                            secondary: true,
                            onTap: () {
                              _send('reset');
                              setState(() {
                                _words.clear();
                                _sentence = '';
                                _note = '';
                              });
                            })),
                  ]),
                ],
              ),
            ),
          ),
        ),
      );

  Widget _toggle(String label, bool value, ValueChanged<bool> onChanged) => Glass(
        radius: 16,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(children: [
          Expanded(child: Text(label, style: b(12.5, color: C.text, w: FontWeight.w700))),
          Switch(value: value, onChanged: onChanged),
        ]),
      );
}

class _HandsPainter extends CustomPainter {
  final List<Offset> left, right;
  final bool mirror;
  _HandsPainter(this.left, this.right, this.mirror);

  @override
  void paint(Canvas canvas, Size size) {
    for (final hand in [left, right]) {
      if (hand.length != 21) continue;
      final pts = [for (final p in hand) Offset((mirror ? 1 - p.dx : p.dx) * size.width, p.dy * size.height)];
      final line = Paint()
        ..color = const Color(0xFF7FD3A0)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      for (final l in _links) {
        canvas.drawLine(pts[l[0]], pts[l[1]], line);
      }
      final dot = Paint()..color = Colors.white;
      for (final p in pts) {
        canvas.drawCircle(p, 4, dot);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _HandsPainter old) => true;
}
