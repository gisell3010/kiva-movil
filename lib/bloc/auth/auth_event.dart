import 'package:kiva_mobile_final/services/api_client.dart';

sealed class AuthEvent {
  const AuthEvent();
}

final class AuthSessionExpired extends AuthEvent {
  const AuthSessionExpired();
}

final class AuthStarted extends AuthEvent {
  const AuthStarted();
}

final class AuthSubmitted extends AuthEvent {
  const AuthSubmitted({
    required this.email,
    required this.password,
    this.registration,
  });

  final String email;
  final String password;
  final Json? registration;
}

final class AuthSignedOut extends AuthEvent {
  const AuthSignedOut();
}

final class AuthAccountAccepted extends AuthEvent {
  const AuthAccountAccepted(this.data);

  final Json data;
}

final class AuthProfileImageRemoved extends AuthEvent {
  const AuthProfileImageRemoved();
}

final class AuthAccountRefreshRequested extends AuthEvent {
  const AuthAccountRefreshRequested();
}
