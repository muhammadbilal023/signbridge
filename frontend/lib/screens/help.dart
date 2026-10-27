import 'package:flutter/material.dart';
import '../data.dart';
import '../services/tts_service.dart';
import '../ui.dart';

class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});
  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  String _q = '';
  static const _faq = [
    ('How accurate is recognition?', 'Accuracy depends on lighting, camera quality and signer position. It works on a limited vocabulary of isolated signs.'),
    ('Does it support full sentences?', 'No. The system recognises individual signs, not continuous signing.'),
    ('Is my session private?', 'Live sessions are one-to-one and use a private session code.'),
  ];

  @override
  Widget build(BuildContext context) {
    final signs = kSigns.where((s) => s.toLowerCase().contains(_q.toLowerCase())).toList();
    return Scaffold(
      body: SafeArea(
        child: Centered(
          maxWidth: 760,
          child: LenisScroll(
            builder: (ctx, ctrl, physics) => ListView(
              controller: ctrl,
              physics: physics,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
              children: [
                const TopBar(title: 'Help & About'),
                FadeIn(
                  child: BorderBeam(
                    radius: 28,
                    child: Glass(
                      radius: 28,
                      blur: true,
                      padding: const EdgeInsets.all(24),
                      child: SizedBox(
                        width: double.infinity,
                        child: Column(children: [
                          const LogoMark(size: 64),
                          const SizedBox(height: 16),
                          GradientText('SignBridge', style: h(30)),
                          const SizedBox(height: 4),
                          Text('Bridging Silence. Connecting Lives.', style: b(14)),
                          const SizedBox(height: 12),
                          Text('AI-powered sign language communication platform for Web and Android.', textAlign: TextAlign.center, style: b(13.5)),
                          const SizedBox(height: 10),
                          const Pill(text: 'v0.3 • UI prototype'),
                        ]),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text('Supported signs', style: h(20)),
                const SizedBox(height: 4),
                Text('Sample list. The final vocabulary will have 40–60 signs.', style: b(13)),
                const SizedBox(height: 12),
                TextField(style: b(15, color: C.text), decoration: const InputDecoration(hintText: 'Search signs', prefixIcon: Icon(Icons.search_rounded)), onChanged: (v) => setState(() => _q = v)),
                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final s in signs)
                    Tooltip(
                      showDuration: const Duration(milliseconds: 1200),
                      message: 'Tap to hear "$s"',
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: () => Speak.I.word(s),
                          behavior: HitTestBehavior.opaque,
                          child: Pill(text: s, icon: Icons.volume_up_rounded, hi: _q.isNotEmpty),
                        ),
                      ),
                    ),
                ]),
                const SizedBox(height: 26),
                Text('FAQ', style: h(20)),
                const SizedBox(height: 12),
                for (final f in _faq)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Glass(
                      radius: 20,
                      padding: EdgeInsets.zero,
                      child: Theme(
                        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          iconColor: C.teal,
                          collapsedIconColor: C.muted,
                          tilePadding: const EdgeInsets.symmetric(horizontal: 18),
                          childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
                          shape: const Border(),
                          collapsedShape: const Border(),
                          title: Text(f.$1, style: b(14.5, color: C.text, w: FontWeight.w700)),
                          expandedAlignment: Alignment.centerLeft,
                          children: [Text(f.$2, style: b(13.5))],
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 10),
                const SizedBox.shrink(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
