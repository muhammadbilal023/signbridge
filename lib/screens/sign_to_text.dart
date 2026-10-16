import 'dart:async';
import 'package:flutter/material.dart';
import '../ui.dart';

class SignToTextScreen extends StatefulWidget {
  const SignToTextScreen({super.key});
  @override
  State<SignToTextScreen> createState() => _SignToTextScreenState();
}

class _SignToTextScreenState extends State<SignToTextScreen> {
  Timer? _t, _st;
  bool _on = false, _speaking = false;
  int _n = 0, _conf = 0;
  String _last = '';
  final List<String> _words = [];
  static const _demo = [
    ('Hello', 94),
    ('Help', 89),
    ('Water', 91),
    ('Doctor', 87),
    ('Thank you', 96)
  ];

  void _toggle() {
    setState(() => _on = !_on);
    _t?.cancel();
    if (_on) {
      _t = Timer.periodic(const Duration(seconds: 2), (_) {
        final d = _demo[_n++ % _demo.length];
        setState(() {
          _last = d.$1;
          _conf = d.$2;
          _words.add(d.$1);
        });
      });
    }
  }

  void _speak() {
    if (_words.isEmpty) return;
    setState(() => _speaking = true);
    _st?.cancel();
    _st = Timer(const Duration(milliseconds: 2400), () {
      if (mounted) setState(() => _speaking = false);
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    _st?.cancel();
    super.dispose();
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
                  FadeIn(
                      child: AspectRatio(
                          aspectRatio: 16 / 11,
                          child: CameraPanel(
                              active: _on,
                              caption: (_on && _last.isNotEmpty)
                                  ? '$_last • $_conf%'
                                  : null))),
                  const SizedBox(height: 16),
                  FadeIn(
                      delay: 100,
                      child: GlowButton(
                          label: _on ? 'Stop recognition' : 'Start recognition',
                          icon: _on
                              ? Icons.stop_rounded
                              : Icons.play_arrow_rounded,
                          onTap: _toggle)),
                  const SizedBox(height: 16),
                  FadeIn(
                    delay: 200,
                    child: Glass(
                      radius: 24,
                      padding: const EdgeInsets.all(18),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Text('TRANSCRIPT',
                                  style:
                                      b(11, color: C.teal, w: FontWeight.w800)),
                              const Spacer(),
                              SizedBox(
                                  width: 90,
                                  height: 22,
                                  child: Waveform(active: _speaking, bars: 16)),
                            ]),
                            const SizedBox(height: 14),
                            if (_words.isEmpty)
                              Text('Detected words will appear here…',
                                  style: b(17))
                            else
                              Wrap(spacing: 8, runSpacing: 8, children: [
                                for (var i = 0; i < _words.length; i++)
                                  FadeIn(
                                      key: ValueKey('w$i'),
                                      dy: 8,
                                      child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 14, vertical: 9),
                                          decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                              gradient: LinearGradient(colors: [
                                                C.blue.withValues(alpha: .28),
                                                C.teal.withValues(alpha: .2)
                                              ]),
                                              border: Border.all(
                                                  color: C.teal
                                                      .withValues(alpha: .4))),
                                          child: Text(_words[i],
                                              style: b(16,
                                                  color: C.text,
                                                  w: FontWeight.w700)))),
                              ]),
                          ]),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                        child: GlowButton(
                            label: 'Speak',
                            icon: Icons.volume_up_rounded,
                            secondary: true,
                            onTap: _words.isEmpty ? null : _speak)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: GlowButton(
                            label: 'Clear',
                            icon: Icons.delete_outline_rounded,
                            secondary: true,
                            onTap: () => setState(() {
                                  _words.clear();
                                  _last = '';
                                }))),
                  ]),
                  const SizedBox(height: 16),
                  const Center(child: ProtoBadge()),
                ],
              ),
            ),
          ),
        ),
      );
}
