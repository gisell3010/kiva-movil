import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AuthSurface extends StatelessWidget {
  const AuthSurface({super.key, required this.child, this.illustrated = false});
  final Widget child;
  final bool illustrated;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return Theme(
      data: theme.copyWith(
        scaffoldBackgroundColor: illustrated
            ? Colors.transparent
            : theme.colorScheme.surface,
        appBarTheme: theme.appBarTheme.copyWith(
          backgroundColor: Colors.transparent,
          foregroundColor: illustrated
              ? Colors.white
              : theme.colorScheme.onSurface,
        ),
      ),
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: dark || illustrated
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        child: illustrated
            ? DecoratedBox(
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage('assets/images/login-background.jpg'),
                    fit: BoxFit.cover,
                  ),
                ),
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x44321A46), Color(0xAA17142B)],
                    ),
                  ),
                  child: child,
                ),
              )
            : ColoredBox(color: theme.colorScheme.surface, child: child),
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
    filterQuality: FilterQuality.high,
    semanticLabel: 'KIVA',
  );
}
