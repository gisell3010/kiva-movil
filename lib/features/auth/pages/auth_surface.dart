import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AuthSurface extends StatelessWidget {
  const AuthSurface({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return Theme(
      data: theme.copyWith(
        scaffoldBackgroundColor: Colors.transparent,
        appBarTheme: theme.appBarTheme.copyWith(
          backgroundColor: Colors.transparent,
        ),
      ),
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: dark
                  ? const [
                      Color.fromARGB(255, 50, 24, 61),
                      Color.fromARGB(255, 16, 10, 26),
                      Color(0xFF201331),
                    ]
                  : const [
                      Color.fromARGB(255, 245, 237, 255),
                      Color.fromARGB(255, 250, 247, 252),
                      Color.fromARGB(255, 248, 234, 254),
                    ],
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

class KivaLogo extends StatelessWidget {
  const KivaLogo({super.key, this.size = 88});
  final double size;
  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/brand/kiva-logo.png',
    width: size,
    height: size,
    fit: BoxFit.contain,
    semanticLabel: 'KIVA',
  );
}
