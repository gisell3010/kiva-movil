import 'package:kiva_mobile_final/models/account.dart';

enum AuthPhase { starting, guest, signedIn, unavailable }

class AuthState {
  const AuthState({
    required this.phase,
    required this.account,
    required this.busy,
    required this.error,
  });

  final AuthPhase phase;
  final Account? account;
  final bool busy;
  final String? error;
  AuthState copyWith({
    AuthPhase? phase,
    Object? account = _unchanged,
    bool? busy,
    Object? error = _unchanged,
  }) => AuthState(
    phase: phase ?? this.phase,
    account: identical(account, _unchanged)
        ? this.account
        : account as Account?,
    busy: busy ?? this.busy,
    error: identical(error, _unchanged) ? this.error : error as String?,
  );
  static const _unchanged = Object();
}
