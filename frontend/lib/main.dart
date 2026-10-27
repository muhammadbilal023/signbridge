import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'config.dart';
import 'firebase_options.dart';
import 'screens/auth.dart';
import 'screens/home.dart';
import 'screens/sign_to_text.dart';
import 'screens/text_to_sign.dart';
import 'screens/live.dart';
import 'screens/help.dart';
import 'ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    AppConfig.firebaseReady = true;
  } catch (e) {
    debugPrint('Firebase is not set up yet ($e) - using the backend login.');
  }
  runApp(const SignBridgeApp());
}

class _FadeSlide extends PageTransitionsBuilder {
  const _FadeSlide();
  @override
  Widget buildTransitions<T>(PageRoute<T> route, BuildContext context, Animation<double> a, Animation<double> s, Widget child) =>
      FadeTransition(
          opacity: CurvedAnimation(parent: a, curve: Curves.easeOut),
          child: SlideTransition(
              position: Tween(begin: const Offset(0, .03), end: Offset.zero).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
              child: child));
}

OutlineInputBorder _ob(Color c, [double w = 1]) =>
    OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: c, width: w));

ThemeData buildTheme() {
  final base = ThemeData.light(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: Colors.transparent,
    colorScheme: const ColorScheme.light(primary: C.teal, secondary: C.blue, surface: Colors.white, onSurface: C.text),
    textTheme: GoogleFonts.manropeTextTheme(base.textTheme).apply(bodyColor: C.text, displayColor: C.text),
    pageTransitionsTheme: PageTransitionsTheme(builders: {for (final p in TargetPlatform.values) p: const _FadeSlide()}),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFFEFDFB),
      labelStyle: b(14),
      hintStyle: b(14, color: C.muted.withValues(alpha: .7)),
      prefixIconColor: C.muted,
      suffixIconColor: C.muted,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: _ob(C.line),
      enabledBorder: _ob(C.line),
      focusedBorder: _ob(C.blue, 1.6),
      errorBorder: _ob(const Color(0xFFFF5D73)),
      focusedErrorBorder: _ob(const Color(0xFFFF5D73), 1.6),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: const WidgetStatePropertyAll(Colors.white),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? C.teal : Colors.black26),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    sliderTheme: SliderThemeData(
        activeTrackColor: C.teal, inactiveTrackColor: Colors.black12, thumbColor: C.teal, overlayColor: C.teal.withValues(alpha: .15)),
    snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: C.text,
        contentTextStyle: b(14, color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
    bottomSheetTheme: const BottomSheetThemeData(backgroundColor: Colors.transparent, modalBackgroundColor: Colors.transparent, elevation: 0),
    dividerColor: Colors.transparent,
  );
}

class SignBridgeApp extends StatelessWidget {
  const SignBridgeApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'SignBridge',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        builder: (ctx, child) => AuroraBackground(child: child!),
        initialRoute: '/',
        routes: {
          '/': (_) => const SplashScreen(),
          '/onboarding': (_) => const OnboardingScreen(),
          '/login': (_) => const LoginScreen(),
          '/register': (_) => const RegisterScreen(),
          '/home': (_) => const HomeShell(),
          '/sign-to-text': (_) => const SignToTextScreen(),
          '/text-to-sign': (_) => const TextToSignScreen(),
          '/live': (_) => const LiveLobbyScreen(),
          '/help': (_) => const HelpScreen(),
        },
      );
}
