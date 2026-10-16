import 'dart:async';
import 'package:flutter/material.dart';
import '../ui.dart';

class LiveLobbyScreen extends StatefulWidget {
  const LiveLobbyScreen({super.key});
  @override
  State<LiveLobbyScreen> createState() => _LiveLobbyScreenState();
}

class _LiveLobbyScreenState extends State<LiveLobbyScreen> {
  final _join = TextEditingController();
  static const _code = 'SB-4821';

  void _start(String code) => Navigator.push(
      context, MaterialPageRoute(builder: (_) => LiveCallScreen(code: code)));

  @override
  void dispose() {
    _join.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Centered(
            maxWidth: 560,
            child: LenisScroll(
              builder: (ctx, ctrl, physics) => ListView(
                controller: ctrl,
                physics: physics,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                children: [
                  const TopBar(title: 'Live Session'),
                  FadeIn(
                    child: BorderBeam(
                      radius: 28,
                      child: Glass(
                        radius: 28,
                        blur: true,
                        padding: const EdgeInsets.all(24),
                        child: Column(children: [
                          const Pill(
                              text: 'New session',
                              icon: Icons.bolt_rounded,
                              hi: true),
                          const SizedBox(height: 16),
                          Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(18)),
                              child: const Icon(Icons.qr_code_2,
                                  size: 140, color: Colors.black)),
                          const SizedBox(height: 14),
                          Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                GradientText(_code,
                                    style: h(40).copyWith(letterSpacing: 3)),
                                const SizedBox(width: 6),
                                IconButton(
                                    icon: const Icon(Icons.copy_rounded,
                                        color: C.muted),
                                    onPressed: () => ScaffoldMessenger.of(
                                            context)
                                        .showSnackBar(const SnackBar(
                                            content:
                                                Text('Code copied (mock)')))),
                              ]),
                          Text('Share this code or QR with the other person',
                              style: b(13), textAlign: TextAlign.center),
                          const SizedBox(height: 20),
                          GlowButton(
                              label: 'Start session',
                              icon: Icons.video_call_rounded,
                              onTap: () => _start(_code)),
                        ]),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FadeIn(
                    delay: 150,
                    child: Glass(
                      radius: 24,
                      padding: const EdgeInsets.all(20),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Join with a code', style: h(18)),
                            const SizedBox(height: 14),
                            TextField(
                                controller: _join,
                                textCapitalization:
                                    TextCapitalization.characters,
                                style: b(16, color: C.text, w: FontWeight.w700),
                                decoration: const InputDecoration(
                                    labelText: 'Session code',
                                    hintText: 'SB-4821',
                                    prefixIcon: Icon(Icons.tag_rounded))),
                            const SizedBox(height: 14),
                            GlowButton(
                                label: 'Join session',
                                secondary: true,
                                onTap: () => _start(_join.text.trim().isEmpty
                                    ? _code
                                    : _join.text.trim())),
                          ]),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Center(child: ProtoBadge()),
                ],
              ),
            ),
          ),
        ),
      );
}

class LiveCallScreen extends StatefulWidget {
  final String code;
  const LiveCallScreen({super.key, required this.code});
  @override
  State<LiveCallScreen> createState() => _LiveCallScreenState();
}

class _LiveCallScreenState extends State<LiveCallScreen> {
  Timer? _t;
  int _secs = 0, _n = 0;
  bool _mic = true, _cam = true, _sign = true;
  String _emo = 'Neutral';
  final List<String> _caps = ['Session started'];
  static const _lines = [
    'Hello, how are you?',
    'I need help with my account.',
    'Please wait one moment.',
    'Thank you very much.'
  ];
  static const _emos = ['Neutral', 'Happy', 'Confused', 'Happy'];
  static const _emoIcon = {
    'Neutral': Icons.sentiment_neutral_rounded,
    'Happy': Icons.sentiment_satisfied_alt_rounded,
    'Confused': Icons.sentiment_dissatisfied_rounded
  };
  static const _emoColor = {
    'Neutral': C.blue,
    'Happy': C.mint,
    'Confused': C.amber
  };

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _secs++;
        if (_secs % 3 == 0) {
          _caps.add(_lines[_n % _lines.length]);
          _emo = _emos[_n % _emos.length];
          _n++;
          if (_caps.length > 3) _caps.removeAt(0);
        }
      });
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  String get _time =>
      '${(_secs ~/ 60).toString().padLeft(2, '0')}:${(_secs % 60).toString().padLeft(2, '0')}';

  void _chat() => showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _ChatSheet());

  @override
  Widget build(BuildContext context) {
    final ec = _emoColor[_emo]!;
    return Scaffold(
      body: SafeArea(
        child: Centered(
          maxWidth: 900,
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Row(children: [
                const PulseDot(color: Color(0xFFFF4D6A), size: 7),
                Text('${widget.code}  •  $_time',
                    style: b(14, color: C.text, w: FontWeight.w700)),
                const Spacer(),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  child: Container(
                    key: ValueKey(_emo),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: ec.withValues(alpha: .15),
                        border: Border.all(color: ec.withValues(alpha: .5))),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(_emoIcon[_emo], size: 18, color: ec),
                      const SizedBox(width: 6),
                      Text('Mood: $_emo',
                          style: b(12.5, color: C.text, w: FontWeight.w700))
                    ]),
                  ),
                ),
              ]),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Stack(children: [
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                C.blue.withValues(alpha: .14),
                                C.teal.withValues(alpha: .06)
                              ]),
                          border: Border.all(color: const Color(0xFFE6DED2))),
                      child: Center(
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                        const SizedBox(
                            width: 240,
                            height: 240,
                            child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Ripples(size: 240),
                                  Orb(Icons.person_rounded, size: 96)
                                ])),
                        Text('Remote participant (mock)', style: b(13)),
                      ])),
                    ),
                  ),
                  Positioned(
                    top: 14,
                    right: 14,
                    child: Glass(
                        radius: 18,
                        blur: true,
                        padding: EdgeInsets.zero,
                        child: SizedBox(
                            width: 96,
                            height: 128,
                            child: Icon(
                                _cam
                                    ? Icons.person_outline_rounded
                                    : Icons.videocam_off_rounded,
                                color: C.muted,
                                size: 36))),
                  ),
                  Positioned(
                    left: 14,
                    right: 14,
                    bottom: 14,
                    child: Glass(
                      radius: 22,
                      blur: true,
                      padding: const EdgeInsets.all(16),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                _sign
                                    ? 'LIVE CAPTIONS + SIGN TRANSLATION'
                                    : 'LIVE CAPTIONS',
                                style:
                                    b(10.5, color: C.teal, w: FontWeight.w800)),
                            const SizedBox(height: 8),
                            for (var i = 0; i < _caps.length - 1; i++)
                              Text(_caps[i],
                                  style: b(13.5,
                                      color: C.muted.withValues(alpha: .7))),
                            RevealText(_caps.last,
                                key:
                                    ValueKey('${_caps.length}${_caps.last}$_n'),
                                style:
                                    b(17, color: C.text, w: FontWeight.w700)),
                          ]),
                    ),
                  ),
                ]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Glass(
                radius: 34,
                blur: true,
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      RoundBtn(
                          icon:
                              _mic ? Icons.mic_rounded : Icons.mic_off_rounded,
                          danger: !_mic,
                          onTap: () => setState(() => _mic = !_mic)),
                      RoundBtn(
                          icon: _cam
                              ? Icons.videocam_rounded
                              : Icons.videocam_off_rounded,
                          danger: !_cam,
                          onTap: () => setState(() => _cam = !_cam)),
                      RoundBtn(
                          icon: Icons.sign_language,
                          active: _sign,
                          onTap: () => setState(() => _sign = !_sign)),
                      RoundBtn(
                          icon: Icons.chat_bubble_outline_rounded,
                          onTap: _chat),
                      RoundBtn(
                          icon: Icons.call_end_rounded,
                          danger: true,
                          onTap: () => Navigator.pop(context)),
                    ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _ChatSheet extends StatefulWidget {
  const _ChatSheet();
  @override
  State<_ChatSheet> createState() => _ChatSheetState();
}

class _ChatSheetState extends State<_ChatSheet> {
  final _c = TextEditingController();
  final List<(String, bool)> _msgs = [
    ('Hello! Can you see me?', false),
    ('Yes, clearly.', true)
  ];

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _send() {
    if (_c.text.trim().isEmpty) return;
    setState(() => _msgs.add((_c.text.trim(), true)));
    _c.clear();
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(
            12, 12, 12, 12 + MediaQuery.of(context).viewInsets.bottom),
        child: Glass(
          radius: 28,
          blur: true,
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            height: 340,
            child: Column(children: [
              Text('Chat', style: h(18)),
              const SizedBox(height: 10),
              Expanded(
                child: ListView(
                    children: _msgs
                        .map((m) => Align(
                              alignment: m.$2
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: Container(
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    gradient: m.$2 ? kGrad : null,
                                    color:
                                        m.$2 ? null : const Color(0xFFF1ECE3)),
                                child: Text(m.$1,
                                    style: b(14,
                                        color: m.$2 ? C.ink : C.text,
                                        w: FontWeight.w600)),
                              ),
                            ))
                        .toList()),
              ),
              Row(children: [
                Expanded(
                    child: TextField(
                        controller: _c,
                        onSubmitted: (_) => _send(),
                        decoration:
                            const InputDecoration(hintText: 'Type a message'))),
                const SizedBox(width: 10),
                RoundBtn(
                    icon: Icons.send_rounded,
                    active: true,
                    size: 48,
                    onTap: _send),
              ]),
            ]),
          ),
        ),
      );
}
