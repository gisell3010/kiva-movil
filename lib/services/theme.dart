import 'package:flutter/material.dart';

ThemeData kivaTheme(Brightness brightness, {bool highContrast = false}) {
  final dark = brightness == Brightness.dark;
  final scheme =
      ColorScheme.fromSeed(
        seedColor: const Color.fromARGB(255, 68, 9, 84),
        brightness: brightness,
        contrastLevel: highContrast ? 1 : 0,
      ).copyWith(
        surface: dark ? const Color.fromARGB(255, 19, 3, 32) : Colors.white,
        onSurface: dark
            ? const Color.fromARGB(255, 246, 238, 248)
            : const Color(0xFF171B2F),
        onSurfaceVariant: dark
            ? const Color(0xFFB7C1DB)
            : const Color(0xFF505B73),
      );
  final border = OutlineInputBorder(borderRadius: BorderRadius.circular(16));
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: dark
        ? const Color.fromARGB(255, 4, 1, 5)
        : const Color.fromARGB(255, 251, 247, 252),
    appBarTheme: AppBarTheme(
      backgroundColor: dark ? const Color(0xFF0A0E1A) : const Color(0xFFF7F8FC),
      foregroundColor: scheme.onSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 6),
      color: dark
          ? const Color.fromARGB(255, 14, 1, 22)
          : const Color.fromARGB(255, 250, 239, 255),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: highContrast ? scheme.outline : scheme.outlineVariant,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? const Color(0xFF141B30) : Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      border: border,
      enabledBorder: border.copyWith(
        borderSide: BorderSide(color: scheme.outline),
      ),
      focusedBorder: border.copyWith(
        borderSide: BorderSide(
          color: dark ? const Color(0xFF93BBFF) : const Color(0xFF2563EB),
          width: 2,
        ),
      ),
      errorMaxLines: 3,
      helperMaxLines: 3,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 52),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        backgroundColor: highContrast
            ? scheme.primary
            : const Color(0xFF7C3AED),
        foregroundColor: highContrast ? scheme.onPrimary : Colors.white,
        textStyle: const TextStyle(
          fontFamily: 'Roboto',
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 52),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: dark
          ? const Color.fromARGB(255, 21, 0, 27)
          : const Color.fromARGB(255, 246, 218, 253),
      indicatorColor: dark
          ? const Color.fromARGB(255, 89, 51, 102)
          : const Color.fromARGB(255, 34, 18, 49),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: AccessiblePageTransitions(),
        TargetPlatform.iOS: AccessiblePageTransitions(),
      },
    ),
    visualDensity: VisualDensity.standard,
  );
}

class AccessiblePageTransitions extends PageTransitionsBuilder {
  const AccessiblePageTransitions();
  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return const FadeUpwardsPageTransitionsBuilder().buildTransitions(
      route,
      context,
      animation,
      secondaryAnimation,
      child,
    );
  }
}
