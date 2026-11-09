import 'package:flutter/material.dart';
import 'package:kiva_mobile_final/pages/app.dart';
import 'package:kiva_mobile_final/services/api_client.dart';
import 'package:kiva_mobile_final/services/config.dart';
import 'package:kiva_mobile_final/services/session_store.dart';
import 'package:kiva_mobile_final/repositories/auth/auth_repository.dart';
import 'package:kiva_mobile_final/bloc/auth/auth_bloc.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final base = ApiConfig.validate(ApiConfig.defaultUrl);
  final api = ApiClient(store: SecureSessionStore(base.toString()));
  final auth = AuthBloc(AuthRepository(api));
  runApp(KivaApp(auth: auth));
  auth.start();
}
