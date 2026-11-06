import 'package:flutter/foundation.dart';
import '../../../core/api_client.dart';
import '../../../core/errors.dart';
import '../models/account.dart';
import '../repositories/auth_repository.dart';

enum AuthPhase { starting, guest, signedIn, unavailable }

class AuthController extends ChangeNotifier {
  AuthController(this.repository) {
    repository.api.onSessionExpired = () {
      account = null;
      phase = AuthPhase.guest;
      notifyListeners();
    };
  }
  final AuthRepository repository;
  Account? account;
  AuthPhase phase = AuthPhase.starting;
  bool busy = false;
  String? error;
  Future<void> start() async {
    phase = AuthPhase.starting;
    error = null;
    notifyListeners();
    try {
      account = await repository.restore();
      phase = account == null ? AuthPhase.guest : AuthPhase.signedIn;
    } catch (failure) {
      phase = repository.api.hasRefreshSession
          ? AuthPhase.unavailable
          : AuthPhase.guest;
      error = friendlyError(failure);
    }
    notifyListeners();
  }

  Future<void> submit({
    required String email,
    required String password,
    Json? registration,
  }) async {
    if (busy) return;
    busy = true;
    error = null;
    notifyListeners();
    try {
      account = registration == null
          ? await repository.signIn(email, password)
          : await repository.register(registration);
      phase = AuthPhase.signedIn;
    } catch (failure) {
      error = friendlyError(failure);
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    if (busy) return;
    busy = true;
    notifyListeners();
    try {
      await repository.api.logout();
      error = null;
    } catch (_) {
      error =
          'Saliste de este dispositivo. No pudimos confirmar el cierre en el servicio.';
    } finally {
      account = null;
      phase = AuthPhase.guest;
      busy = false;
      notifyListeners();
    }
  }

  void acceptAccount(Json data) {
    if (phase != AuthPhase.signedIn || data['id'] != account?.id) return;
    account = Account.fromJson(data);
    notifyListeners();
  }

  void removeProfileImage() {
    final user = account;
    if (user == null || phase != AuthPhase.signedIn) return;
    account = Account(
      id: user.id,
      name: user.name,
      username: user.username,
      email: user.email,
      role: user.role,
    );
    notifyListeners();
  }

  Future<void> refreshAccount() async {
    final id = account?.id;
    final result = await repository.me();
    if (phase != AuthPhase.signedIn || account?.id != id) return;
    account = result;
    notifyListeners();
  }
}
