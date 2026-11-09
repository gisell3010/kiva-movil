import 'package:kiva_mobile_final/services/api_client.dart';
import 'package:kiva_mobile_final/models/account.dart';

class AuthRepository {
  AuthRepository(this.api);
  final ApiClient api;
  Future<Account?> restore() async {
    await api.restore();
    if (!api.hasRefreshSession) return null;
    final response = await api.refresh();
    return Account.fromJson(Map<String, dynamic>.from(response['user'] as Map));
  }

  Future<Account> signIn(String email, String password) async {
    final data = await api.authenticate('login', {
      'email': email.trim().toLowerCase(),
      'password': password,
    });
    return Account.fromJson(Map<String, dynamic>.from(data['user'] as Map));
  }

  Future<Account> register(Json fields) async {
    final data = await api.authenticate('register', fields);
    return Account.fromJson(Map<String, dynamic>.from(data['user'] as Map));
  }

  Future<Account> me() async => Account.fromJson(await api.get('/users/me'));
}
