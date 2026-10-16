import 'package:flutter/material.dart';
import '../data.dart';
import '../ui.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 3200), () {
      if (mounted) Navigator.pushReplacementNamed(context, '/onboarding');
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(
                height: 200,
                child: Stack(
                    alignment: Alignment.center,
                    children: [Ripples(size: 200), LogoMark(size: 88)])),
            const SizedBox(height: 8),
            FadeIn(delay: 300, child: GradientText('SignBridge', style: h(42))),
            const SizedBox(height: 10),
            RevealText('Bridging Silence. Connecting Lives.',
                style: b(15), center: true, delay: 700),
            const SizedBox(height: 36),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 2800),
              builder: (_, v, __) => SizedBox(
                  width: 160,
                  height: 4,
                  child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Stack(children: [
                        const ColoredBox(
                            color: Color(0xFFE6DED2), child: SizedBox.expand()),
                        Align(
                            alignment: Alignment.centerLeft,
                            child: FractionallySizedBox(
                                widthFactor: v,
                                child: const DecoratedBox(
                                    decoration:
                                        BoxDecoration(gradient: kGrad)))),
                      ]))),
            ),
          ]),
        ),
      );
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _c = PageController();
  int _i = 0;
  static const _pages = [
    (
      Icons.sign_language,
      'Sign to text & speech',
      'Show a sign to your camera and get instant text and a natural voice.'
    ),
    (
      Icons.record_voice_over_rounded,
      'Speech to sign',
      'Type or speak, and watch the matching sign clips play back.'
    ),
    (
      Icons.video_call_rounded,
      'Live conversations',
      'One-to-one video with live captions and a mood indicator.'
    ),
  ];

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _next() => _i == _pages.length - 1
      ? Navigator.pushReplacementNamed(context, '/login')
      : _c.nextPage(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic);

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Centered(
            maxWidth: 520,
            child: Column(children: [
              Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                      onPressed: () =>
                          Navigator.pushReplacementNamed(context, '/login'),
                      child: Text('Skip',
                          style: b(14, color: C.muted, w: FontWeight.w700)))),
              Expanded(
                child: PageView.builder(
                  controller: _c,
                  itemCount: _pages.length,
                  onPageChanged: (i) => setState(() => _i = i),
                  itemBuilder: (_, i) {
                    final (icon, t, s) = _pages[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            OrbitVisual(icon: icon),
                            const SizedBox(height: 36),
                            RevealText(t, style: h(28), center: true),
                            const SizedBox(height: 12),
                            FadeIn(
                                delay: 400,
                                child: Text(s,
                                    textAlign: TextAlign.center, style: b(15))),
                          ]),
                    );
                  },
                ),
              ),
              Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                      _pages.length,
                      (i) => AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.all(4),
                          width: _i == i ? 28 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              gradient: _i == i ? kGrad : null,
                              color:
                                  _i == i ? null : const Color(0xFFE2DACE))))),
              Padding(
                  padding: const EdgeInsets.all(24),
                  child: GlowButton(
                      label:
                          _i == _pages.length - 1 ? 'Get started' : 'Continue',
                      icon: Icons.arrow_forward_rounded,
                      onTap: _next)),
            ]),
          ),
        ),
      );
}

class _AuthShell extends StatelessWidget {
  final String title, subtitle;
  final Widget form;
  final bool backButton;
  const _AuthShell(
      {required this.title,
      required this.subtitle,
      required this.form,
      this.backButton = false});

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: LayoutBuilder(builder: (context, cs) {
            final wide = cs.maxWidth >= 900;
            final card = SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (backButton) ...[
                          RoundBtn(
                              icon: Icons.arrow_back_rounded,
                              size: 42,
                              onTap: () => Navigator.maybePop(context)),
                          const SizedBox(height: 16)
                        ],
                        if (!wide) ...[
                          const FadeIn(child: LogoMark(size: 56)),
                          const SizedBox(height: 20)
                        ],
                        FadeIn(delay: 100, child: Text(title, style: h(32))),
                        const SizedBox(height: 8),
                        FadeIn(delay: 200, child: Text(subtitle, style: b(15))),
                        const SizedBox(height: 24),
                        FadeIn(
                            delay: 300,
                            child: BorderBeam(
                                radius: 28,
                                child: Glass(
                                    radius: 28,
                                    blur: true,
                                    padding: const EdgeInsets.all(22),
                                    child: form))),
                      ]),
                ),
              ),
            );
            if (!wide) return card;
            final half = kSigns.length ~/ 2;
            return Row(children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(56),
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const LogoMark(size: 68),
                        const SizedBox(height: 28),
                        RevealText('Bridging silence. Connecting lives.',
                            style: h(54)),
                        const SizedBox(height: 18),
                        Text(
                            'Real-time sign language, speech and text in one place, on Web and Android.',
                            style: b(17)),
                        const SizedBox(height: 36),
                        fadeEdges(SizedBox(
                            height: 36,
                            child: Marquee(children: [
                              for (final s in kSigns.sublist(0, half))
                                Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: Pill(text: s))
                            ]))),
                        const SizedBox(height: 10),
                        fadeEdges(SizedBox(
                            height: 36,
                            child: Marquee(reverse: true, children: [
                              for (final s in kSigns.sublist(half))
                                Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: Pill(text: s))
                            ]))),
                      ]),
                ),
              ),
              Expanded(child: card),
            ]);
          }),
        ),
      );
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _key = GlobalKey<FormState>();
  bool _obscure = true;

  void _forgot() => showDialog(
      context: context,
      builder: (_) => AlertDialog(
            backgroundColor: const Color(0xFFFFFEFB),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: const BorderSide(color: Color(0xFFE6DED2))),
            title: Text('Reset password', style: h(20)),
            content: const TextField(
                decoration: InputDecoration(labelText: 'Registered email')),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel')),
              TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Reset link sent (mock)')));
                  },
                  child: const Text('Send link')),
            ],
          ));

  @override
  Widget build(BuildContext context) => _AuthShell(
        title: 'Welcome back',
        subtitle: 'Sign in to continue your conversations.',
        form: Form(
          key: _key,
          child: Column(children: [
            TextFormField(
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                  labelText: 'Email', prefixIcon: Icon(Icons.email_outlined)),
              validator: (v) => (v == null || !v.contains('@'))
                  ? 'Enter a valid email'
                  : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              obscureText: _obscure,
              decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                      icon: Icon(_obscure
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded),
                      onPressed: () => setState(() => _obscure = !_obscure))),
              validator: (v) =>
                  (v == null || v.length < 6) ? 'Minimum 6 characters' : null,
            ),
            Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                    onPressed: _forgot,
                    child: Text('Forgot password?',
                        style: b(13, color: C.teal, w: FontWeight.w700)))),
            GlowButton(
                label: 'Sign in',
                icon: Icons.arrow_forward_rounded,
                onTap: () {
                  if (_key.currentState!.validate())
                    Navigator.pushReplacementNamed(context, '/home');
                }),
            const SizedBox(height: 12),
            GlowButton(
                label: 'Continue as demo user',
                secondary: true,
                onTap: () => Navigator.pushReplacementNamed(context, '/home')),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('New here?', style: b(13.5)),
              TextButton(
                  onPressed: () => Navigator.pushNamed(context, '/register'),
                  child: Text('Create account',
                      style: b(13.5, color: C.teal, w: FontWeight.w700))),
            ]),
          ]),
        ),
      );
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _key = GlobalKey<FormState>();
  final _pass = TextEditingController();
  String _role = 'Deaf / Mute';

  @override
  void dispose() {
    _pass.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _AuthShell(
        backButton: true,
        title: 'Create account',
        subtitle: 'Join SignBridge in under a minute.',
        form: Form(
          key: _key,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            TextFormField(
                decoration: const InputDecoration(
                    labelText: 'Full name',
                    prefixIcon: Icon(Icons.person_outline_rounded)),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Enter your name' : null),
            const SizedBox(height: 14),
            TextFormField(
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                    labelText: 'Email', prefixIcon: Icon(Icons.email_outlined)),
                validator: (v) => (v == null || !v.contains('@'))
                    ? 'Enter a valid email'
                    : null),
            const SizedBox(height: 14),
            Text('I am', style: b(13, w: FontWeight.w700)),
            const SizedBox(height: 8),
            PillTabs(
                options: const ['Deaf / Mute', 'Hearing'],
                selected: _role,
                onChanged: (v) => setState(() => _role = v)),
            const SizedBox(height: 14),
            TextFormField(
                controller: _pass,
                obscureText: true,
                decoration: const InputDecoration(
                    labelText: 'Password',
                    prefixIcon: Icon(Icons.lock_outline_rounded)),
                validator: (v) => (v == null || v.length < 6)
                    ? 'Minimum 6 characters'
                    : null),
            const SizedBox(height: 14),
            TextFormField(
                obscureText: true,
                decoration: const InputDecoration(
                    labelText: 'Confirm password',
                    prefixIcon: Icon(Icons.lock_outline_rounded)),
                validator: (v) =>
                    v != _pass.text ? 'Passwords do not match' : null),
            const SizedBox(height: 20),
            GlowButton(
                label: 'Create account',
                icon: Icons.check_rounded,
                onTap: () {
                  if (_key.currentState!.validate())
                    Navigator.pushNamedAndRemoveUntil(
                        context, '/home', (_) => false);
                }),
          ]),
        ),
      );
}
