import 'package:flutter/material.dart';
import 'app.dart';
import 'core/api_client.dart';
import 'core/config.dart';
import 'core/session_store.dart';
import 'features/auth/repositories/auth_repository.dart';
import 'features/auth/state/auth_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final base = ApiConfig.validate(ApiConfig.defaultUrl);
  final api = ApiClient(store: SecureSessionStore(base.toString()));
  final auth = AuthController(AuthRepository(api));
  runApp(KivaApp(auth: auth));
  auth.start();
}
