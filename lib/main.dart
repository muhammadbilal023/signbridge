import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/auth.dart';
import 'screens/home.dart';
import 'screens/sign_to_text.dart';
import 'screens/text_to_sign.dart';
import 'screens/live.dart';
import 'screens/help.dart';
import 'ui.dart';

void main() => runApp(const SignBridgeApp());

class _FadeSlide extends PageTransitionsBuilder {
  const _FadeSlide();
  @override
  Widget buildTransitions<T>(PageRoute<T> route, BuildContext context,
          Animation<double> a, Animation<double> s, Widget child) =>
      FadeTransition(
          opacity: CurvedAnimation(parent: a, curve: Curves.easeOut),
          child: SlideTransition(
              position: Tween(begin: const Offset(0, .03), end: Offset.zero)
                  .animate(
                      CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
              child: child));
}

OutlineInputBorder _ob(Color c, [double w = 1]) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: BorderSide(color: c, width: w));

ThemeData buildTheme() {
  final base = ThemeData.light(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: C.bg,
    colorScheme: const ColorScheme.light(
        primary: C.blue,
        secondary: C.mint,
        surface: Color(0xFFFFFEFB),
        onSurface: C.text),
    textTheme: GoogleFonts.manropeTextTheme(base.textTheme)
        .apply(bodyColor: C.text, displayColor: C.text),
    pageTransitionsTheme: PageTransitionsTheme(builders: {
      for (final p in TargetPlatform.values) p: const _FadeSlide()
    }),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFFFFEFB),
      labelStyle: b(14),
      hintStyle: b(14, color: C.muted.withValues(alpha: .7)),
      prefixIconColor: C.muted,
      suffixIconColor: C.muted,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: _ob(const Color(0xFFE2DACE)),
      enabledBorder: _ob(const Color(0xFFE2DACE)),
      focusedBorder: _ob(C.blue, 1.6),
      errorBorder: _ob(const Color(0xFFFF5D73)),
      focusedErrorBorder: _ob(const Color(0xFFFF5D73), 1.6),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: const WidgetStatePropertyAll(Colors.white),
      trackColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected) ? C.blue : const Color(0xFFE2DACE)),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    sliderTheme: SliderThemeData(
        activeTrackColor: C.blue,
        inactiveTrackColor: const Color(0xFFE2DACE),
        thumbColor: Colors.white,
        overlayColor: C.blue.withValues(alpha: .12)),
    snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: C.text,
        contentTextStyle: b(14, color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
    bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        modalBackgroundColor: Colors.transparent,
        elevation: 0),
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
