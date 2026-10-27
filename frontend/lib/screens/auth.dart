import 'package:flutter/material.dart';
import '../data.dart';
import '../config.dart';
import '../services/api.dart';
import '../services/auth_service.dart';
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
    _go();
  }

  Future<void> _go() async {
    final started = DateTime.now();
    await Api.I.loadConfig(); // does the backend use Firebase login?
    final ok = await Api.I.restore(); // already logged in? go straight to Home
    final wait = 2600 - DateTime.now().difference(started).inMilliseconds;
    if (wait > 0) await Future.delayed(Duration(milliseconds: wait));
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, ok ? '/home' : '/onboarding');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(
                height: 200,
                child: Stack(alignment: Alignment.center, children: [Ripples(size: 200), LogoMark(size: 88)])),
            const SizedBox(height: 8),
            FadeIn(delay: 300, child: GradientText('SignBridge', style: h(42))),
            const SizedBox(height: 10),
            RevealText('Bridging Silence. Connecting Lives.', style: b(15), center: true, delay: 700),
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
                        ColoredBox(color: C.text.withValues(alpha: .10), child: const SizedBox.expand()),
                        Align(alignment: Alignment.centerLeft, child: FractionallySizedBox(widthFactor: v, child: const DecoratedBox(decoration: BoxDecoration(gradient: kGrad)))),
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
    (Icons.sign_language, 'Sign to text & speech', 'Show a sign to your camera and get instant text and a natural voice.'),
    (Icons.record_voice_over_rounded, 'Speech to sign', 'Type or speak, and watch the matching sign clips play back.'),
    (Icons.video_call_rounded, 'Live conversations', 'One-to-one video with live captions and a mood indicator.'),
  ];

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _next() => _i == _pages.length - 1
      ? Navigator.pushReplacementNamed(context, '/login')
      : _c.nextPage(duration: const Duration(milliseconds: 400), curve: Curves.easeOutCubic);

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Centered(
            maxWidth: 520,
            child: Column(children: [
              Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                      onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
                      child: Text('Skip', style: b(14, color: C.muted, w: FontWeight.w700)))),
              Expanded(
                child: PageView.builder(
                  controller: _c,
                  itemCount: _pages.length,
                  onPageChanged: (i) => setState(() => _i = i),
                  itemBuilder: (_, i) {
                    final (icon, t, s) = _pages[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        OrbitVisual(icon: icon),
                        const SizedBox(height: 36),
                        RevealText(t, style: h(28), center: true),
                        const SizedBox(height: 12),
                        FadeIn(delay: 400, child: Text(s, textAlign: TextAlign.center, style: b(15))),
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
                              color: _i == i ? null : C.text.withValues(alpha: .18))))),
              Padding(padding: const EdgeInsets.all(24), child: GlowButton(label: _i == _pages.length - 1 ? 'Get started' : 'Continue', icon: Icons.arrow_forward_rounded, onTap: _next)),
            ]),
          ),
        ),
      );
}

class _AuthShell extends StatelessWidget {
  final String title, subtitle;
  final Widget form;
  final bool backButton;
  const _AuthShell({required this.title, required this.subtitle, required this.form, this.backButton = false});

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
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (backButton) ...[RoundBtn(icon: Icons.arrow_back_rounded, size: 42, onTap: () => Navigator.maybePop(context)), const SizedBox(height: 16)],
                    if (!wide) ...[const FadeIn(child: LogoMark(size: 56)), const SizedBox(height: 20)],
                    FadeIn(delay: 100, child: Text(title, style: h(32))),
                    const SizedBox(height: 8),
                    FadeIn(delay: 200, child: Text(subtitle, style: b(15))),
                    const SizedBox(height: 24),
                    FadeIn(delay: 300, child: BorderBeam(radius: 28, child: Glass(radius: 28, blur: true, padding: const EdgeInsets.all(22), child: form))),
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
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const LogoMark(size: 68),
                    const SizedBox(height: 28),
                    RevealText('Bridging silence. Connecting lives.', style: h(54)),
                    const SizedBox(height: 18),
                    Text('Real-time sign language, speech and text in one place, on Web and Android.', style: b(17)),
                    const SizedBox(height: 36),
                    fadeEdges(SizedBox(height: 36, child: Marquee(children: [for (final s in kSigns.sublist(0, half)) Padding(padding: const EdgeInsets.only(right: 8), child: Pill(text: s))]))),
                    const SizedBox(height: 10),
                    fadeEdges(SizedBox(height: 36, child: Marquee(reverse: true, children: [for (final s in kSigns.sublist(half)) Padding(padding: const EdgeInsets.only(right: 8), child: Pill(text: s))]))),
                  ]),
                ),
              ),
              Expanded(child: card),
            ]);
          }),
        ),
      );
}

const _red = Color(0xFFC0392B);

/// Asks a brand-new (Google) user whether they are deaf/mute or hearing.
Future<void> askRole(BuildContext context) async {
  String sel = 'Hearing';
  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setD) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: const BorderSide(color: C.line)),
        title: Text('Welcome to SignBridge', style: h(20)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('I am a', style: b(13, w: FontWeight.w700)),
          const SizedBox(height: 10),
          PillTabs(options: const ['Deaf / Mute', 'Hearing'], selected: sel, onChanged: (v) => setD(() => sel = v)),
        ]),
        actions: [
          TextButton(
              onPressed: () async {
                try {
                  await Api.I.updateProfile(role: sel == 'Hearing' ? 'hearing' : 'deaf_mute');
                } catch (_) {}
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Continue')),
        ],
      ),
    ),
  );
}

Widget _orDivider() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(children: [
      const Expanded(child: Divider(color: C.line)),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text('or', style: b(12.5))),
      const Expanded(child: Divider(color: C.line)),
    ]));

Widget _firebaseWarning() => AppConfig.firebaseReady
    ? const SizedBox.shrink()
    : Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
            AppConfig.backendFirebase
                ? 'The server wants Firebase login, but this app is not connected to Firebase yet. Run "flutterfire configure" (see README).'
                : 'Google sign-in and email verification go live once Firebase is connected: run "flutterfire configure" (see README) and set FIREBASE_PROJECT_ID in the backend .env, then restart the app.',
            style: b(12.5, color: C.amber, w: FontWeight.w600)));

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _key = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _obscure = true, _loading = false, _needsVerify = false;
  String? _error, _info;

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _done(bool isNew) async {
    if (!mounted) return;
    if (isNew) await askRole(context);
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/home');
  }

  Future<void> _submit() async {
    if (!_key.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
      _info = null;
      _needsVerify = false;
    });
    try {
      if (AuthService.useFirebase) {
        await AuthService.signIn(_email.text.trim(), _pass.text);
      } else {
        await Api.I.login(_email.text.trim(), _pass.text);
      }
      await _done(false);
    } on NeedsVerification catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _needsVerify = true;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _google() async {
    if (!AppConfig.firebaseReady) {
      setState(() => _error = 'Google sign-in needs Firebase. Run "flutterfire configure" (see README), then restart the app.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _info = null;
    });
    try {
      await _done(await AuthService.google());
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = 'Google sign-in failed: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    try {
      await AuthService.resendVerification(_email.text.trim(), _pass.text);
      if (mounted) {
        setState(() {
          _info = 'Verification email sent again. Check your inbox and spam folder.';
          _error = null;
          _needsVerify = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _forgot() async {
    final c = TextEditingController(text: _email.text.trim());
    String? msg;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: const BorderSide(color: C.line)),
          title: Text('Reset password', style: h(20)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: c, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Registered email')),
            if (msg != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(msg!, style: b(13, color: C.text))),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
            TextButton(
                onPressed: () async {
                  if (!AuthService.useFirebase) {
                    setD(() => msg = 'Password reset e-mails need Firebase login (see README).');
                    return;
                  }
                  try {
                    await AuthService.resetPassword(c.text.trim());
                    setD(() => msg = 'Reset link sent. Check your inbox.');
                  } on ApiException catch (e) {
                    setD(() => msg = e.message);
                  }
                },
                child: const Text('Send link')),
          ],
        ),
      ),
    );
    c.dispose();
  }

  @override
  Widget build(BuildContext context) => _AuthShell(
        title: 'Welcome back',
        subtitle: 'Sign in to continue your conversations.',
        form: Form(
          key: _key,
          child: Column(children: [
            _firebaseWarning(),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined)),
              validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _pass,
              obscureText: _obscure,
              decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(icon: Icon(_obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded), onPressed: () => setState(() => _obscure = !_obscure))),
              validator: (v) => (v == null || v.length < 6) ? 'Minimum 6 characters' : null,
            ),
            Align(alignment: Alignment.centerRight, child: TextButton(onPressed: _forgot, child: Text('Forgot password?', style: b(13, color: C.blue, w: FontWeight.w700)))),
            if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(_error!, textAlign: TextAlign.center, style: b(13, color: _red, w: FontWeight.w600))),
            if (_info != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(_info!, textAlign: TextAlign.center, style: b(13, color: C.mint, w: FontWeight.w600))),
            if (_needsVerify) TextButton(onPressed: _resend, child: Text('Resend verification email', style: b(13, color: C.blue, w: FontWeight.w700))),
            GlowButton(label: _loading ? 'Please wait...' : 'Sign in', icon: Icons.arrow_forward_rounded, onTap: _loading ? null : _submit),
            _orDivider(),
            GlowButton(label: 'Continue with Google', icon: Icons.account_circle_outlined, secondary: true, onTap: _loading ? null : _google),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('New here?', style: b(13.5)),
              TextButton(onPressed: () => Navigator.pushNamed(context, '/register'), child: Text('Create account', style: b(13.5, color: C.blue, w: FontWeight.w700))),
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
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  String _role = 'Deaf / Mute';
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  String get _roleKey => _role == 'Hearing' ? 'hearing' : 'deaf_mute';

  Future<void> _submit() async {
    if (!_key.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (AuthService.useFirebase) {
        await AuthService.register(name: _name.text.trim(), email: _email.text.trim(), password: _pass.text, role: _roleKey);
        if (!mounted) return;
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: const BorderSide(color: C.line)),
            title: Text('Check your email', style: h(20)),
            content: Text('We sent a verification link to ${_email.text.trim()}.\nOpen it, then come back and sign in. You cannot sign in before the email is verified.', style: b(14, color: C.text)),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
          ),
        );
        if (mounted) Navigator.pushReplacementNamed(context, '/login');
      } else {
        await Api.I.register(fullName: _name.text.trim(), email: _email.text.trim(), password: _pass.text, role: _roleKey);
        if (!mounted) return;
        Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _google() async {
    if (!AppConfig.firebaseReady) {
      setState(() => _error = 'Google sign-up needs Firebase. Run "flutterfire configure" (see README), then restart the app.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final isNew = await AuthService.google();
      if (!mounted) return;
      if (isNew) await askRole(context);
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = 'Google sign-up failed: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => _AuthShell(
        backButton: true,
        title: 'Create account',
        subtitle: AuthService.useFirebase ? 'We will email you a link to confirm your address.' : 'Join SignBridge in under a minute.',
        form: Form(
          key: _key,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _firebaseWarning(),
            TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Full name', prefixIcon: Icon(Icons.person_outline_rounded)),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter your name' : null),
            const SizedBox(height: 14),
            TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined)),
                validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null),
            const SizedBox(height: 14),
            Text('I am', style: b(13, w: FontWeight.w700)),
            const SizedBox(height: 8),
            PillTabs(options: const ['Deaf / Mute', 'Hearing'], selected: _role, onChanged: (v) => setState(() => _role = v)),
            const SizedBox(height: 14),
            TextFormField(
                controller: _pass,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock_outline_rounded)),
                validator: (v) => (v == null || v.length < 6) ? 'Minimum 6 characters' : null),
            const SizedBox(height: 14),
            TextFormField(
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Confirm password', prefixIcon: Icon(Icons.lock_outline_rounded)),
                validator: (v) => v != _pass.text ? 'Passwords do not match' : null),
            const SizedBox(height: 20),
            if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(_error!, style: b(13, color: _red, w: FontWeight.w600))),
            GlowButton(label: _loading ? 'Please wait...' : 'Create account', icon: Icons.check_rounded, onTap: _loading ? null : _submit),
            _orDivider(),
            GlowButton(label: 'Sign up with Google', icon: Icons.account_circle_outlined, secondary: true, onTap: _loading ? null : _google),
          ]),
        ),
      );
}
