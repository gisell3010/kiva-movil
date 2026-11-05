import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract class PreferencesStore {
  Future<String?> read();
  Future<void> write(String value);
}

class SecurePreferencesStore implements PreferencesStore {
  SecurePreferencesStore(this.key);
  final String key;
  final _storage = const FlutterSecureStorage();
  @override
  Future<String?> read() => _storage.read(key: key);
  @override
  Future<void> write(String value) => _storage.write(key: key, value: value);
}

class AppPreferences extends ChangeNotifier {
  AppPreferences(this.store);
  final PreferencesStore store;
  ThemeMode theme = ThemeMode.system;
  bool highContrast = false;
  bool reduceMotion = false;
  bool busy = false;
  bool loaded = false;
  bool _disposed = false;
  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load() async {
    try {
      final saved = await store.read();
      if (saved != null) {
        final data = jsonDecode(saved);
        if (data is Map) {
          theme = switch (data['theme']) {
            'light' => ThemeMode.light,
            'dark' => ThemeMode.dark,
            _ => ThemeMode.system,
          };
          highContrast = data['high_contrast'] == true;
          reduceMotion = data['reduce_motion'] == true;
        }
      }
    } catch (_) {
      // Device preferences must never prevent authentication.
    } finally {
      loaded = true;
      _notify();
    }
  }

  Future<void> update({
    ThemeMode? theme,
    bool? highContrast,
    bool? reduceMotion,
  }) async {
    if (busy || !loaded) return;
    final old = (this.theme, this.highContrast, this.reduceMotion);
    busy = true;
    this.theme = theme ?? this.theme;
    this.highContrast = highContrast ?? this.highContrast;
    this.reduceMotion = reduceMotion ?? this.reduceMotion;
    _notify();
    try {
      await store.write(
        jsonEncode({
          'theme': this.theme.name,
          'high_contrast': this.highContrast,
          'reduce_motion': this.reduceMotion,
        }),
      );
    } catch (_) {
      this.theme = old.$1;
      this.highContrast = old.$2;
      this.reduceMotion = old.$3;
      rethrow;
    } finally {
      busy = false;
      _notify();
    }
  }

  static AppPreferences of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PreferencesScope>()!.notifier!;
}

class PreferencesScope extends InheritedNotifier<AppPreferences> {
  const PreferencesScope({
    super.key,
    required AppPreferences preferences,
    required super.child,
  }) : super(notifier: preferences);
}
