import 'package:kiva_mobile_final/services/api_client.dart';
import 'package:kiva_mobile_final/models/account.dart';

class DashboardRepository {
  DashboardRepository(this.api);
  final ApiClient api;
  Future<Json> personal() => api.get('/dashboard');
  Future<Json> workspace(Account user) {
    final path = switch (user.role) {
      GlobalRole.superAdmin => '/super-admin/dashboard',
      GlobalRole.admin => '/admin/dashboard',
      GlobalRole.support => '/support/dashboard',
      GlobalRole.user => '/dashboard',
    };
    return api.get(path);
  }
}
