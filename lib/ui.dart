// SignBridge design system.
// Flutter ports of effects inspired by Inspira UI (aurora background, border beam,
// card spotlight, marquee, text generate, dock, orbiting circles, number ticker,
// shimmer button), Animate UI (fade/slide reveals, spring press feedback)
// and Lenis (inertia smooth scroll).
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';

class C {
  static const bg = Color(0xFFF7F3EB);
  static const blue = Color(0xFF355C9A);
  static const teal = Color(0xFF7895B2);
  static const mint = Color(0xFFE6A08B);
  static const violet = Color(0xFFB6A7A0);
  static const amber = Color(0xFFB56D52);
  static const text = Color(0xFF242B32);
  static const muted = Color(0xFF74756F);
  static const ink = Color(0xFFFFFFFF);
}

const kGrad = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [C.blue, Color(0xFF5276A3)]);

TextStyle h(double s, {Color color = C.text, FontWeight w = FontWeight.w700}) =>
    GoogleFonts.dmSerifDisplay(
        fontSize: s,
        fontWeight: w,
        color: color,
        height: 1.12,
        letterSpacing: -s * .015);

TextStyle b(double s,
        {Color color = C.muted, FontWeight w = FontWeight.w500}) =>
    GoogleFonts.manrope(fontSize: s, color: color, fontWeight: w, height: 1.5);

// ───────────────────────── layout helpers ─────────────────────────
class Centered extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  const Centered({super.key, required this.child, this.maxWidth = 1100});
  @override
  Widget build(BuildContext context) => Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth), child: child));
}

class ProtoBadge extends StatelessWidget {
  const ProtoBadge({super.key});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
            color: C.amber.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: C.amber.withValues(alpha: .35))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.science_outlined, size: 12, color: C.amber),
          const SizedBox(width: 6),
          Text('Demo User', style: b(11, color: C.amber, w: FontWeight.w600)),
        ]),
      );
}

// ───────────────────────── background (Aurora) ─────────────────────────
class AuroraBackground extends StatefulWidget {
  final Widget child;
  const AuroraBackground({super.key, required this.child});
  @override
  State<AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends State<AuroraBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 26))
        ..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: C.bg,
        child: Stack(fit: StackFit.expand, children: [
          const RepaintBoundary(
            child: CustomPaint(painter: _DotsPainter()),
          ),
          RepaintBoundary(
            child: CustomPaint(
              painter: _AuroraPainter(_c),
            ),
          ),
          widget.child,
        ]),
      );
}

class _AuroraPainter extends CustomPainter {
  final Animation<double> a;
  _AuroraPainter(this.a) : super(repaint: a);
  @override
  void paint(Canvas canvas, Size size) {
    final t = a.value * 2 * math.pi;
    final w = size.width, h = size.height, m = math.max(w, h);
    void blob(Offset c, double r, Color col) => canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = RadialGradient(colors: [
            col.withValues(alpha: .36),
            col.withValues(alpha: 0)
          ]).createShader(Rect.fromCircle(center: c, radius: r)));
    blob(Offset(w * (.18 + .12 * math.sin(t)), h * (.12 + .10 * math.cos(t))),
        m * .55, C.blue);
    blob(
        Offset(
            w * (.88 + .08 * math.cos(t)), h * (.30 + .12 * math.sin(t + 1))),
        m * .48,
        C.teal);
    blob(
        Offset(
            w * (.50 + .16 * math.sin(t + 2)), h * (.98 + .05 * math.cos(t))),
        m * .55,
        C.violet);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _DotsPainter extends CustomPainter {
  const _DotsPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = const Color(0xFF8A8176).withValues(alpha: .09);
    for (double x = 0; x < size.width; x += 30) {
      for (double y = 0; y < size.height; y += 30) {
        canvas.drawCircle(Offset(x, y), 1, p);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ───────────────────────── glass / cards ─────────────────────────
class Glass extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final bool blur;
  const Glass(
      {super.key,
      required this.child,
      this.padding = const EdgeInsets.all(16),
      this.radius = 22,
      this.blur = false});
  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(radius);
    Widget w = Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: r,
        gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, Color(0xFFFCFAF6)]),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0C30271F), blurRadius: 22, offset: Offset(0, 8))
        ],
        border: Border.all(color: const Color(0xFFE6DED2)),
      ),
      child: child,
    );
    if (blur) {
      w = ClipRRect(
          borderRadius: r,
          child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20), child: w));
    }
    return w;
  }
}

class SpotlightCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final double radius;
  final bool beam;
  const SpotlightCard(
      {super.key,
      required this.child,
      this.onTap,
      this.padding = const EdgeInsets.all(16),
      this.radius = 22,
      this.beam = false});
  @override
  State<SpotlightCard> createState() => _SpotlightCardState();
}

class _SpotlightCardState extends State<SpotlightCard> {
  Alignment? _a;
  bool _hover = false, _down = false;

  Alignment _align(Offset p) {
    final s = context.size;
    if (s == null || s.width == 0 || s.height == 0) return Alignment.center;
    return Alignment((p.dx / s.width) * 2 - 1, (p.dy / s.height) * 2 - 1);
  }

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(widget.radius);
    Widget card = Container(
      decoration: BoxDecoration(
        borderRadius: r,
        gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, Color(0xFFFCFAF6)]),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0C30271F), blurRadius: 22, offset: Offset(0, 8))
        ],
        border: Border.all(
            color: _hover ? const Color(0xFFB6C4D5) : const Color(0xFFE6DED2)),
      ),
      child: Stack(children: [
        if (_a != null)
          Positioned.fill(
              child: IgnorePointer(
                  child: DecoratedBox(
                      decoration: BoxDecoration(
                          borderRadius: r,
                          gradient: RadialGradient(
                              center: _a!,
                              radius: .85,
                              colors: [
                                C.teal.withValues(alpha: .20),
                                Colors.transparent
                              ]))))),
        Padding(padding: widget.padding, child: widget.child),
      ]),
    );
    if (widget.beam) card = BorderBeam(radius: widget.radius, child: card);
    return MouseRegion(
      cursor:
          widget.onTap != null ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hover = true),
      onHover: (e) => setState(() {
        _hover = true;
        _a = _align(e.localPosition);
      }),
      onExit: (_) => setState(() {
        _hover = false;
        _a = null;
      }),
      child: GestureDetector(
        onTapDown: (d) => setState(() {
          _down = true;
          _a = _align(d.localPosition);
        }),
        onTapUp: (_) => setState(() {
          _down = false;
          if (!_hover) _a = null;
        }),
        onTapCancel: () => setState(() {
          _down = false;
          if (!_hover) _a = null;
        }),
        onTap: widget.onTap,
        child: AnimatedScale(
            scale: _down ? .97 : (_hover ? 1.012 : 1),
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            child: card),
      ),
    );
  }
}

class BorderBeam extends StatefulWidget {
  final Widget child;
  final double radius;
  const BorderBeam({super.key, required this.child, this.radius = 24});
  @override
  State<BorderBeam> createState() => _BorderBeamState();
}

class _BorderBeamState extends State<BorderBeam>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 5))
        ..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CustomPaint(
      foregroundPainter: _BeamPainter(_c, widget.radius), child: widget.child);
}

class _BeamPainter extends CustomPainter {
  final Animation<double> a;
  final double r;
  _BeamPainter(this.a, this.r) : super(repaint: a);
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final shader = SweepGradient(
      colors: const [
        Colors.transparent,
        C.teal,
        C.blue,
        Colors.transparent,
        Colors.transparent
      ],
      stops: const [0, .1, .2, .3, 1],
      transform: GradientRotation(a.value * 2 * math.pi),
    ).createShader(rect);
    canvas.drawRRect(
        RRect.fromRectAndRadius(rect.deflate(.8), Radius.circular(r)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8
          ..shader = shader);
  }

  @override
  bool shouldRepaint(covariant _BeamPainter old) => old.r != r;
}

// ───────────────────────── text & reveal ─────────────────────────
class GradientText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final TextAlign? align;
  const GradientText(this.text, {super.key, required this.style, this.align});
  @override
  Widget build(BuildContext context) => ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (r) => kGrad.createShader(r),
      child: Text(text,
          textAlign: align, style: style.copyWith(color: Colors.white)));
}

class FadeIn extends StatefulWidget {
  final Widget child;
  final int delay;
  final double dy;
  const FadeIn({super.key, required this.child, this.delay = 0, this.dy = 18});
  @override
  State<FadeIn> createState() => _FadeInState();
}

class _FadeInState extends State<FadeIn> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 700));
  late final Animation<double> _a =
      CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
      opacity: _a,
      child: AnimatedBuilder(
          animation: _a,
          builder: (_, c) => Transform.translate(
              offset: Offset(0, (1 - _a.value) * widget.dy), child: c),
          child: widget.child));
}

class RevealText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final bool center;
  final int delay;
  const RevealText(this.text,
      {super.key, required this.style, this.center = false, this.delay = 0});
  @override
  State<RevealText> createState() => _RevealTextState();
}

class _RevealTextState extends State<RevealText>
    with SingleTickerProviderStateMixin {
  late final List<String> _w = widget.text.split(RegExp(r'\s+'));
  late final AnimationController _c = AnimationController(
      vsync: this, duration: Duration(milliseconds: 500 + _w.length * 110));
  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (_, __) {
          final n = _w.length;
          return Wrap(
            alignment:
                widget.center ? WrapAlignment.center : WrapAlignment.start,
            children: [
              for (var i = 0; i < n; i++)
                () {
                  final s = i / (n + 2.0);
                  final e = math.min(1.0, s + 3.0 / (n + 2.0));
                  final t = Curves.easeOut
                      .transform(((_c.value - s) / (e - s)).clamp(0.0, 1.0));
                  return Opacity(
                      opacity: t,
                      child: Transform.translate(
                          offset: Offset(0, (1 - t) * 10),
                          child: Text('${_w[i]} ', style: widget.style)));
                }(),
            ],
          );
        },
      );
}

class CountUp extends StatelessWidget {
  final int value;
  final TextStyle style;
  const CountUp(this.value, {super.key, required this.style});
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: const Duration(milliseconds: 1400),
      curve: Curves.easeOutCubic,
      builder: (_, v, __) => GradientText(v.round().toString(), style: style));
}

// ───────────────────────── marquee ─────────────────────────
class Marquee extends StatefulWidget {
  final List<Widget> children;
  final bool reverse;
  final Duration duration;
  const Marquee(
      {super.key,
      required this.children,
      this.reverse = false,
      this.duration = const Duration(seconds: 40)});
  @override
  State<Marquee> createState() => _MarqueeState();
}

class _MarqueeState extends State<Marquee> with SingleTickerProviderStateMixin {
  late final AnimationController _ac =
      AnimationController(vsync: this, duration: widget.duration)..repeat();
  final _sc = ScrollController();
  @override
  void initState() {
    super.initState();
    _ac.addListener(() {
      if (!_sc.hasClients || !_sc.position.hasContentDimensions) return;
      final max = _sc.position.maxScrollExtent;
      final loop = ((max + _sc.position.viewportDimension) / 2).clamp(0.0, max);
      _sc.jumpTo((widget.reverse ? 1 - _ac.value : _ac.value) * loop);
    });
  }

  @override
  void dispose() {
    _ac.dispose();
    _sc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
      controller: _sc,
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      child: Row(children: [...widget.children, ...widget.children]));
}

Widget fadeEdges(Widget child) => ShaderMask(
    blendMode: BlendMode.dstIn,
    shaderCallback: (r) => const LinearGradient(colors: [
          Colors.transparent,
          Colors.black,
          Colors.black,
          Colors.transparent
        ], stops: [
          0,
          .08,
          .92,
          1
        ]).createShader(r),
    child: child);

class Pill extends StatelessWidget {
  final String text;
  final IconData? icon;
  final bool hi;
  const Pill({super.key, required this.text, this.icon, this.hi = false});
  @override
  Widget build(BuildContext context) {
    final base = hi ? C.blue : C.muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: base.withValues(alpha: hi ? .16 : .06),
          border: Border.all(color: base.withValues(alpha: hi ? .5 : .12))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[
          Icon(icon, size: 14, color: hi ? C.teal : C.muted),
          const SizedBox(width: 6)
        ],
        Text(text, style: b(12.5, color: C.text, w: FontWeight.w600)),
      ]),
    );
  }
}

class PillTabs extends StatelessWidget {
  final List<String> options;
  final String selected;
  final ValueChanged<String> onChanged;
  const PillTabs(
      {super.key,
      required this.options,
      required this.selected,
      required this.onChanged});
  @override
  Widget build(BuildContext context) => Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((o) {
        final on = o == selected;
        return MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
                onTap: () => onChanged(o),
                child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                        gradient: on ? kGrad : null,
                        color: on ? null : const Color(0xFFF1ECE3),
                        border: Border.all(
                            color: on ? C.blue : const Color(0xFFE2DACE))),
                    child: Text(o,
                        style: b(13,
                            color: on ? C.ink : C.text, w: FontWeight.w700)))));
      }).toList());
}

// ───────────────────────── buttons ─────────────────────────
class GlowButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool secondary;
  const GlowButton(
      {super.key,
      required this.label,
      this.icon,
      this.onTap,
      this.secondary = false});
  @override
  State<GlowButton> createState() => _GlowButtonState();
}

class _GlowButtonState extends State<GlowButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _s = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2600))
    ..repeat();
  bool _down = false;
  @override
  void dispose() {
    _s.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sec = widget.secondary;
    final fg = sec ? C.text : Colors.white;
    final r = BorderRadius.circular(16);
    return Opacity(
      opacity: widget.onTap == null ? .45 : 1,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTapDown: (_) => setState(() => _down = true),
          onTapUp: (_) => setState(() => _down = false),
          onTapCancel: () => setState(() => _down = false),
          onTap: widget.onTap,
          child: AnimatedScale(
            scale: _down ? .97 : 1,
            duration: const Duration(milliseconds: 120),
            child: Container(
              height: 52,
              width: double.infinity,
              decoration: BoxDecoration(
                  borderRadius: r,
                  gradient: sec ? null : kGrad,
                  color: sec ? const Color(0xFFF1ECE3) : null,
                  border:
                      sec ? Border.all(color: const Color(0xFFE2DACE)) : null,
                  boxShadow: sec
                      ? null
                      : [
                          BoxShadow(
                              color: C.blue.withValues(alpha: .18),
                              blurRadius: 18,
                              offset: const Offset(0, 7))
                        ]),
              child: ClipRRect(
                borderRadius: r,
                child: Stack(alignment: Alignment.center, children: [
                  if (!sec)
                    Positioned.fill(
                        child: AnimatedBuilder(
                            animation: _s,
                            builder: (_, __) => Align(
                                alignment: Alignment(-1.6 + 3.2 * _s.value, 0),
                                child: FractionallySizedBox(
                                    widthFactor: .22,
                                    heightFactor: 1,
                                    child: DecoratedBox(
                                        decoration: BoxDecoration(
                                            gradient: LinearGradient(colors: [
                                      Colors.white.withValues(alpha: 0),
                                      Colors.white.withValues(alpha: .32),
                                      Colors.white.withValues(alpha: 0)
                                    ]))))))),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    if (widget.icon != null) ...[
                      Icon(widget.icon, size: 20, color: fg),
                      const SizedBox(width: 8)
                    ],
                    Text(widget.label,
                        style: b(15, color: fg, w: FontWeight.w700)),
                  ]),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class RoundBtn extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool active, danger;
  final double size;
  const RoundBtn(
      {super.key,
      required this.icon,
      required this.onTap,
      this.active = false,
      this.danger = false,
      this.size = 48});
  @override
  State<RoundBtn> createState() => _RoundBtnState();
}

class _RoundBtnState extends State<RoundBtn> {
  bool _down = false;
  @override
  Widget build(BuildContext context) {
    final hl = widget.active && !widget.danger;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _down = true),
        onTapUp: (_) => setState(() => _down = false),
        onTapCancel: () => setState(() => _down = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _down ? .9 : 1,
          duration: const Duration(milliseconds: 120),
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: widget.danger
                    ? const LinearGradient(
                        colors: [Color(0xFFFF5D73), Color(0xFFFF3B6B)])
                    : (hl ? kGrad : null),
                color: (widget.danger || hl) ? null : Colors.white,
                border: Border.all(color: const Color(0xFFE2DACE))),
            child: Icon(widget.icon,
                size: widget.size * .44, color: hl ? Colors.white : C.text),
          ),
        ),
      ),
    );
  }
}

class TopBar extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const TopBar({super.key, required this.title, this.trailing});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(children: [
          RoundBtn(
              icon: Icons.arrow_back_rounded,
              size: 42,
              onTap: () => Navigator.maybePop(context)),
          const SizedBox(width: 14),
          Expanded(child: Text(title, style: h(21))),
          if (trailing != null) trailing!,
        ]),
      );
}

class Orb extends StatelessWidget {
  final IconData icon;
  final double size;
  const Orb(this.icon, {super.key, this.size = 46});
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(size * .34),
            color: const Color(0xFFE8EDF3),
            border: Border.all(color: const Color(0xFFD5DFE9))),
        child: Icon(icon, color: C.blue, size: size * .5),
      );
}

class LogoMark extends StatelessWidget {
  final double size;
  const LogoMark({super.key, this.size = 64});
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(size * .3),
            color: C.blue,
            boxShadow: [
              BoxShadow(
                  color: C.blue.withValues(alpha: .16),
                  blurRadius: size * .24,
                  offset: const Offset(0, 6))
            ]),
        child: Icon(Icons.sign_language, color: Colors.white, size: size * .56),
      );
}

// ───────────────────────── dock (floating nav) ─────────────────────────
class GlassDock extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;
  final List<(IconData, String)> items;
  const GlassDock(
      {super.key,
      required this.index,
      required this.onChanged,
      required this.items});
  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: const Color(0xFFFFFEFB),
                borderRadius: BorderRadius.circular(30),
                boxShadow: const [
                  BoxShadow(
                      color: Color(0x1730271F),
                      blurRadius: 24,
                      offset: Offset(0, 8))
                ],
                border: Border.all(color: const Color(0xFFE6DED2))),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              for (var i = 0; i < items.length; i++)
                _DockItem(
                    icon: items[i].$1,
                    label: items[i].$2,
                    on: i == index,
                    onTap: () => onChanged(i)),
            ]),
          ),
        ),
      );
}

class _DockItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool on;
  final VoidCallback onTap;
  const _DockItem(
      {required this.icon,
      required this.label,
      required this.on,
      required this.onTap});
  @override
  State<_DockItem> createState() => _DockItemState();
}

class _DockItemState extends State<_DockItem> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedScale(
            scale: _hover ? 1.1 : 1,
            duration: const Duration(milliseconds: 160),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              padding: EdgeInsets.symmetric(
                  horizontal: widget.on ? 18 : 14, vertical: 12),
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: widget.on ? kGrad : null),
              child: AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(widget.icon,
                      size: 22, color: widget.on ? C.ink : C.muted),
                  if (widget.on) ...[
                    const SizedBox(width: 8),
                    Text(widget.label,
                        style: b(13.5, color: C.ink, w: FontWeight.w800)),
                  ],
                ]),
              ),
            ),
          ),
        ),
      );
}

// ───────────────────────── Lenis-style smooth scroll ─────────────────────────
class LenisScroll extends StatefulWidget {
  final Widget Function(BuildContext, ScrollController, ScrollPhysics?) builder;
  const LenisScroll({super.key, required this.builder});
  @override
  State<LenisScroll> createState() => _LenisScrollState();
}

class _LenisScrollState extends State<LenisScroll>
    with SingleTickerProviderStateMixin {
  final _c = ScrollController();
  late final Ticker _tick = createTicker(_onTick);
  double _target = 0;

  bool get _smooth =>
      kIsWeb &&
      const {TargetPlatform.windows, TargetPlatform.macOS, TargetPlatform.linux}
          .contains(defaultTargetPlatform);

  void _onTick(Duration _) {
    if (!_c.hasClients) return;
    final d = _target - _c.offset;
    if (d.abs() < .4) {
      _c.jumpTo(_target);
      _tick.stop();
      return;
    }
    _c.jumpTo(_c.offset + d * .11);
  }

  void _onSignal(PointerSignalEvent e) {
    if (e is! PointerScrollEvent ||
        !_c.hasClients ||
        !_c.position.hasContentDimensions) return;
    final base = _tick.isActive ? _target : _c.offset;
    _target = (base + e.scrollDelta.dy).clamp(0.0, _c.position.maxScrollExtent);
    if (!_tick.isActive) _tick.start();
  }

  @override
  void dispose() {
    _tick.dispose();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_smooth) return widget.builder(context, _c, null);
    return Listener(
        onPointerSignal: _onSignal,
        child:
            widget.builder(context, _c, const NeverScrollableScrollPhysics()));
  }
}

// ───────────────────────── motion widgets ─────────────────────────
class PulseDot extends StatefulWidget {
  final Color color;
  final double size;
  const PulseDot({super.key, this.color = C.mint, this.size = 8});
  @override
  State<PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1400))
    ..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        width: widget.size * 3,
        height: widget.size * 3,
        child: Stack(alignment: Alignment.center, children: [
          AnimatedBuilder(
              animation: _c,
              builder: (_, __) => Container(
                  width: widget.size * (1 + _c.value * 1.8),
                  height: widget.size * (1 + _c.value * 1.8),
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.color
                          .withValues(alpha: .5 * (1 - _c.value))))),
          Container(
              width: widget.size,
              height: widget.size,
              decoration:
                  BoxDecoration(shape: BoxShape.circle, color: widget.color)),
        ]),
      );
}

class Ripples extends StatefulWidget {
  final double size;
  final Color color;
  const Ripples({super.key, required this.size, this.color = C.teal});
  @override
  State<Ripples> createState() => _RipplesState();
}

class _RipplesState extends State<Ripples> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 3000))
    ..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        width: widget.size,
        height: widget.size,
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, __) => Stack(alignment: Alignment.center, children: [
            for (var k = 0; k < 3; k++)
              () {
                final t = (_c.value + k / 3) % 1;
                final s = widget.size * (.35 + .65 * t);
                return Container(
                    width: s,
                    height: s,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                            color:
                                widget.color.withValues(alpha: .55 * (1 - t)),
                            width: 1.5)));
              }(),
          ]),
        ),
      );
}

class Waveform extends StatefulWidget {
  final bool active;
  final Color color;
  final int bars;
  const Waveform(
      {super.key, this.active = true, this.color = C.teal, this.bars = 24});
  @override
  State<Waveform> createState() => _WaveformState();
}

class _WaveformState extends State<Waveform>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1600))
    ..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CustomPaint(
      size: Size.infinite,
      painter: _WavePainter(_c, widget.active, widget.color, widget.bars));
}

class _WavePainter extends CustomPainter {
  final Animation<double> a;
  final bool active;
  final Color color;
  final int bars;
  _WavePainter(this.a, this.active, this.color, this.bars) : super(repaint: a);
  @override
  void paint(Canvas canvas, Size size) {
    final gap = size.width / bars;
    final p = Paint()..color = color;
    for (var i = 0; i < bars; i++) {
      final amp = active
          ? .25 + .75 * ((math.sin(a.value * 4 * math.pi + i * .7) + 1) / 2)
          : .12;
      final hh = size.height * amp;
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(
                  center: Offset(gap * i + gap / 2, size.height / 2),
                  width: gap * .55,
                  height: hh),
              const Radius.circular(3)),
          p);
    }
  }

  @override
  bool shouldRepaint(covariant _WavePainter old) => old.active != active;
}

class OrbitVisual extends StatefulWidget {
  final IconData icon;
  const OrbitVisual({super.key, required this.icon});
  @override
  State<OrbitVisual> createState() => _OrbitVisualState();
}

class _OrbitVisualState extends State<OrbitVisual>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 16))
        ..repeat();
  static const _sat = [
    Icons.mic_rounded,
    Icons.closed_caption_rounded,
    Icons.mood_rounded
  ];
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Widget _ring(double f) => Center(
      child: FractionallySizedBox(
          widthFactor: f,
          heightFactor: f,
          child: DecoratedBox(
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border:
                      Border.all(color: Colors.white.withValues(alpha: .1))))));

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 260,
        height: 260,
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, __) {
            final a = _c.value * 2 * math.pi;
            return Stack(alignment: Alignment.center, children: [
              const Ripples(size: 260, color: C.blue),
              _ring(.86),
              _ring(.5),
              for (var k = 0; k < 3; k++)
                Align(
                    alignment: Alignment(
                        math.cos(a + k * 2 * math.pi / 3) * .86,
                        math.sin(a + k * 2 * math.pi / 3) * .86),
                    child: Orb(_sat[k], size: 40)),
              for (var k = 0; k < 2; k++)
                Align(
                    alignment: Alignment(math.cos(-a * 1.4 + k * math.pi) * .5,
                        math.sin(-a * 1.4 + k * math.pi) * .5),
                    child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                            shape: BoxShape.circle, color: C.mint))),
              BorderBeam(
                  radius: 44,
                  child: Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF0B1020).withValues(alpha: .8)),
                      child: ShaderMask(
                          blendMode: BlendMode.srcIn,
                          shaderCallback: (r) => kGrad.createShader(r),
                          child: Icon(widget.icon,
                              size: 42, color: Colors.white)))),
            ]);
          },
        ),
      );
}

// ───────────────────────── camera panel with hand-tracking overlay ─────────────────────────
class CameraPanel extends StatefulWidget {
  final bool active;
  final String? caption;
  const CameraPanel({super.key, this.active = true, this.caption});
  @override
  State<CameraPanel> createState() => _CameraPanelState();
}

class _CameraPanelState extends State<CameraPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 4))
        ..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Container(
          decoration: BoxDecoration(
              gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0B1224), Color(0xFF06101A)]),
              border: Border.all(color: Colors.white.withValues(alpha: .1)),
              borderRadius: BorderRadius.circular(22)),
          child: Stack(children: [
            Positioned.fill(
                child: CustomPaint(painter: _CamPainter(_c, widget.active))),
            Positioned(
                left: 14,
                top: 14,
                child: widget.active
                    ? Row(children: [
                        const PulseDot(color: Color(0xFFFF4D6A), size: 7),
                        Text('LIVE',
                            style:
                                b(11, color: Colors.white, w: FontWeight.w800))
                      ])
                    : Row(children: [
                        const Icon(Icons.videocam_off_rounded,
                            size: 14, color: C.muted),
                        const SizedBox(width: 6),
                        Text('Camera off', style: b(11))
                      ])),
            Positioned(
                right: 14,
                top: 14,
                child: Text('MediaPipe • 21 pts',
                    style: b(10.5, color: C.teal, w: FontWeight.w700))),
            if (widget.caption != null)
              Positioned(
                  left: 14,
                  bottom: 14,
                  child: Glass(
                      radius: 14,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      child: Text(widget.caption!,
                          style: b(13, color: C.text, w: FontWeight.w700)))),
          ]),
        ),
      );
}

class _CamPainter extends CustomPainter {
  final Animation<double> a;
  final bool active;
  _CamPainter(this.a, this.active) : super(repaint: a);
  static const _pts = [
    Offset(.5, .92),
    Offset(.38, .82),
    Offset(.28, .70),
    Offset(.20, .58),
    Offset(.14, .47),
    Offset(.40, .58),
    Offset(.38, .40),
    Offset(.37, .27),
    Offset(.36, .15),
    Offset(.50, .55),
    Offset(.50, .35),
    Offset(.50, .21),
    Offset(.50, .08),
    Offset(.60, .58),
    Offset(.62, .40),
    Offset(.63, .28),
    Offset(.64, .17),
    Offset(.69, .65),
    Offset(.74, .50),
    Offset(.77, .40),
    Offset(.79, .31),
  ];
  static const _links = [
    [0, 1],
    [1, 2],
    [2, 3],
    [3, 4],
    [0, 5],
    [5, 6],
    [6, 7],
    [7, 8],
    [5, 9],
    [9, 10],
    [10, 11],
    [11, 12],
    [9, 13],
    [13, 14],
    [14, 15],
    [15, 16],
    [13, 17],
    [17, 18],
    [18, 19],
    [19, 20],
    [0, 17],
  ];
  @override
  void paint(Canvas canvas, Size size) {
    final t = a.value * 2 * math.pi;
    final s = math.min(size.width, size.height) * .66;
    final o =
        Offset((size.width - s) / 2, (size.height - s) / 2 + size.height * .04);
    final alpha = active ? 1.0 : .3;
    final pts = [
      for (var i = 0; i < _pts.length; i++)
        o +
            Offset(_pts[i].dx * s + (active ? math.sin(t * 2 + i) * 2.5 : 0),
                _pts[i].dy * s + (active ? math.cos(t * 2 + i * 1.3) * 2.5 : 0))
    ];
    // frame brackets
    final rect = Rect.fromCenter(
        center: Offset(size.width / 2, size.height / 2 + size.height * .03),
        width: s * 1.08,
        height: s * 1.08);
    final bp = Paint()
      ..color = C.mint.withValues(alpha: .9 * alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    const l = 24.0;
    void corner(double x, double y, double dx, double dy) => canvas.drawPath(
        Path()
          ..moveTo(x + dx * l, y)
          ..lineTo(x, y)
          ..lineTo(x, y + dy * l),
        bp);
    corner(rect.left, rect.top, 1, 1);
    corner(rect.right, rect.top, -1, 1);
    corner(rect.left, rect.bottom, 1, -1);
    corner(rect.right, rect.bottom, -1, -1);
    if (active) {
      final y = rect.top + rect.height * (.5 + .5 * math.sin(t));
      canvas.drawLine(
          Offset(rect.left, y),
          Offset(rect.right, y),
          Paint()
            ..strokeWidth = 2
            ..shader = LinearGradient(colors: [
              Colors.transparent,
              C.teal.withValues(alpha: .85),
              Colors.transparent
            ]).createShader(Rect.fromLTWH(rect.left, y, rect.width, 1)));
    }
    final lp = Paint()
      ..color = C.teal.withValues(alpha: .75 * alpha)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (final k in _links) {
      canvas.drawLine(pts[k[0]], pts[k[1]], lp);
    }
    final glow = Paint()
      ..color = C.teal.withValues(alpha: .35 * alpha)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    final dp = Paint()..color = Colors.white.withValues(alpha: alpha);
    for (final p in pts) {
      canvas.drawCircle(p, 5, glow);
      canvas.drawCircle(p, 2.6, dp);
    }
  }

  @override
  bool shouldRepaint(covariant _CamPainter old) => old.active != active;
}
