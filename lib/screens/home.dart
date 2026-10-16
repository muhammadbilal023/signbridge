import 'package:flutter/material.dart';
import '../data.dart';
import '../ui.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _i = 0;
  @override
  Widget build(BuildContext context) {
    const tabs = [HomeTab(), HistoryTab(), ProfileTab()];
    return Scaffold(
      body: Stack(children: [
        SafeArea(
          bottom: false,
          child: Centered(
              child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  switchInCurve: Curves.easeOutCubic,
                  child: KeyedSubtree(key: ValueKey(_i), child: tabs[_i]))),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 18,
          child: SafeArea(
            top: false,
            child: Center(
              child: GlassDock(
                index: _i,
                onChanged: (i) => setState(() => _i = i),
                items: const [
                  (Icons.home_rounded, 'Home'),
                  (Icons.history_rounded, 'History'),
                  (Icons.person_rounded, 'Profile')
                ],
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

class _Mini extends StatelessWidget {
  final IconData icon;
  final String title, sub;
  final Widget trailing;
  const _Mini(
      {required this.icon,
      required this.title,
      required this.sub,
      required this.trailing});
  @override
  Widget build(BuildContext context) => Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [Orb(icon, size: 44), const Spacer(), trailing]),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: h(17)),
              const SizedBox(height: 3),
              Text(sub, style: b(12.5)),
            ]),
          ]);
}

class _Stat extends StatelessWidget {
  final int value;
  final String label;
  const _Stat(this.value, this.label);
  @override
  Widget build(BuildContext context) => Glass(
      radius: 20,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CountUp(value, style: h(32)),
        const SizedBox(height: 2),
        Text(label, style: b(12)),
      ]));
}

class HomeTab extends StatelessWidget {
  const HomeTab({super.key});
  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 860;
    void go(String r) => Navigator.pushNamed(context, r);
    Widget tile(Widget c) =>
        wide ? Expanded(child: c) : SizedBox(height: 128, child: c);

    final hero = SpotlightCard(
      beam: true,
      radius: 28,
      padding: const EdgeInsets.all(18),
      onTap: () => go('/sign-to-text'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Pill(text: 'Sign → Text', icon: Icons.sign_language, hi: true),
          Spacer(),
          Icon(Icons.north_east_rounded, color: C.muted, size: 20)
        ]),
        const SizedBox(height: 12),
        const Expanded(child: CameraPanel(active: true)),
        const SizedBox(height: 14),
        Text('Sign it. It speaks.', style: h(22)),
        const SizedBox(height: 4),
        Text('Hand tracking turns signs into text and voice.', style: b(13)),
      ]),
    );
    final textCard = SpotlightCard(
        onTap: () => go('/text-to-sign'),
        child: const _Mini(
            icon: Icons.record_voice_over_rounded,
            title: 'Text → Sign',
            sub: 'Type or speak, watch the clips',
            trailing: SizedBox(width: 72, height: 26, child: Waveform())));
    final liveCard = SpotlightCard(
        onTap: () => go('/live'),
        child: _Mini(
            icon: Icons.video_call_rounded,
            title: 'Live Session',
            sub: 'One-to-one with captions + mood',
            trailing: Row(children: [
              const PulseDot(size: 7),
              Text('Ready', style: b(12, color: C.mint, w: FontWeight.w700))
            ])));

    final top = wide
        ? SizedBox(
            height: 400,
            child:
                Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(flex: 6, child: hero),
              const SizedBox(width: 16),
              Expanded(
                  flex: 5,
                  child: Column(children: [
                    tile(textCard),
                    const SizedBox(height: 16),
                    tile(liveCard)
                  ])),
            ]))
        : Column(children: [
            SizedBox(height: 380, child: hero),
            const SizedBox(height: 12),
            tile(textCard),
            const SizedBox(height: 12),
            tile(liveCard)
          ]);

    final half = kSigns.length ~/ 2;
    final vocab = SpotlightCard(
      radius: 24,
      padding: const EdgeInsets.symmetric(vertical: 18),
      onTap: () => go('/help'),
      child: Column(children: [
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(children: [
              Text('Vocabulary', style: h(18)),
              const Spacer(),
              Text('${kSigns.length} demo signs', style: b(12.5))
            ])),
        const SizedBox(height: 14),
        fadeEdges(SizedBox(
            height: 34,
            child: Marquee(children: [
              for (final s in kSigns.sublist(0, half))
                Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Pill(text: s))
            ]))),
        const SizedBox(height: 10),
        fadeEdges(SizedBox(
            height: 34,
            child: Marquee(reverse: true, children: [
              for (final s in kSigns.sublist(half))
                Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Pill(text: s))
            ]))),
      ]),
    );

    return LenisScroll(
      builder: (ctx, ctrl, physics) => ListView(
        controller: ctrl,
        physics: physics,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 130),
        children: [
          const Row(children: [ProtoBadge(), Spacer(), SizedBox.shrink()]),
          const SizedBox(height: 14),
          Text('Welcome back', style: b(14, w: FontWeight.w600)),
          const SizedBox(height: 4),
          RevealText("Let's bridge a conversation.", style: h(wide ? 38 : 30)),
          const SizedBox(height: 20),
          FadeIn(delay: 150, child: top),
          const SizedBox(height: 16),
          FadeIn(delay: 300, child: vocab),
          const SizedBox(height: 16),
          const FadeIn(
              delay: 400,
              child: Row(children: [
                Expanded(child: _Stat(25, 'Demo signs')),
                SizedBox(width: 12),
                Expanded(child: _Stat(4, 'Core modules')),
                SizedBox(width: 12),
                Expanded(child: _Stat(2, 'Platforms'))
              ])),
          const SizedBox(height: 24),
          Text('Recent activity', style: h(18)),
          const SizedBox(height: 12),
          for (final item in kHistory.take(3))
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SpotlightCard(
                radius: 20,
                child: Row(children: [
                  Orb(iconFor(item.type), size: 42),
                  const SizedBox(width: 14),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(item.title,
                            style: b(14.5, color: C.text, w: FontWeight.w700)),
                        Text(item.date, style: b(12))
                      ])),
                  const Icon(Icons.chevron_right_rounded, color: C.muted),
                ]),
              ),
            ),
        ],
      ),
    );
  }
}

class HistoryTab extends StatefulWidget {
  const HistoryTab({super.key});
  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  String _f = 'All';

  void _detail(HistoryItem it) => showModalBottomSheet(
        context: context,
        builder: (_) => Padding(
          padding: const EdgeInsets.all(12),
          child: Glass(
            radius: 28,
            blur: true,
            padding: const EdgeInsets.all(24),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Pill(text: it.type, icon: iconFor(it.type), hi: true),
                  const SizedBox(height: 14),
                  Text(it.title, style: h(22)),
                  const SizedBox(height: 8),
                  Text(it.detail, style: b(14.5)),
                  const SizedBox(height: 4),
                  Text(it.date,
                      style: b(12.5, color: C.muted.withValues(alpha: .7))),
                  const SizedBox(height: 16),
                ]),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final items = kHistory.where((h) => _f == 'All' || h.type == _f).toList();
    return LenisScroll(
      builder: (ctx, ctrl, physics) => ListView(
        controller: ctrl,
        physics: physics,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 130),
        children: [
          Text('History', style: h(34)),
          const SizedBox(height: 4),
          Text('Everything you translated or talked about.', style: b(14)),
          const SizedBox(height: 18),
          PillTabs(
              options: kFilters,
              selected: _f,
              onChanged: (v) => setState(() => _f = v)),
          const SizedBox(height: 18),
          if (items.isEmpty)
            Padding(
                padding: const EdgeInsets.all(40),
                child: Center(child: Text('Nothing here yet', style: b(14)))),
          for (var i = 0; i < items.length; i++)
            FadeIn(
              key: ValueKey('${_f}_$i'),
              delay: i * 60,
              dy: 12,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SpotlightCard(
                  radius: 22,
                  onTap: () => _detail(items[i]),
                  child: Row(children: [
                    Orb(iconFor(items[i].type)),
                    const SizedBox(width: 14),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(items[i].title,
                              style: b(15, color: C.text, w: FontWeight.w700)),
                          const SizedBox(height: 2),
                          Text('${items[i].type} • ${items[i].date}',
                              style: b(12.5)),
                        ])),
                    const Icon(Icons.chevron_right_rounded, color: C.muted),
                  ]),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});
  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  bool _captions = true, _emotion = true, _contrast = false;
  String _lang = 'English';
  double _speed = .5;

  Widget _row(IconData i, String t, Widget trailing) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Icon(i, color: C.muted, size: 22),
        const SizedBox(width: 14),
        Expanded(
            child: Text(t, style: b(14.5, color: C.text, w: FontWeight.w600))),
        trailing
      ]));

  @override
  Widget build(BuildContext context) => LenisScroll(
        builder: (ctx, ctrl, physics) => ListView(
          controller: ctrl,
          physics: physics,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 130),
          children: [
            Text('Profile', style: h(34)),
            const SizedBox(height: 22),
            Center(
              child: Column(children: [
                BorderBeam(
                    radius: 52,
                    child: Container(
                        width: 104,
                        height: 104,
                        padding: const EdgeInsets.all(6),
                        child: Container(
                            decoration: const BoxDecoration(
                                shape: BoxShape.circle, gradient: kGrad),
                            child: const Icon(Icons.person_rounded,
                                size: 50, color: C.ink)))),
                const SizedBox(height: 14),
                Text('Demo User', style: h(22)),
                const SizedBox(height: 2),
                Text('demo@signbridge.app', style: b(13.5)),
              ]),
            ),
            const SizedBox(height: 24),
            Glass(
              radius: 24,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              child: Column(children: [
                _row(
                    Icons.closed_caption_rounded,
                    'Live captions',
                    Switch(
                        value: _captions,
                        onChanged: (v) => setState(() => _captions = v))),
                _row(
                    Icons.mood_rounded,
                    'Emotion indicator',
                    Switch(
                        value: _emotion,
                        onChanged: (v) => setState(() => _emotion = v))),
                _row(
                    Icons.contrast_rounded,
                    'High-contrast captions',
                    Switch(
                        value: _contrast,
                        onChanged: (v) => setState(() => _contrast = v))),
                _row(
                    Icons.speed_rounded,
                    'Speech speed',
                    SizedBox(
                        width: 150,
                        child: Slider(
                            value: _speed,
                            onChanged: (v) => setState(() => _speed = v)))),
              ]),
            ),
            const SizedBox(height: 14),
            Glass(
              radius: 24,
              padding: const EdgeInsets.all(18),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.language_rounded,
                          color: C.muted, size: 22),
                      const SizedBox(width: 14),
                      Text('Language',
                          style: b(14.5, color: C.text, w: FontWeight.w600))
                    ]),
                    const SizedBox(height: 12),
                    PillTabs(
                        options: const ['English', 'Urdu'],
                        selected: _lang,
                        onChanged: (v) => setState(() => _lang = v)),
                  ]),
            ),
            const SizedBox(height: 14),
            SpotlightCard(
                radius: 24,
                onTap: () => Navigator.pushNamed(context, '/help'),
                child: _row(Icons.info_outline_rounded, 'Help & About',
                    const Icon(Icons.chevron_right_rounded, color: C.muted))),
            const SizedBox(height: 20),
            GlowButton(
                label: 'Log out',
                icon: Icons.logout_rounded,
                secondary: true,
                onTap: () => Navigator.pushNamedAndRemoveUntil(
                    context, '/login', (_) => false)),
          ],
        ),
      );
}
