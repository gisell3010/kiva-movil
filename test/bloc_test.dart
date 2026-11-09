import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiva_mobile_final/bloc/auth/auth_bloc.dart';
import 'package:kiva_mobile_final/bloc/dashboard/dashboard_bloc.dart';
import 'package:kiva_mobile_final/models/account.dart';
import 'package:kiva_mobile_final/repositories/auth/auth_repository.dart';
import 'package:kiva_mobile_final/repositories/dashboard/dashboard_repository.dart';
import 'package:kiva_mobile_final/services/api_client.dart';
import 'session_test.dart' as fixtures;

void main() {
  test(
    'El evento de inicio emite una sesión invitada sin credenciales',
    () async {
      final bloc = AuthBloc(
        AuthRepository(ApiClient(store: fixtures.MemoryStore())),
      );
      final result = bloc.stream.firstWhere(
        (state) => state.phase == AuthPhase.guest,
      );
      bloc.add(const AuthStarted());
      expect((await result).account, isNull);
      await bloc.close();
    },
  );

  test(
    'Dashboard conserva los datos tras un fallo y permite reintentar',
    () async {
      var fail = false;
      final api = ApiClient(
        store: fixtures.MemoryStore(),
        dio: Dio()
          ..httpClientAdapter = fixtures.Adapter((request) {
            return fail
                ? fixtures.reply(500, {})
                : fixtures.reply(200, {'groups_count': 3});
          }),
      );
      final bloc = DashboardBloc(DashboardRepository(api));
      final event = DashboardRequested(
        account: Account.fromJson(
          Map<String, dynamic>.from(fixtures.payload['user'] as Map),
        ),
        workspace: false,
      );
      await bloc.refresh(event);
      expect(bloc.state.data?['groups_count'], 3);
      fail = true;
      await bloc.refresh(event);
      expect(bloc.state.error, isNotNull);
      expect(bloc.state.data?['groups_count'], 3);
      expect(bloc.state.loading, isFalse);
      fail = false;
      await bloc.refresh(event);
      expect(bloc.state.error, isNull);
      await bloc.close();
    },
  );
}
