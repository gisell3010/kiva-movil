import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'auth_event.dart';
import 'auth_state.dart';
export 'auth_event.dart';
export 'auth_state.dart';

import 'package:flutter/foundation.dart';

import 'package:kiva_mobile_final/models/account.dart';
import 'package:kiva_mobile_final/repositories/auth/auth_repository.dart';
import 'package:kiva_mobile_final/services/api_client.dart';
import 'package:kiva_mobile_final/services/errors.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> implements Listenable {
  AuthBloc(this.repository)
    : super(
        const AuthState(
          phase: AuthPhase.starting,
          account: null,
          busy: false,
          error: null,
        ),
      ) {
    on<AuthEvent>((event, emit) async {
      _emitter = emit;
      try {
        await _process(event);
        _pending.remove(event)?.complete();
      } catch (error, stack) {
        _pending.remove(event)?.completeError(error, stack);
      } finally {
        _emitter = null;
      }
    }, transformer: (events, mapper) => events.asyncExpand(mapper));
    repository.api.onSessionExpired = () {
      add(const AuthSessionExpired());
    };
  }

  final AuthRepository repository;
  final _notifications = _AuthNotifications();
  Emitter<AuthState>? _emitter;
  final _pending = Map<AuthEvent, Completer<void>>.identity();

  Account? get account => state.account;
  set _account(Account? value) => _update(state.copyWith(account: value));
  AuthPhase get phase => state.phase;
  set _phase(AuthPhase value) => _update(state.copyWith(phase: value));
  bool get busy => state.busy;
  set _busy(bool value) => _update(state.copyWith(busy: value));
  String? get error => state.error;
  set _error(String? value) => _update(state.copyWith(error: value));
  Stream<AuthState> get states => stream;

  void _update(AuthState next) {
    if (!isClosed && _emitter?.isDone == false) _emitter!(next);
  }

  @override
  void addListener(VoidCallback listener) =>
      _notifications.addListener(listener);
  @override
  void removeListener(VoidCallback listener) =>
      _notifications.removeListener(listener);

  Future<void> dispatch(AuthEvent event) {
    if (isClosed) return Future.value();
    final completion = Completer<void>();
    _pending[event] = completion;
    super.add(event);
    return completion.future;
  }

  Future<void> _process(AuthEvent event) async {
    if (event is AuthSessionExpired) {
      _account = null;
      _phase = AuthPhase.guest;
      _emit();
    } else if (event is AuthStarted) {
      await _start();
    } else if (event is AuthSubmitted) {
      await _submit(event);
    } else if (event is AuthSignedOut) {
      await _signOut();
    } else if (event is AuthAccountAccepted) {
      _acceptAccount(event.data);
    } else if (event is AuthProfileImageRemoved) {
      _removeProfileImage();
    } else if (event is AuthAccountRefreshRequested) {
      await _refreshAccount();
    }
  }

  Future<void> start() => dispatch(AuthStarted());

  Future<void> submit({
    required String email,
    required String password,
    Json? registration,
  }) => dispatch(
    AuthSubmitted(email: email, password: password, registration: registration),
  );

  Future<void> signOut() => dispatch(AuthSignedOut());

  Future<void> acceptAccount(Json data) {
    return dispatch(AuthAccountAccepted(data));
  }

  Future<void> removeProfileImage() {
    return dispatch(AuthProfileImageRemoved());
  }

  Future<void> refreshAccount() => dispatch(AuthAccountRefreshRequested());

  Future<void> _start() async {
    _phase = AuthPhase.starting;
    _error = null;
    _emit();
    try {
      _account = await repository.restore();
      _phase = account == null ? AuthPhase.guest : AuthPhase.signedIn;
    } catch (failure) {
      _phase = repository.api.hasRefreshSession
          ? AuthPhase.unavailable
          : AuthPhase.guest;
      _error = friendlyError(failure);
    }
    _emit();
  }

  Future<void> _submit(AuthSubmitted event) async {
    if (busy) return;
    _busy = true;
    _error = null;
    _emit();
    try {
      _account = event.registration == null
          ? await repository.signIn(event.email, event.password)
          : await repository.register(event.registration!);
      _phase = AuthPhase.signedIn;
    } catch (failure) {
      _error = friendlyError(failure);
    } finally {
      _busy = false;
      _emit();
    }
  }

  Future<void> _signOut() async {
    if (busy) return;
    _busy = true;
    _emit();
    try {
      await repository.api.logout();
      _error = null;
    } catch (_) {
      _error =
          'Saliste de este dispositivo. No pudimos confirmar el cierre en el servicio.';
    } finally {
      _account = null;
      _phase = AuthPhase.guest;
      _busy = false;
      _emit();
    }
  }

  void _acceptAccount(Json data) {
    if (phase != AuthPhase.signedIn || data['id'] != account?.id) return;
    _account = Account.fromJson(data);
    _emit();
  }

  void _removeProfileImage() {
    final user = account;
    if (user == null || phase != AuthPhase.signedIn) return;
    _account = Account(
      id: user.id,
      name: user.name,
      username: user.username,
      email: user.email,
      role: user.role,
    );
    _emit();
  }

  Future<void> _refreshAccount() async {
    final id = account?.id;
    final result = await repository.me();
    if (phase != AuthPhase.signedIn || account?.id != id) return;
    _account = result;
    _emit();
  }

  void _emit() {
    if (!isClosed) _notifications.refresh();
  }

  void dispose() {
    unawaited(close());
  }

  @override
  Future<void> close() async {
    repository.api.onSessionExpired = null;
    await super.close();
    _notifications.dispose();
  }
}

/// Adaptador Listenable para el redireccionamiento de GoRouter.
class _AuthNotifications extends ChangeNotifier {
  void refresh() => notifyListeners();
}
